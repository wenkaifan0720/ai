// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:dart_mcp/server.dart';

import 'dart_element_finder.dart' as element_finder;
import 'signature_visitor.dart';

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
      return CallToolResult(
        content: [
          TextContent(
            text: 'No element found at line $line, column $column in $filePath',
          ),
        ],
        isError: false,
      );
    }

    // Find the declaration of this element
    final declarationElement = _findDeclarationElement(element);

    // Check if this is a valid element that we can follow to its declaration
    final declarationSource = declarationElement.source;
    final nameOffset = declarationElement.nameOffset;

    // For certain element types (like CompilationUnit, imports, etc.)
    // or when we can't find a valid declaration, return an error
    if (declarationSource == null ||
        nameOffset < 0 ||
        declarationElement.displayName.isEmpty ||
        declarationElement.runtimeType.toString().contains('CompilationUnit')) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Cannot follow declaration for this element type: ${declarationElement.runtimeType}. '
                'Element: ${declarationElement.displayName}, '
                'Source: ${declarationSource?.fullName ?? 'null'}, '
                'NameOffset: $nameOffset',
          ),
        ],
        isError: true,
      );
    }

    // Parse the declaration file directly and find the node at the nameOffset
    final unit = await _parseFileDirectly(declarationSource.fullName);
    if (unit == null) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Could not parse declaration file: ${declarationSource.fullName}',
          ),
        ],
        isError: true,
      );
    }

    // Find the node at the nameOffset
    final targetNode = _findNodeAtOffset(unit, nameOffset);
    if (targetNode == null) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Could not find AST node at offset $nameOffset in declaration file: ${declarationSource.fullName}',
          ),
        ],
        isError: true,
      );
    }

    // Find the target node based on the getContainingDeclaration option
    final finalNode =
        getContainingDeclaration
            ? _findContainingDeclaration(targetNode) ?? targetNode
            : targetNode;

    // Generate signature directly from the AST node
    final signature = _generateSignatureFromAstNode(finalNode);

    return CallToolResult(
      content: [TextContent(text: signature)],
      isError: false,
    );
  } catch (e) {
    return CallToolResult(
      content: [
        TextContent(text: 'Error getting element declaration signature: $e'),
      ],
      isError: true,
    );
  }
}

/// Finds the declaration element for a given element.
///
/// If the element is already a declaration, returns it as-is.
/// If it's a reference to another element, follows it to the declaration.
/// For implicit property accessor elements, returns the associated variable element.
Element _findDeclarationElement(Element element) {
  // Handle PropertyAccessorElement (like implicit getters for widget parameters)
  if (element is PropertyAccessorElement) {
    // For implicit getters/setters, get the variable they're associated with
    final variable = element.variable2;
    if (variable != null) {
      return variable.declaration;
    }
  }

  // If this element has a declaration, follow it
  if (element.declaration case final declaration?) {
    return declaration;
  }

  // If it's already a declaration, return it
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
      return CallToolResult(
        content: [
          TextContent(
            text: 'No element found at line $line, column $column in $filePath',
          ),
        ],
        isError: false,
      );
    }

    // Find the target node based on the option
    final targetNode =
        getContainingDeclaration
            ? _findContainingDeclaration(node) ?? node
            : node;

    // Generate signature using the target node's source code
    final signature = _generateSignatureFromAstNode(targetNode);

    return CallToolResult(
      content: [TextContent(text: signature)],
      isError: false,
    );
  } catch (e) {
    return CallToolResult(
      content: [TextContent(text: 'Error getting element signature: $e')],
      isError: true,
    );
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
    if (current is ClassDeclaration ||
        current is MixinDeclaration ||
        current is ExtensionDeclaration ||
        current is EnumDeclaration ||
        current is TypeAlias ||
        current is FunctionDeclaration ||
        current is TopLevelVariableDeclaration) {
      return current;
    }
    current = current.parent;
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
