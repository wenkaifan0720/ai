// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:dart_mcp/server.dart';

import '../../utils/sdk.dart';

/// Implementation of the get_dart_type_hierarchy tool using a shared analysis collection.
Future<CallToolResult> getDartTypeHierarchy(
  CallToolRequest request,
  SdkSupport sdkSupport,
  AnalysisContextCollection collection,
) async {
  final filePath = request.arguments?['file_path'] as String?;
  final typeName = request.arguments?['type_name'] as String?;

  if (filePath == null || typeName == null) {
    return CallToolResult(
      content: [
        TextContent(text: 'Missing required arguments: file_path, type_name'),
      ],
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

    // Only interface elements have inheritance hierarchies
    if (typeElement is! InterfaceElement) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Type "$typeName" is not an interface type (class, enum, mixin) and does not have a hierarchy.',
          ),
        ],
      );
    }

    var hierarchyText = 'Type hierarchy for $typeName:\n\n';

    // Get direct superclass
    if (typeElement.supertype != null &&
        typeElement.supertype!.element.name != 'Object') {
      hierarchyText += 'Direct superclass:\n';
      hierarchyText +=
          '- ${typeElement.supertype!.getDisplayString(withNullability: true)}\n\n';
    }

    // Get all supertypes using the built-in getter
    final allSupertypes =
        typeElement.allSupertypes
            .where((type) => type.element.name != 'Object')
            .toList();

    if (allSupertypes.isNotEmpty) {
      // Categorize supertypes
      final superclasses = <String>[];
      final interfaces = <String>[];
      final mixins = <String>[];

      for (final supertype in allSupertypes) {
        final element = supertype.element;
        final displayString = supertype.getDisplayString(withNullability: true);

        if (element is ClassElement) {
          superclasses.add(displayString);
        } else if (element is MixinElement) {
          mixins.add(displayString);
        } else {
          // Treat everything else as interfaces (including abstract classes used as interfaces)
          interfaces.add(displayString);
        }
      }

      if (superclasses.isNotEmpty) {
        hierarchyText += 'All superclasses:\n';
        hierarchyText += '- ${superclasses.join('\n- ')}\n\n';
      }

      if (interfaces.isNotEmpty) {
        hierarchyText += 'Implemented interfaces:\n';
        hierarchyText += '- ${interfaces.join('\n- ')}\n\n';
      }

      if (mixins.isNotEmpty) {
        hierarchyText += 'Mixed in types:\n';
        hierarchyText += '- ${mixins.join('\n- ')}\n\n';
      }
    } else {
      hierarchyText += 'No explicit inheritance (extends Object directly)\n';
    }

    return CallToolResult(content: [TextContent(text: hierarchyText)]);
  } on Exception catch (e) {
    return CallToolResult(
      content: [TextContent(text: 'Failed to analyze type hierarchy: $e')],
      isError: true,
    );
  }
}

// Helper method to find types in the library and its imports
Element? _findTypeInLibrary(ResolvedLibraryResult library, String typeName) {
  // First check types defined directly in this library
  final directVisitor = _TypeFinderVisitor([typeName]);
  library.element.accept(directVisitor);

  if (directVisitor.foundTypes[typeName] != null) {
    return directVisitor.foundTypes[typeName];
  }

  // Then check imported libraries using their export namespace
  // This automatically handles re-exports correctly
  for (final importElement in library.element.libraryImports) {
    final importedLibrary = importElement.importedLibrary;
    if (importedLibrary != null) {
      // Use the export namespace to get all accessible symbols
      final exportNamespace = importedLibrary.exportNamespace;
      final element = exportNamespace.get(typeName);

      // Check if this element represents a type that can be used in type checking
      if (_canRepresentType(element)) {
        // Check if this type is accessible given import show/hide constraints
        if (_isTypeAccessible(importElement, typeName)) {
          return element;
        }
      }
    }
  }

  return null;
}

// Check if an element can represent a type for type system analysis
bool _canRepresentType(Element? element) {
  return element is ClassElement ||
      element is TypeAliasElement ||
      element is EnumElement ||
      element is MixinElement ||
      element is ExtensionTypeElement;
}

// Check if a type is accessible given import constraints
bool _isTypeAccessible(LibraryImportElement importElement, String typeName) {
  // If there are shown names, the type must be in the list
  if (importElement.combinators.any((c) => c is ShowElementCombinator)) {
    final showCombiners =
        importElement.combinators.whereType<ShowElementCombinator>();
    return showCombiners.any((show) => show.shownNames.contains(typeName));
  }

  // If there are hidden names, the type must not be in the list
  if (importElement.combinators.any((c) => c is HideElementCombinator)) {
    final hideCombiners =
        importElement.combinators.whereType<HideElementCombinator>();
    return !hideCombiners.any((hide) => hide.hiddenNames.contains(typeName));
  }

  // No constraints, so it's accessible
  return true;
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
  void visitTypeAliasElement(TypeAliasElement element) {
    if (targetTypes.contains(element.name)) {
      foundTypes[element.name] = element;
    }
    super.visitTypeAliasElement(element);
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

  @override
  void visitExtensionTypeElement(ExtensionTypeElement element) {
    if (targetTypes.contains(element.name)) {
      foundTypes[element.name] = element;
    }
    super.visitExtensionTypeElement(element);
  }
}
