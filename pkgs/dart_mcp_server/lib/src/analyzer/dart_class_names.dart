// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:dart_mcp/server.dart';

import '../utils/sdk.dart';

/// Implementation of the get_dart_class_names tool using a shared analysis collection.
Future<CallToolResult> getDartClassNames(
  CallToolRequest request,
  SdkSupport sdkSupport,
  AnalysisContextCollection collection,
) async {
  final filePath = request.arguments?['file_path'] as String?;

  if (filePath == null) {
    return CallToolResult(
      content: [TextContent(text: 'Missing required argument: file_path')],
      isError: true,
    );
  }

  try {
    final context = collection.contextFor(filePath);
    final result = await context.currentSession.getResolvedLibrary(filePath);

    if (result is! ResolvedLibraryResult) {
      return CallToolResult(
        content: [TextContent(text: 'Failed to resolve library for $filePath')],
        isError: true,
      );
    }

    final visitor = _ClassNameVisitor();
    result.element.accept(visitor);

    final classNames = visitor.classNames;
    if (classNames.isEmpty) {
      return CallToolResult(
        content: [TextContent(text: 'No classes found in $filePath')],
      );
    }

    return CallToolResult(
      content: [
        TextContent(
          text: 'Classes found in $filePath:\n${classNames.join('\n')}',
        ),
      ],
    );
  } on Exception catch (e) {
    return CallToolResult(
      content: [TextContent(text: 'Failed to analyze classes: $e')],
      isError: true,
    );
  }
}

class _ClassNameVisitor extends GeneralizingElementVisitor<void> {
  final List<String> classNames = [];

  @override
  void visitClassElement(ClassElement element) {
    classNames.add(element.name);
    super.visitClassElement(element);
  }
}
