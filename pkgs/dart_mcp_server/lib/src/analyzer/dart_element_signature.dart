// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/type.dart';
// ignore: implementation_imports
import 'package:dart_mcp/server.dart';

import 'dart_element_finder.dart' as element_finder;
import 'signature_visitor.dart';

/// Helper to create a success result with text content
CallToolResult _successResult(String text) {
  return CallToolResult(content: [TextContent(text: text)], isError: false);
}

/// Helper to create an error result with error message
CallToolResult _errorResult(String message) {
  return CallToolResult(content: [TextContent(text: message)], isError: true);
}

/// Try to extract an Element2 from a DartType using typed analyzer APIs.
Element2? _element2FromDartType(DartType? type) {
  if (type == null) return null;

  // For InterfaceType, get the element3 (Element2)
  if (type is InterfaceType) {
    return type.element3;
  }

  return null;
}

/// Try to resolve a variable element's declared type to its type-defining Element2.
Element2? _tryResolveVariableElementType(Element2 variableElement) {
  if (variableElement is VariableElement2) {
    return _element2FromDartType(variableElement.type);
  }
  return null;
}

/// Generate signature from an Element2 using its displayString2.
String _generateSignatureFromElement(Element2 element) {
  if (element is TypeDefiningElement2 || element is InterfaceElement2) {
    return element.displayString2(multiline: true);
  }
  return element.displayName;
}

/// Gets the signature of the declaration for an element at a specific location.
///
/// This function finds the semantic element at the given location, follows it to its
/// declaration, and returns the declaration's source code representation with method bodies omitted.
///
/// If [getContainingDeclaration] is true, walks up the AST tree to find the
/// containing class, enum, mixin, extension, type alias, function, or
/// top-level variable declaration and returns its signature instead.
///
/// Returns a [CallToolResult] with the signature information or an error message.
Future<CallToolResult> getElementDeclarationSignature(
  AnalysisContext analysisContext,
  String filePath,
  int line,
  int column, {
  bool getContainingDeclaration = true,
}) async {
  try {
    // Get the semantic element at the specified location
    final element = await element_finder.getElementAtLocation(
      analysisContext,
      filePath,
      line,
      column,
    );

    if (element == null) {
      return _successResult(
        'No element found at line $line, column $column in $filePath',
      );
    }

    // Find the declaration of this element (with type-following and AST fallback).
    final declarationElement = await _findDeclarationElement(
      element,
      analysisContext: analysisContext,
      filePath: filePath,
      line: line,
      column: column,
    );

    // If we couldn't find a declaration element, return the original element
    if (declarationElement == null) {
      return _successResult(_generateSignatureFromElement(element));
    }

    // Get declaration source and offset
    final declarationSource =
        declarationElement.firstFragment.libraryFragment?.source;
    final nameOffset = declarationElement.firstFragment.nameOffset2;

    // Try to parse and locate the declaration node
    if (declarationSource == null || nameOffset == null) {
      return _successResult(_generateSignatureFromElement(declarationElement));
    }

    final unit = await _parseFileDirectly(declarationSource.fullName);
    if (unit == null) {
      return _successResult(_generateSignatureFromElement(declarationElement));
    }

    final targetNode = _findNodeAtOffset(unit, nameOffset);
    if (targetNode == null) {
      return _successResult(_generateSignatureFromElement(declarationElement));
    }

    // Find the target node based on the getContainingDeclaration option
    final finalNode = getContainingDeclaration
        ? _findContainingDeclaration(targetNode) ?? targetNode
        : targetNode;

    // Generate signature directly from the AST node
    final signature = _generateSignatureFromAstNode(finalNode);

    return _successResult(signature);
  } catch (e) {
    return _errorResult('Error getting element declaration signature: $e');
  }
}

/// Finds the declaration element for a given element.
///
/// If the element is already a declaration, returns it as-is.
/// If it's a reference to another element, follows it to the declaration.
/// For implicit property accessor elements, returns the associated variable element.
/// For variables, follows the type to get the type's declaration.
/// Returns null if no declaration element can be found.
Future<Element2?> _findDeclarationElement(
  Element2 element, {
  AnalysisContext? analysisContext,
  String? filePath,
  int? line,
  int? column,
}) async {
  // Unwrap implicit accessors to their underlying variable.
  if (element is PropertyAccessorElement2) {
    final variable = element.variable3;
    if (variable != null) {
      element = variable.firstFragment.element;
    }
  }

  // For variables, try to resolve their declared type element
  if (element is VariableElement2) {
    final typeElement = _tryResolveVariableElementType(element);
    if (typeElement != null) return typeElement;
  }

  // Type-defining elements (classes, enums, mixins, etc.) are already declarations
  // Return them as-is since they represent the actual definition
  if (element is InterfaceElement2 ||
      element is EnumElement2 ||
      element is MixinElement2 ||
      element is ExtensionElement2 ||
      element is ExtensionTypeElement2) {
    return element;
  }

  // For identifier nodes at cursor, try static type resolution
  if (analysisContext != null &&
      filePath != null &&
      line != null &&
      column != null) {
    try {
      final node = await element_finder.getAstNodeAtLocation(
        analysisContext,
        filePath,
        line,
        column,
      );
      if (node is SimpleIdentifier) {
        final staticType = node.staticType;
        if (staticType != null) {
          final typeEl2 = _element2FromDartType(staticType);
          if (typeEl2 != null) return typeEl2;
        }
      }
    } catch (_) {}
  }

  // Constructors → enclosing type.
  if (element is ConstructorElement2) {
    return element.enclosingElement2;
  }

  // Type aliases → aliased element when available.
  if (element is TypeAliasElement2) {
    final aliased = element.aliasedElement2;
    if (aliased != null) {
      return aliased;
    }
  }

  // Multiply defined → pick first conflicting and resolve again.
  if (element is MultiplyDefinedElement2 &&
      element.conflictingElements2.isNotEmpty) {
    return _findDeclarationElement(
      element.conflictingElements2.first,
      analysisContext: analysisContext,
      filePath: filePath,
      line: line,
      column: column,
    );
  }

  // Already a declaration or unsupported case: return as-is.
  return element;
}

