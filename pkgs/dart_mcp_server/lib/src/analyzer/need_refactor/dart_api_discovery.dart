// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:dart_mcp/server.dart';

import '../../utils/sdk.dart';

/// Gets available API members for a type using a shared analysis collection.
Future<CallToolResult> getAvailableMembers(
  CallToolRequest request,
  SdkSupport sdkSupport,
  AnalysisContextCollection collection,
) async {
  final arguments = request.arguments as Map<String, Object?>;
  final filePath = arguments['file_path'] as String;
  final typeName = arguments['type_name'] as String;
  final includeInherited = arguments['include_inherited'] as bool? ?? true;

  if (!File(filePath).existsSync()) {
    return CallToolResult(
      content: [TextContent(text: 'File not found: $filePath')],
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

    final typeElement = _findTypeInLibrary(result, typeName);
    if (typeElement == null) {
      return CallToolResult(
        content: [
          TextContent(
            text: 'Type "$typeName" not found in $filePath or its imports.',
          ),
        ],
        isError: true,
      );
    }

    final apiInfo = _extractApiInfo(typeElement, includeInherited);
    return CallToolResult(content: [TextContent(text: apiInfo)]);
  } on Exception catch (e) {
    return CallToolResult(
      content: [TextContent(text: 'Failed to analyze type: $e')],
      isError: true,
    );
  }
}

String _extractApiInfo(Element typeElement, bool includeInherited) {
  final buffer = StringBuffer();
  buffer.writeln('Available APIs for ${typeElement.displayName}:\n');

  if (typeElement is! InterfaceElement) {
    buffer.writeln('Type does not have discoverable instance members.');
    return buffer.toString();
  }

  final element = typeElement as InterfaceElement;

  // Constructors
  final constructors = element.constructors.where((c) => !c.isPrivate).toList();
  if (constructors.isNotEmpty) {
    buffer.writeln('CONSTRUCTORS:');
    for (final constructor in constructors) {
      buffer.write('  ${element.name}');
      final name = constructor.name;
      if (name != null && name.isNotEmpty) {
        buffer.write('.$name');
      }
      buffer.write('(');
      buffer.write(_formatParams(constructor.parameters));
      buffer.writeln(')');
    }
    buffer.writeln();
  }

  // Instance methods
  final methods =
      includeInherited
          ? element.allSupertypes
              .expand((t) => t.methods)
              .where((m) => !m.isStatic && !m.isPrivate)
              .followedBy(
                element.methods.where((m) => !m.isStatic && !m.isPrivate),
              )
          : element.methods.where((m) => !m.isStatic && !m.isPrivate);

  final methodList = methods.toList();
  if (methodList.isNotEmpty) {
    buffer.writeln('METHODS:');
    for (final method in methodList) {
      buffer.write('  ${method.returnType.getDisplayString()} ${method.name}(');
      buffer.write(_formatParams(method.parameters));
      buffer.writeln(')');
    }
    buffer.writeln();
  }

  // Properties (getters/setters)
  final accessors =
      includeInherited
          ? element.allSupertypes
              .expand((t) => t.accessors)
              .where((a) => !a.isStatic && !a.isPrivate)
              .followedBy(
                element.accessors.where((a) => !a.isStatic && !a.isPrivate),
              )
          : element.accessors.where((a) => !a.isStatic && !a.isPrivate);

  final getters = accessors.where((a) => a.isGetter).toList();
  if (getters.isNotEmpty) {
    buffer.writeln('PROPERTIES:');
    for (final getter in getters) {
      buffer.writeln(
        '  ${getter.returnType.getDisplayString()} ${getter.name}',
      );
    }
    buffer.writeln();
  }

  return buffer.toString();
}

String _formatParams(List<ParameterElement> params) {
  if (params.isEmpty) return '';

  return params
      .map((p) {
        final buffer = StringBuffer();
        if (p.isRequiredNamed) buffer.write('required ');
        buffer.write('${p.type.getDisplayString()} ${p.name}');
        return buffer.toString();
      })
      .join(', ');
}

Element? _findTypeInLibrary(ResolvedLibraryResult library, String typeName) {
  final visitor = _TypeFinderVisitor([typeName]);
  library.element.accept(visitor);

  if (visitor.foundTypes[typeName] != null) {
    return visitor.foundTypes[typeName];
  }

  // Check imports
  for (final importElement in library.element.libraryImports) {
    final importedLibrary = importElement.importedLibrary;
    if (importedLibrary != null) {
      final exportNamespace = importedLibrary.exportNamespace;
      final element = exportNamespace.get(typeName);

      if (element is InterfaceElement || element is EnumElement) {
        return element;
      }
    }
  }

  return null;
}

class _TypeFinderVisitor extends GeneralizingElementVisitor<void> {
  final List<String> targetTypes;
  final Map<String, Element> foundTypes = {};

  _TypeFinderVisitor(this.targetTypes);

  @override
  void visitClassElement(ClassElement element) {
    if (targetTypes.contains(element.name)) {
      foundTypes[element.name] = element;
    }
    super.visitClassElement(element);
  }

  @override
  void visitEnumElement(EnumElement element) {
    if (targetTypes.contains(element.name)) {
      foundTypes[element.name] = element;
    }
    super.visitEnumElement(element);
  }

  @override
  void visitMixinElement(MixinElement element) {
    if (targetTypes.contains(element.name)) {
      foundTypes[element.name] = element;
    }
    super.visitMixinElement(element);
  }
}
