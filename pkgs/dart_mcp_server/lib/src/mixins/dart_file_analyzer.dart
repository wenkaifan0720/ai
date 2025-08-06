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
    // This tool doesn't need analysis context, delegate to original implementation
    return outline.getDartFileOutline(request);
  }

  Future<CallToolResult> _convertDartUri(CallToolRequest request) async {
    return _withAnalysisContext(request, (context, filePath) async {
      return uri_converter.convertDartUriWithContext(request, this, context);
    });
  }

  Future<CallToolResult> _getSignature(CallToolRequest request) async {
    // Validate arguments early, before trying to get analysis context
    final line = request.arguments?['line'] as int?;
    final column = request.arguments?['column'] as int?;
    final getContainingDeclaration =
        request.arguments?['get_containing_declaration'] as bool? ?? false;

    if (line == null) {
      return CallToolResult(
        content: [TextContent(text: 'Missing required argument `line`.')],
        isError: true,
      );
    }

    if (column == null) {
      return CallToolResult(
        content: [TextContent(text: 'Missing required argument `column`.')],
        isError: true,
      );
    }

    return _withAnalysisContext(request, (context, filePath) async {
      return element_signature.getElementDeclarationSignature(
        context,
        filePath,
        line,
        column,
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
        'This provides a token-efficient overview of the file structure that is ideal '
        'for understanding code organization, API surfaces, and inheritance relationships '
        'without the implementation details.',
    annotations: ToolAnnotations(
      title: 'Dart File Outline',
      readOnlyHint: true,
    ),
    inputSchema: Schema.object(
      properties: {
        'uri': Schema.string(
          description:
              'The URI of the Dart file to analyze. Can be a file:// URI or absolute file path.',
        ),
        'skip_expression_bodies': Schema.bool(
          description:
              'Whether to convert expression function bodies (=> syntax) to regular bodies with content skipped. '
              'When true, `methodName() => implementation;` becomes `methodName() { /* skipped */ }`. '
              'When false, preserves the original `=>` syntax. Defaults to false.',
        ),
        'omit_skip_comments': Schema.bool(
          description:
              'Whether to omit the "// Lines X-Y skipped" placeholder comments that indicate '
              'where method bodies were removed. When true, provides a cleaner outline. '
              'When false, shows exactly which lines were skipped for reference. Defaults to false.',
        ),
        'skip_imports': Schema.bool(
          description:
              'Whether to remove all import and export directives from the output. '
              'Useful when you only need to see the defined classes and methods '
              'without dependency information. Defaults to false.',
        ),
        'skip_comments': Schema.bool(
          description:
              'Whether to remove all comments (both single-line // and multi-line /* */) '
              'from the output. Useful when you want a minimal code structure view. '
              'Note: this removes original comments but may preserve skip indicators. Defaults to false.',
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
        'Essential for navigating Dart\'s module system and resolving dependencies. '
        'Supports dart: core library URIs (dart:core, dart:io), package: URIs from pub dependencies '
        '(package:flutter/material.dart), and converts them to the actual file locations on disk.',
    annotations: ToolAnnotations(title: 'Convert Dart URI', readOnlyHint: true),
    inputSchema: Schema.object(
      properties: {
        'uri': Schema.string(
          description:
              'The URI to convert. Examples:\n'
              '• dart:core - Core Dart library\n'
              '• dart:io - Dart I/O library\n'
              '• package:flutter/material.dart - Flutter Material package\n'
              '• package:my_package/lib.dart - Local package reference\n'
              '• file:///path/to/file.dart - File URI (returned as-is)',
        ),
      },
      required: ['uri'],
    ),
  );

  /// Tool for getting the signature of an element at a specific location.
  static final getSignatureTool = Tool(
    name: 'get_signature',
    description:
        'Analyzes a specific location in a Dart file and returns the signature of the element at that position. '
        'This tool performs "Go to Definition" functionality - when you point to a method call, variable reference, '
        'or type usage, it returns the signature of the actual declaration, not the usage site. '
        'Essential for understanding APIs, method parameters, return types, and class definitions.',
    annotations: ToolAnnotations(title: 'Get Signature', readOnlyHint: true),
    inputSchema: Schema.object(
      properties: {
        'uri': Schema.string(
          description: 'The URI of the Dart file to analyze.',
        ),
        'line': Schema.int(
          description:
              'The zero-based line number of the cursor position in the file.',
        ),
        'column': Schema.int(
          description:
              'The zero-based column number of the cursor position within the line.',
        ),
        'get_containing_declaration': Schema.bool(
          description:
              'Whether to return the signature of the containing declaration instead of just the element declaration. '
              'When true, if the cursor is inside a method body, it returns the method signature. '
              'If inside a class, returns the class declaration. Useful for getting context about '
              'the current scope rather than the specific symbol under the cursor.',
        ),
      },
      required: ['uri', 'line', 'column'],
    ),
  );
}
