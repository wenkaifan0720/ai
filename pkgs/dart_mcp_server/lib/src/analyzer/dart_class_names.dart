// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:dart_mcp/server.dart';
import 'package:path/path.dart' as path;

import '../utils/sdk.dart';

/// Implementation of the get_dart_class_names tool.
Future<CallToolResult> getDartClassNames(
  CallToolRequest request,
  SdkSupport sdkSupport,
) async {
  final filePath = request.arguments?['file_path'] as String?;
  if (filePath == null) {
    return CallToolResult(
      content: [TextContent(text: 'Missing required argument `file_path`.')],
      isError: true,
    );
  }

  try {
    final dartSdkPath = sdkSupport.sdk.dartSdkPath;
    if (dartSdkPath == null) {
      return CallToolResult(
        content: [TextContent(text: 'Could not find Dart SDK path.')],
        isError: true,
      );
    }

    final collection = AnalysisContextCollection(
      includedPaths: [path.dirname(filePath)],
      sdkPath: dartSdkPath,
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final context = collection.contextFor(filePath);
    final result = await context.currentSession.getResolvedLibrary(filePath);

    if (result is! ResolvedLibraryResult) {
      return CallToolResult(
        content: [TextContent(text: 'Failed to resolve library for $filePath')],
        isError: true,
      );
    }

    // Find the specific unit for our file
    final unit = result.units.firstWhere(
      (unit) => unit.path == filePath,
      orElse: () => throw StateError('Unit not found for $filePath'),
    );

    final classVisitor = _ClassElementVisitor();
    unit.libraryElement.accept(classVisitor);

    final classNames = classVisitor.classNames;

    return CallToolResult(
      content: [
        TextContent(text: 'Class names found: ${classNames.join(', ')}'),
      ],
    );
  } on Exception catch (e) {
    return CallToolResult(
      content: [TextContent(text: 'Failed to analyze file: $e')],
      isError: true,
    );
  }
}

class _ClassElementVisitor extends GeneralizingElementVisitor<void> {
  final List<String> classNames = [];

  @override
  void visitClassElement(ClassElement element) {
    classNames.add(element.name);
    super.visitClassElement(element);
  }
}