/// Parses a Dart file directly and returns its AST.
Future<CompilationUnit?> _parseFileDirectly(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    final content = await file.readAsString();
    final parseResult = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    return parseResult.unit;
  } catch (e) {
    return null;
  }
}

/// Finds the AST node at a specific character offset.
AstNode? _findNodeAtOffset(CompilationUnit unit, int offset) {
  AstNode? result;

  void visitNode(AstNode node) {
    if (node.offset <= offset && offset <= node.end) {
      result = node;
      // Continue to find more specific child nodes
      node.childEntities.whereType<AstNode>().forEach(visitNode);
    }
  }

  visitNode(unit);
  return result;
}

/// Gets the signature and detailed information about an element at a specific location.
///
/// This function finds the AST node at the given location and returns its
/// source code representation, optionally with method bodies omitted.
///
/// If [getContainingDeclaration] is true, walks up the AST tree to find the
/// containing class, enum, mixin, extension, type alias, function, or
/// top-level variable declaration and returns its signature instead.
///
/// Returns a [CallToolResult] with the signature information or an error message.
Future<CallToolResult> getElementSignature(
  AnalysisContext analysisContext,
  String filePath,
  int line,
  int column, {
  bool getContainingDeclaration = true,
}) async {
  try {
    // Get the AST node at the specified location
    final node = await element_finder.getAstNodeAtLocation(
      analysisContext,
      filePath,
      line,
      column,
    );

    if (node == null) {
      return _successResult(
        'No element found at line $line, column $column in $filePath',
      );
    }

    // Find the target node based on the option
    final targetNode = getContainingDeclaration
        ? _findContainingDeclaration(node) ?? node
        : node;

    // Generate signature using the target node's source code
    final signature = _generateSignatureFromAstNode(targetNode);

    return _successResult(signature);
  } catch (e) {
    return _errorResult('Error getting element signature: $e');
  }
}

/// Walks up the AST tree to find the containing declaration.
///
/// Stops at the first node that is one of:
/// - ClassDeclaration
/// - MixinDeclaration
/// - ExtensionDeclaration
/// - EnumDeclaration
/// - TypeAlias
/// - FunctionDeclaration
/// - TopLevelVariableDeclaration
///
/// Returns null if no containing declaration is found.
AstNode? _findContainingDeclaration(AstNode node) {
  var current = node.parent;

  while (current != null) {
    // Use switch expression for cleaner type checking
    switch (current) {
      case ClassDeclaration() ||
          MixinDeclaration() ||
          ExtensionDeclaration() ||
          EnumDeclaration() ||
          TypeAlias() ||
          FunctionDeclaration() ||
          TopLevelVariableDeclaration():
        return current;
      default:
        current = current.parent;
    }
  }

  return null;
}

/// Generates a signature from an AST node using the SignatureVisitor.
String _generateSignatureFromAstNode(AstNode node) {
  final buffer = StringBuffer();
  final visitor = SignatureVisitor(buffer);
  node.accept(visitor);
  return buffer.toString();
}

/// Gets the signatures of all elements with the given name in a Dart file.
///
/// This function searches for all occurrences of symbols with the specified name,
/// finds their locations, and returns the signature of each declaration.
///
/// Returns a [CallToolResult] with a list of signature information or an error message.
Future<CallToolResult> getElementDeclarationSignaturesByName(
  AnalysisContext analysisContext,
  String filePath,
  String symbolName, {
  bool getContainingDeclaration = true,
}) async {
  try {
    // Find all locations of the symbol in the file
    final locations = await element_finder.findSymbolLocationsByName(
      analysisContext,
      filePath,
      symbolName,
    );

    if (locations.isEmpty) {
      return _successResult(
        'No elements found with name "$symbolName" in $filePath',
      );
    }

    final uniqueSignatures = <String>{};

    // Get signature for each location and deduplicate by signature content
    for (final location in locations) {
      try {
        // Get the signature at this specific location
        final signatureResult = await getElementDeclarationSignature(
          analysisContext,
          filePath,
          location.line,
          location.column,
          getContainingDeclaration: getContainingDeclaration,
        );

        // Only process successful results
        if ((signatureResult.isError != true) &&
            signatureResult.content.isNotEmpty) {
          final signatureText = signatureResult.content.first;
          if (signatureText is TextContent) {
            uniqueSignatures.add(signatureText.text);
          }
        }
      } catch (e) {
        // Skip this location if there's an error getting its signature
        continue;
      }
    }

    final signatures = uniqueSignatures.toList();

    if (signatures.isEmpty) {
      return _successResult(
        'Found ${locations.length} occurrences of "$symbolName" but could not retrieve signatures for any of them.',
      );
    }

    // Format the results as a readable text response
    final buffer = StringBuffer();
    buffer.writeln(
      'Found ${signatures.length} signature(s) for "$symbolName":',
    );
    buffer.writeln();

    for (int i = 0; i < signatures.length; i++) {
      final signature = signatures[i];

      buffer.writeln('${i + 1}.');
      buffer.writeln(signature);

      if (i < signatures.length - 1) {
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    return _successResult(buffer.toString());
  } catch (e) {
    return _errorResult(
      'Error getting element declaration signatures by name: $e',
    );
  }
}
