// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dart_mcp/server.dart';

import '../utils/sdk.dart';

/// Implementation of the check_dart_subtype tool using a shared analysis collection.
Future<CallToolResult> checkDartSubtype(
  CallToolRequest request,
  SdkSupport sdkSupport,
  AnalysisContextCollection collection,
) async {
  final filePath = request.arguments?['file_path'] as String?;
  final subtypeName = request.arguments?['subtype'] as String?;
  final supertypeName = request.arguments?['supertype'] as String?;

  if (filePath == null || subtypeName == null || supertypeName == null) {
    return CallToolResult(
      content: [
        TextContent(
          text: 'Missing required arguments: file_path, subtype, supertype',
        ),
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

    // Try to resolve types from the full context (including imports)
    final subtypeElement = _findTypeInLibrary(result, subtypeName);
    final supertypeElement = _findTypeInLibrary(result, supertypeName);

    if (subtypeElement == null) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Type "$subtypeName" not found. Make sure it\'s defined in $filePath or imported into it.',
          ),
        ],
        isError: true,
      );
    }

    if (supertypeElement == null) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Type "$supertypeName" not found. Make sure it\'s defined in $filePath or imported into it.',
          ),
        ],
        isError: true,
      );
    }

    // Check if subtype is assignable to supertype
    final typeSystem = result.element.typeSystem;
    final subtypeType = _getTypeFromElement(subtypeElement);
    final supertypeType = _getTypeFromElement(supertypeElement);

    if (subtypeType == null || supertypeType == null) {
      return CallToolResult(
        content: [
          TextContent(
            text: 'Failed to resolve type information for comparison',
          ),
        ],
        isError: true,
      );
    }

    final isAssignable = typeSystem.isAssignableTo(subtypeType, supertypeType);

    final relationship = isAssignable ? 'IS' : 'IS NOT';
    return CallToolResult(
      content: [
        TextContent(
          text:
              'Type analysis result:\n\n'
              '$subtypeName $relationship assignable to $supertypeName\n\n'
              'Details:\n'
              '- Subtype: ${subtypeType.getDisplayString(withNullability: true)}\n'
              '- Supertype: ${supertypeType.getDisplayString(withNullability: true)}\n'
              '- Subtype location: ${subtypeElement.source?.shortName ?? 'unknown'}\n'
              '- Supertype location: ${supertypeElement.source?.shortName ?? 'unknown'}',
        ),
      ],
    );
  } on Exception catch (e) {
    return CallToolResult(
      content: [TextContent(text: 'Failed to analyze types: $e')],
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

// Get the DartType from an element that represents a type
DartType? _getTypeFromElement(Element element) {
  if (element is ClassElement) {
    return element.thisType;
  } else if (element is TypeAliasElement) {
    return element.aliasedType;
  } else if (element is EnumElement) {
    return element.thisType;
  } else if (element is MixinElement) {
    return element.thisType;
  } else if (element is ExtensionTypeElement) {
    return element.thisType;
  }
  return null;
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
