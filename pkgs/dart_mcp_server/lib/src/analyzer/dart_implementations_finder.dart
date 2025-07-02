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

/// Implementation of the find_dart_implementations tool.
Future<CallToolResult> findDartImplementations(
  CallToolRequest request,
  SdkSupport sdkSupport,
) async {
  final projectPath = request.arguments?['project_path'] as String?;
  final interfaceName = request.arguments?['interface_name'] as String?;

  if (projectPath == null || interfaceName == null) {
    return CallToolResult(
      content: [
        TextContent(
          text: 'Missing required arguments: project_path, interface_name',
        ),
      ],
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
      includedPaths: [projectPath],
      sdkPath: dartSdkPath,
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final implementations = <String>[];

    // Analyze all contexts in the project
    for (final context in collection.contexts) {
      for (final filePath in context.contextRoot.analyzedFiles()) {
        if (!filePath.endsWith('.dart')) continue;

        try {
          final result = await context.currentSession.getResolvedLibrary(
            filePath,
          );
          if (result is! ResolvedLibraryResult) continue;

          final implementationVisitor = _ImplementationFinderVisitor(
            interfaceName,
          );
          result.element.accept(implementationVisitor);

          for (final impl in implementationVisitor.implementations) {
            implementations.add(
              '${path.relative(filePath, from: projectPath)}: $impl',
            );
          }
        } catch (e) {
          // Skip files that can't be analyzed
          continue;
        }
      }
    }

    final resultText =
        implementations.isEmpty
            ? 'No implementations of "$interfaceName" found in project'
            : 'Implementations of "$interfaceName":\n\n${implementations.join('\n')}';

    return CallToolResult(content: [TextContent(text: resultText)]);
  } on Exception catch (e) {
    return CallToolResult(
      content: [TextContent(text: 'Failed to find implementations: $e')],
      isError: true,
    );
  }
}

class _ImplementationFinderVisitor extends GeneralizingElementVisitor<void> {
  final String interfaceName;
  final List<String> implementations = [];

  _ImplementationFinderVisitor(this.interfaceName);

  @override
  void visitClassElement(ClassElement element) {
    // Check if this class implements or extends the target interface
    final implementsInterface = _implementsInterface(element);
    if (implementsInterface) {
      implementations.add(element.name);
    }
    super.visitClassElement(element);
  }

  bool _implementsInterface(ClassElement element) {
    // Check superclass chain
    var current = element.supertype;
    while (current != null) {
      if (current.element.name == interfaceName) {
        return true;
      }
      current = current.element.supertype;
    }

    // Check interfaces
    for (final interface in element.interfaces) {
      if (interface.element.name == interfaceName) {
        return true;
      }
    }

    // Check mixins
    for (final mixin in element.mixins) {
      if (mixin.element.name == interfaceName) {
        return true;
      }
    }

    return false;
  }
}
