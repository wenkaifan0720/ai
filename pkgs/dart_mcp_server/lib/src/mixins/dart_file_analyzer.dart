// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dart_mcp/server.dart';

import '../analyzer/dart_file_skeleton.dart' as skeleton;
import '../analyzer/dart_class_names.dart' as class_names;
import '../analyzer/dart_subtype_checker.dart' as subtype_checker;
import '../analyzer/dart_type_hierarchy.dart' as type_hierarchy;
import '../analyzer/dart_implementations_finder.dart' as implementations_finder;
import '../analyzer/dart_uri_converter.dart' as uri_converter;
import '../analyzer/dart_api_discovery.dart' as api_discovery;
import '../utils/sdk.dart';

/// Mix this in to any MCPServer to add support for analyzing Dart files.
base mixin DartFileAnalyzerSupport on ToolsSupport implements SdkSupport {
  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) {
    registerTool(getDartFileSkeletonTool, skeleton.getDartFileSkeleton);
    registerTool(
      getDartClassNamesTool,
      (request) => class_names.getDartClassNames(request, this),
    );
    registerTool(
      checkDartSubtypeTool,
      (request) => subtype_checker.checkDartSubtype(request, this),
    );
    registerTool(
      getDartTypeHierarchyTool,
      (request) => type_hierarchy.getDartTypeHierarchy(request, this),
    );
    registerTool(
      findDartImplementationsTool,
      (request) =>
          implementations_finder.findDartImplementations(request, this),
    );
    registerTool(
      convertDartUriTool,
      (request) => uri_converter.convertDartUri(request, this),
    );
    registerTool(
      getAvailableMembersTool,
      (request) => api_discovery.getAvailableMembers(request, this),
    );

    return super.initialize(request);
  }

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
}
