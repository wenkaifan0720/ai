// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: lines_longer_than_80_chars, unused_element

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:dart_mcp/server.dart';
import 'package:path/path.dart' as path;

import '../analyzer/dart_element_signature.dart' as element_signature;
import '../analyzer/dart_file_skeleton.dart' as skeleton;
import '../analyzer/dart_uri_converter.dart' as uri_converter;
import '../analyzer/need_refactor/dart_api_discovery.dart' as api_discovery;
import '../analyzer/need_refactor/dart_class_names.dart' as class_names;
import '../analyzer/need_refactor/dart_subtype_checker.dart' as subtype_checker;
import '../analyzer/need_refactor/dart_type_hierarchy.dart' as type_hierarchy;
import '../utils/sdk.dart';

/// Mix this in to any MCPServer to add support for analyzing Dart files.
base mixin DartFileAnalyzerSupport on ToolsSupport, RootsTrackingSupport
    implements SdkSupport {
  /// The persistent analysis context collection
  AnalysisContextCollection? _analysisCollection;

  /// File watcher for detecting changes
  StreamSubscription<FileSystemEvent>? _fileWatcher;

  /// Current project roots being analyzed
  List<String> _currentRoots = [];

  /// Get the current analysis collection, creating it if needed
  Future<AnalysisContextCollection?> get analysisCollection async {
    final currentRoots = (await roots).map((r) => r.uri).toList();

    // Check if roots changed - if so, recreate collection
    if (_analysisCollection == null ||
        !_listsEqual(_currentRoots, currentRoots)) {
      await _initializeAnalysisCollection(currentRoots);
    }

    return _analysisCollection;
  }

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
    registerTool(getDartFileSkeletonTool, _getDartFileSkeleton);
    registerTool(convertDartUriTool, _convertDartUri);
    registerTool(getSignatureTool, _getSignature);
    // The commented out tools requires refactoring, because they now use name to find the element
    // which is ambiguous. We should use the file uri + line + column to find the element.

    // registerTool(getAvailableMembersTool, _getAvailableMembers);
    // registerTool(getDartClassNamesTool, _getDartClassNames);
    // registerTool(checkDartSubtypeTool, _checkDartSubtype);
    // registerTool(getDartTypeHierarchyTool, _getDartTypeHierarchy);
    // registerTool(findDartImplementationsTool, _findDartImplementations);

    return result;
  }

  /// Initialize the analysis collection for the given roots
  Future<void> _initializeAnalysisCollection(List<String> rootPaths) async {
    // Clean up existing collection and watcher
    await _cleanup();

    if (rootPaths.isEmpty) {
      _analysisCollection = null;
      _currentRoots = [];
      return;
    }

    final dartSdkPath = sdk.dartSdkPath;
    if (dartSdkPath == null) {
      _analysisCollection = null;
      _currentRoots = [];
      return;
    }

    try {
      // Convert root URIs to normalized file paths
      final normalizedPaths =
          rootPaths.map((rootUri) {
            final uri = Uri.parse(rootUri);
            if (uri.scheme == 'file') {
              // Convert file URI to path and normalize
              return path.normalize(uri.toFilePath());
            } else {
              // Assume it's already a file path
              return path.normalize(rootUri);
            }
          }).toList();

      // Create new analysis collection
      _analysisCollection = AnalysisContextCollection(
        includedPaths: normalizedPaths,
        sdkPath: dartSdkPath,
        resourceProvider: PhysicalResourceProvider.INSTANCE,
      );

      _currentRoots = List.from(rootPaths);

      // Set up file watching for normalized paths
      await _setupFileWatcher(normalizedPaths);

      log(
        LoggingLevel.info,
        'Initialized analysis collection for ${rootPaths.length} roots',
      );
    } catch (e) {
      log(LoggingLevel.error, 'Failed to initialize analysis collection: $e');
      _analysisCollection = null;
      _currentRoots = [];
    }
  }

  /// Set up file watcher for the given root paths
  Future<void> _setupFileWatcher(List<String> rootPaths) async {
    if (rootPaths.isEmpty) return;

    // For simplicity, we'll watch all roots. In a more sophisticated implementation,
    // we could merge multiple directory watchers.
    try {
      // Watch the first root (most common case is single root)
      final primaryRoot = rootPaths.first;
      final directory = Directory(primaryRoot);

      if (await directory.exists()) {
        _fileWatcher = directory
            .watch(recursive: true)
            .where((event) => event.path.endsWith('.dart'))
            .listen(
              _handleFileChange,
              onError: (error) {
                log(LoggingLevel.warning, 'File watcher error: $error');
              },
            );

        log(LoggingLevel.debug, 'File watcher initialized for $primaryRoot');
      }
    } catch (e) {
      log(LoggingLevel.warning, 'Failed to set up file watcher: $e');
    }
  }

  /// Handle file system changes
  void _handleFileChange(FileSystemEvent event) async {
    final collection = _analysisCollection;
    if (collection == null) return;

    try {
      final context = collection.contextFor(event.path);
      context.changeFile(event.path);
      await context.applyPendingFileChanges();

      log(LoggingLevel.debug, 'Notified analyzer of change: ${event.path}');
    } catch (e) {
      log(LoggingLevel.debug, 'Failed to notify file change: $e');
    }
  }

  @override
  Future<void> updateRoots() async {
    await super.updateRoots();

    // Trigger reinitialization of analysis collection when roots change
    final newRoots = (await roots).map((r) => r.uri).toList();
    if (!_listsEqual(_currentRoots, newRoots)) {
      log(
        LoggingLevel.info,
        'Roots changed, reinitializing analysis collection',
      );
      await _initializeAnalysisCollection(newRoots);
    }
  }

  /// Clean up resources
  Future<void> _cleanup() async {
    await _fileWatcher?.cancel();
    _fileWatcher = null;

    // Note: AnalysisContextCollection doesn't have an explicit dispose method,
    // but setting it to null allows GC to clean it up
    _analysisCollection = null;
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

  Future<CallToolResult> _getDartFileSkeleton(CallToolRequest request) async {
    // This tool doesn't need analysis context, delegate to original implementation
    return skeleton.getDartFileSkeleton(request);
  }

  Future<CallToolResult> _getDartClassNames(CallToolRequest request) async {
    return _withSharedAnalysisContext(request, (collection, filePath) async {
      return class_names.getDartClassNames(request, this, collection);
    });
  }

  Future<CallToolResult> _checkDartSubtype(CallToolRequest request) async {
    return _withSharedAnalysisContext(request, (collection, filePath) async {
      return subtype_checker.checkDartSubtype(request, this, collection);
    });
  }

  Future<CallToolResult> _getDartTypeHierarchy(CallToolRequest request) async {
    return _withSharedAnalysisContext(request, (collection, filePath) async {
      return type_hierarchy.getDartTypeHierarchy(request, this, collection);
    });
  }

  Future<CallToolResult> _convertDartUri(CallToolRequest request) async {
    return _withSharedAnalysisContext(request, (collection, filePath) async {
      return uri_converter.convertDartUri(request, this, collection);
    });
  }

  Future<CallToolResult> _getSignature(CallToolRequest request) async {
    return _withSharedAnalysisContext(request, (collection, filePath) async {
      final line = request.arguments?['line'] as int?;
      final column = request.arguments?['column'] as int?;
      final getContainingDeclaration =
          request.arguments?['get_containing_declaration'] as bool? ?? true;

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

      return element_signature.getElementSignature(
        collection,
        filePath,
        line,
        column,
        getContainingDeclaration: getContainingDeclaration,
      );
    });
  }

  Future<CallToolResult> _getAvailableMembers(CallToolRequest request) async {
    return _withSharedAnalysisContext(request, (collection, filePath) async {
      return api_discovery.getAvailableMembers(request, this, collection);
    });
  }

  /// Helper method for tools that need analysis context
  Future<CallToolResult> _withSharedAnalysisContext(
    CallToolRequest request,
    Future<CallToolResult> Function(AnalysisContextCollection, String) handler,
  ) async {
    final filePath = request.arguments?['file_path'] as String?;
    if (filePath == null) {
      return CallToolResult(
        content: [TextContent(text: 'Missing required argument `file_path`.')],
        isError: true,
      );
    }

    final collection = await analysisCollection;
    if (collection == null) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Analysis collection not available. Make sure roots are set and Dart SDK is available.',
          ),
        ],
        isError: true,
      );
    }

    return handler(collection, filePath);
  }

  // Tool definitions (unchanged from original)

  /// Tool for creating a skeleton version of a Dart file with method bodies removed.
  static final getDartFileSkeletonTool = Tool(
    name: 'get_dart_file_skeleton',
    description:
        'Parses a Dart file and returns a skeleton version with method bodies '
        'removed, preserving class structure, method signatures, and imports. '
        'This provides a token-efficient overview of the file structure.',
    inputSchema: Schema.object(
      properties: {
        'file_path': Schema.string(
          description: 'The absolute path to the Dart file to analyze.',
        ),
        'skip_expression_bodies': Schema.bool(
          description:
              'Whether to also skip expression function bodies (=> syntax). Defaults to false.',
        ),
        'omit_skip_comments': Schema.bool(
          description:
              'Whether to omit the "// Lines X-Y skipped" comments. Defaults to false.',
        ),
        'skip_imports': Schema.bool(
          description:
              'Whether to remove import directives from the output. Defaults to false.',
        ),
        'skip_comments': Schema.bool(
          description:
              'Whether to remove all comments from the output. Defaults to false.',
        ),
      },
      required: ['file_path'],
    ),
  );

  /// Tool for extracting class names from a Dart file.
  static final getDartClassNamesTool = Tool(
    name: 'get_dart_class_names',
    description:
        'Analyzes a Dart file and returns the list of class names defined '
        'in it.',
    inputSchema: Schema.object(
      properties: {
        'file_path': Schema.string(
          description: 'The absolute path to the Dart file to analyze.',
        ),
      },
      required: ['file_path'],
    ),
  );

  /// Tool for checking if one type is a subtype of another.
  static final checkDartSubtypeTool = Tool(
    name: 'check_dart_subtype',
    description:
        'Checks if one type is assignable to another using the Dart type system. '
        'This performs semantic analysis, not just name matching.',
    inputSchema: Schema.object(
      properties: {
        'file_path': Schema.string(
          description:
              'The absolute path to a Dart file containing both types.',
        ),
        'subtype': Schema.string(
          description: 'The name of the potential subtype.',
        ),
        'supertype': Schema.string(
          description: 'The name of the potential supertype.',
        ),
      },
      required: ['file_path', 'subtype', 'supertype'],
    ),
  );

  /// Tool for getting the complete inheritance hierarchy of a type.
  static final getDartTypeHierarchyTool = Tool(
    name: 'get_dart_type_hierarchy',
    description:
        'Gets the complete inheritance hierarchy for a type, including '
        'superclasses, implemented interfaces, and mixed-in types.',
    inputSchema: Schema.object(
      properties: {
        'file_path': Schema.string(
          description: 'The absolute path to a Dart file containing the type.',
        ),
        'type_name': Schema.string(
          description: 'The name of the type to analyze.',
        ),
      },
      required: ['file_path', 'type_name'],
    ),
  );

  /// Tool for finding all implementations of a given interface/class.
  static final findDartImplementationsTool = Tool(
    name: 'find_dart_implementations',
    description:
        'Finds all classes that implement or extend a given interface/class '
        'within a project directory.',
    inputSchema: Schema.object(
      properties: {
        'project_path': Schema.string(
          description: 'The absolute path to the project directory to search.',
        ),
        'interface_name': Schema.string(
          description:
              'The name of the interface/class to find implementations of.',
        ),
      },
      required: ['project_path', 'interface_name'],
    ),
  );

  /// Tool for converting Dart URIs to file paths.
  static final convertDartUriTool = Tool(
    name: 'convert_dart_uri',
    description:
        'Converts a Dart URI (dart:, package:, or file:) to an actual file path '
        'that can be accessed by AI tools. Supports dart: URIs like dart:ui, '
        'package: URIs like package:flutter/material.dart, and file paths.',
    inputSchema: Schema.object(
      properties: {
        'uri': Schema.string(
          description:
              'The URI to convert (e.g., "dart:ui", "package:flutter/material.dart").',
        ),
        'context_path': Schema.string(
          description:
              'Optional: A file path in the project for context when resolving package: URIs. '
              'Required for package: URIs to resolve dependencies correctly.',
        ),
      },
      required: ['uri'],
    ),
  );

  /// Tool for discovering available API members of a type.
  static final getAvailableMembersTool = Tool(
    name: 'get_available_members',
    description:
        'Gets available API members (constructors, methods, properties) for a given type. '
        'Essential for AI code generation to discover what operations are available on objects.',
    inputSchema: Schema.object(
      properties: {
        'file_path': Schema.string(
          description: 'The absolute path to a Dart file containing the type.',
        ),
        'type_name': Schema.string(
          description: 'The name of the type to analyze.',
        ),
        'include_inherited': Schema.bool(
          description:
              'Whether to include inherited members from supertypes. Defaults to true.',
        ),
      },
      required: ['file_path', 'type_name'],
    ),
  );

  /// Tool for getting the signature of an element at a specific location.
  static final getSignatureTool = Tool(
    name: 'get_signature',
    description:
        'Gets the source code of the element at a specific location in a Dart file.',
    inputSchema: Schema.object(
      properties: {
        'file_path': Schema.string(
          description: 'The absolute path to the Dart file to analyze.',
        ),
        'line': Schema.int(
          description: 'The zero-based line number of the position.',
        ),
        'column': Schema.int(
          description: 'The zero-based column number of the position.',
        ),
        'get_containing_declaration': Schema.bool(
          description:
              'Optional. If true, walks up the AST tree to find the containing class, enum, mixin, extension, type alias, function, or top-level variable declaration and returns its signature instead of the element at the specified location.',
        ),
      },
      required: ['file_path', 'line', 'column'],
    ),
  );
}
