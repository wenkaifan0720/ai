// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: lines_longer_than_80_chars, unused_element

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:dart_mcp/server.dart';
import 'package:path/path.dart' as path;

import '../analyzer/dart_element_signature.dart' as element_signature;
import '../analyzer/dart_file_outline.dart' as outline;
import '../analyzer/dart_uri_converter.dart' as uri_converter;
import '../utils/sdk.dart';

/// Mix this in to any MCPServer to add support for analyzing Dart files.
base mixin DartFileAnalyzerSupport on ToolsSupport, RootsTrackingSupport
    implements SdkSupport {
  /// Analysis context collections per root
  final Map<String, AnalysisContextCollection> _analysisCollections = {};

  /// File watchers per root for detecting changes
  final Map<String, StreamSubscription<FileSystemEvent>> _fileWatchers = {};

  /// Current project roots being analyzed
  List<String> _currentRoots = [];

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    final result = await super.initialize(request);

    // Check if we have the required dependencies
    if (sdk.dartSdkPath == null) {
      log(
        LoggingLevel.warning,
        'Project analysis requires a Dart SDK but none was given. '
        'Dart file analysis tools have been disabled.',
      );
      return result;
    }

    if (!supportsRoots) {
      log(
        LoggingLevel.warning,
        'Project analysis requires the "roots" capability which is not '
        'supported. Dart file analysis tools have been disabled.',
      );
      return result;
    }

    // Register all the tools
    registerTool(getDartFileOutlineTool, _getDartFileOutline);
    registerTool(convertDartUriTool, _convertDartUri);
    registerTool(getSignatureTool, _getSignature);

    return result;
  }

  /// Initialize analysis collections for the given roots
  Future<void> _initializeAnalysisCollections(List<String> rootPaths) async {
    // Clean up existing collections and watchers
    await _cleanup();

    if (rootPaths.isEmpty) {
      _currentRoots = [];
      return;
    }

    final dartSdkPath = sdk.dartSdkPath;
    if (dartSdkPath == null) {
      _currentRoots = [];
      return;
    }

    try {
      // Create separate analysis collection for each root
      for (final rootUri in rootPaths) {
        final uri = Uri.parse(rootUri);
        final rootPath = uri.scheme == 'file' ? uri.toFilePath() : rootUri;
        final normalizedPath = path.normalize(rootPath);

        // Create analysis collection for this root
        final collection = AnalysisContextCollection(
          includedPaths: [normalizedPath],
          sdkPath: dartSdkPath,
          resourceProvider: PhysicalResourceProvider.INSTANCE,
        );

        _analysisCollections[rootUri] = collection;

        // Set up file watcher for this root
        await _setupFileWatcherForRoot(rootUri, normalizedPath);

        log(
          LoggingLevel.debug,
          'Initialized analysis collection for root: $rootUri',
        );
      }

      _currentRoots = List.from(rootPaths);

      log(
        LoggingLevel.info,
        'Initialized ${_analysisCollections.length} analysis collections for ${rootPaths.length} roots',
      );
    } catch (e) {
      log(LoggingLevel.error, 'Failed to initialize analysis collections: $e');
      await _cleanup();
    }
  }

  /// Set up file watcher for a specific root
  Future<void> _setupFileWatcherForRoot(String rootUri, String rootPath) async {
    try {
      final directory = Directory(rootPath);

      if (await directory.exists()) {
        final watcher = directory
            .watch(recursive: true)
            .where((event) => event.path.endsWith('.dart'))
            .listen(
              (event) => _handleFileChange(event, rootUri),
              onError: (Object error) {
                log(
                  LoggingLevel.warning,
                  'File watcher error for $rootUri: $error',
                );
              },
            );

        _fileWatchers[rootUri] = watcher;
        log(LoggingLevel.debug, 'File watcher initialized for $rootUri');
      }
    } catch (e) {
      log(
        LoggingLevel.warning,
        'Failed to set up file watcher for $rootUri: $e',
      );
    }
  }

  /// Handle file system changes
  void _handleFileChange(FileSystemEvent event, String rootUri) async {
    final collection = _analysisCollections[rootUri];
    if (collection == null) return;

    try {
      final context = collection.contextFor(event.path);
      context.changeFile(event.path);
      await context.applyPendingFileChanges();

      log(
        LoggingLevel.debug,
        'Notified analyzer of change: ${event.path} (root: $rootUri)',
      );
    } catch (e) {
      log(LoggingLevel.debug, 'Failed to notify file change: $e');
    }
  }

  @override
  Future<void> updateRoots() async {
    await super.updateRoots();

    // Trigger reinitialization of analysis collections when roots change
    final newRoots = (await roots).map((r) => r.uri).toList();
    if (!_listsEqual(_currentRoots, newRoots)) {
      log(
        LoggingLevel.info,
        'Roots changed, reinitializing analysis collections',
      );
      await _initializeAnalysisCollections(newRoots);
    }
  }

  /// Clean up resources
  Future<void> _cleanup() async {
    // Cancel all file watchers
    for (final watcher in _fileWatchers.values) {
      await watcher.cancel();
    }
    _fileWatchers.clear();

    // Note: AnalysisContextCollection doesn't have an explicit dispose method,
    // but clearing the map allows GC to clean them up
    _analysisCollections.clear();
  }

  @override
  Future<void> shutdown() async {
    await _cleanup();
    await super.shutdown();
  }

  /// Helper to compare two lists for equality
  bool _listsEqual<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Tool implementations using shared analysis context

  Future<CallToolResult> _getDartFileOutline(CallToolRequest request) async {
    final uriString = request.arguments?['uri'] as String?;
    if (uriString == null) {
      return CallToolResult(
        content: [TextContent(text: 'Missing required argument `uri`.')],
        isError: true,
      );
    }

    // Check if this is a dart: or package: URI that needs conversion
    if (uriString.startsWith('dart:') || uriString.startsWith('package:')) {
      // Convert the URI first
      final convertResult = await _convertDartUri(
        CallToolRequest(
          name: 'convert_dart_uri',
          arguments: {'uri': uriString},
        ),
      );

      if (convertResult.isError == true) {
        return convertResult;
      }

      // Extract the converted file path from the result
      final resultText = (convertResult.content.first as TextContent).text;
      final pathMatch = RegExp(
        r'resolved to file path:\s*(.+)',
      ).firstMatch(resultText);
      if (pathMatch == null) {
        return CallToolResult(
          content: [
            TextContent(
              text: 'Could not extract file path from URI conversion result.',
            ),
          ],
          isError: true,
        );
      }

      final convertedPath = pathMatch.group(1)!.trim();

      // Create a new request with the converted file path
      final convertedRequest = CallToolRequest(
        name: request.name,
        arguments: {...request.arguments!, 'uri': 'file://$convertedPath'},
      );

      return outline.getDartFileOutline(convertedRequest);
    }

    // For file: URIs or regular paths, use original implementation
    return outline.getDartFileOutline(request);
  }

  Future<CallToolResult> _convertDartUri(CallToolRequest request) async {
    // Check if we have any analysis collections
    if (_analysisCollections.isEmpty) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'No analysis collections available. Make sure roots are set and Dart SDK is available.',
          ),
        ],
        isError: true,
      );
    }

    try {
      // Use any available analysis context since URI conversion works across the entire project
      final context = _analysisCollections.values.first.contexts.first;
      return uri_converter.convertDartUriWithContext(request, this, context);
    } catch (e) {
      return CallToolResult(
        content: [
          TextContent(
            text: 'Error accessing analysis context for URI conversion: $e',
          ),
        ],
        isError: true,
      );
    }
  }

  Future<CallToolResult> _getSignature(CallToolRequest request) async {
    // Validate arguments early, before trying to get analysis context
    final symbolName = request.arguments?['name'] as String?;
    final getContainingDeclaration =
        request.arguments?['get_containing_declaration'] as bool? ?? true;
    final uriString = request.arguments?['uri'] as String?;

    if (symbolName == null || symbolName.isEmpty) {
      return CallToolResult(
        content: [TextContent(text: 'Missing required argument `name`.')],
        isError: true,
      );
    }

    if (uriString == null) {
      return CallToolResult(
        content: [TextContent(text: 'Missing required argument `uri`.')],
        isError: true,
      );
    }

    // Check if this is a dart: or package: URI that needs conversion
    if (uriString.startsWith('dart:') || uriString.startsWith('package:')) {
      // Convert the URI first
      final convertResult = await _convertDartUri(
        CallToolRequest(
          name: 'convert_dart_uri',
          arguments: {'uri': uriString},
        ),
      );

      if (convertResult.isError == true) {
        return convertResult;
      }

      // Extract the converted file path from the result
      final resultText = (convertResult.content.first as TextContent).text;
      final pathMatch = RegExp(
        r'resolved to file path:\s*(.+)',
      ).firstMatch(resultText);
      if (pathMatch == null) {
        return CallToolResult(
          content: [
            TextContent(
              text: 'Could not extract file path from URI conversion result.',
            ),
          ],
          isError: true,
        );
      }

      final convertedPath = pathMatch.group(1)!.trim();

      // Create a new request with the converted file path
      final convertedRequest = CallToolRequest(
        name: request.name,
        arguments: {...request.arguments!, 'uri': 'file://$convertedPath'},
      );

      return _getSignature(convertedRequest);
    }

    return _withAnalysisContext(request, (context, filePath) async {
      return element_signature.getElementDeclarationSignaturesByName(
        context,
        filePath,
        symbolName,
        getContainingDeclaration: getContainingDeclaration,
      );
    });
  }

  /// Helper method for tools that need direct analysis context access
  Future<CallToolResult> _withAnalysisContext(
    CallToolRequest request,
    Future<CallToolResult> Function(AnalysisContext, String) handler,
  ) async {
    final uriString = request.arguments?['uri'] as String?;
    if (uriString == null) {
      return CallToolResult(
        content: [TextContent(text: 'Missing required argument `uri`.')],
        isError: true,
      );
    }

    // Convert URI to file path
    final uri = Uri.parse(uriString);
    final filePath = uri.scheme == 'file' ? uri.toFilePath() : uriString;

    // Check if we have any analysis collections
    if (_analysisCollections.isEmpty) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'No analysis collections available. Make sure roots are set and Dart SDK is available.',
          ),
        ],
        isError: true,
      );
    }

    // Iterate through all analysis collections and find the first one
    // that can handle this file path
    for (final collection in _analysisCollections.values) {
      try {
        final context = collection.contextFor(filePath);
        return handler(context, filePath);
      } catch (e) {
        // This collection can't handle the file, try the next one
        continue;
      }
    }

    // If we get here, no collection could handle the file
    // Return a success result with "No element found" message instead of an error
    // This matches the expected behavior for invalid/nonexistent files
    return CallToolResult(
      content: [
        TextContent(
          text:
              'No element found at the specified location. The file may not exist or may not be under any analysis root.',
        ),
      ],
      isError: false,
    );
  }

  // Tool definitions (unchanged from original)

  /// Tool for creating an outline version of a Dart file with method bodies removed.
  static final getDartFileOutlineTool = Tool(
    name: 'get_dart_file_outline',
    description:
        'Parses a Dart file and returns a skeletal outline with method bodies removed, '
        'preserving class structure, method signatures, imports, and comments. '
        'Useful for getting an overview of file structure and API surfaces.',
    annotations: ToolAnnotations(
      title: 'Dart File Outline',
      readOnlyHint: true,
    ),
    inputSchema: Schema.object(
      properties: {
        'uri': Schema.string(
          description:
              'The URI of the Dart file to analyze. Supports file:, dart:, and package: URIs.',
        ),
        'skip_comments': Schema.bool(
          description: 'Remove all comments from the output.',
        ),
      },
      required: ['uri'],
    ),
  );

  /// Tool for converting Dart URIs to file paths.
  static final convertDartUriTool = Tool(
    name: 'convert_dart_uri',
    description:
        'Converts Dart-specific URIs to actual file paths that can be accessed by other tools. '
        'Supports dart: core library URIs, package: URIs from dependencies, and file: URIs.',
    annotations: ToolAnnotations(title: 'Convert Dart URI', readOnlyHint: true),
    inputSchema: Schema.object(
      properties: {
        'uri': Schema.string(
          description: 'The URI to convert (dart:, package:, or file: URI).',
        ),
      },
      required: ['uri'],
    ),
  );

  /// Tool for getting the signature of an element by name.
  static final getSignatureTool = Tool(
    name: 'get_signature',
    description:
        'Finds all occurrences of a symbol with the given name in a Dart file and returns their signatures. '
        'For variables, follows the type to return the type\'s declaration (e.g., searching for a Process variable returns the Process class signature). '
        'Automatically deduplicates identical signatures.',
    annotations: ToolAnnotations(title: 'Get Signature', readOnlyHint: true),
    inputSchema: Schema.object(
      properties: {
        'uri': Schema.string(
          description:
              'The URI of the Dart file containing the symbol to search for. Supports file:, dart:, and package: URIs.',
        ),
        'name': Schema.string(
          description: 'The name of the symbol to search for (case-sensitive).',
        ),
        'get_containing_declaration': Schema.bool(
          description:
              'Whether to return the containing declaration signature. Defaults to true.',
        ),
      },
      required: ['uri', 'name'],
    ),
  );
}
