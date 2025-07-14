// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:dart_mcp/server.dart';

import 'dart_element_finder.dart' as element_finder;

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
  AnalysisContextCollection collection,
  String filePath,
  int line,
  int column, {
  bool getContainingDeclaration = true,
}) async {
  try {
    // Get the AST node at the specified location
    final node = await element_finder.getAstNodeAtLocation(
      collection,
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
  AstNode? current = node.parent;

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

/// Generates a signature from an AST node using its source representation.
String _generateSignatureFromAstNode(AstNode node) {
  final buffer = StringBuffer();

  // Add node type information
  buffer.writeln('AST Node Type: ${node.runtimeType}');
  buffer.writeln('');

  // Get the source code for this node
  final sourceCode = node.toSource();

  // For method and function declarations, or any node that might contain them,
  // we want to omit method bodies to save tokens while keeping the signature
  final processedCode = _simplifyMethodBodies(sourceCode);
  buffer.writeln('Signature:');
  buffer.writeln(processedCode);

  return buffer.toString();
}

/// Simplifies method/function bodies by replacing them with placeholders using an AST visitor.
String _simplifyMethodBodies(String source) {
  try {
    // Parse the source code to get a fresh AST with correct offsets
    final parseResult = parseString(
      content: source,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    // Create a visitor to collect all method/function nodes that need body simplification
    final visitor = _MethodBodySimplifierVisitor();
    parseResult.unit.accept(visitor);

    // Sort replacements in reverse order to avoid affecting offsets
    final replacements =
        visitor.replacements
          ..sort((a, b) => b.startOffset.compareTo(a.startOffset));

    // Apply all replacements
    String result = source;
    for (final replacement in replacements) {
      if (replacement.startOffset >= 0 &&
          replacement.endOffset <= result.length &&
          replacement.startOffset < replacement.endOffset) {
        result = result.replaceRange(
          replacement.startOffset,
          replacement.endOffset,
          replacement.newContent,
        );
      }
    }

    return result;
  } catch (e) {
    // If there's any error in processing, return the original source
    return source;
  }
}

/// Represents a replacement operation for simplifying method bodies.
class _BodyReplacement {
  final int startOffset;
  final int endOffset;
  final String newContent;

  _BodyReplacement(this.startOffset, this.endOffset, this.newContent);
}

/// AST visitor that finds method and function bodies that need to be simplified.
class _MethodBodySimplifierVisitor extends RecursiveAstVisitor<void> {
  final List<_BodyReplacement> replacements = [];

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _processMethodBody(node.body);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _processMethodBody(node.functionExpression.body);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    _processMethodBody(node.body);
    super.visitFunctionExpression(node);
  }

  void _processMethodBody(FunctionBody? body) {
    if (body == null) return;

    if (body is BlockFunctionBody) {
      final block = body.block;
      final openBraceOffset = block.offset;
      final closeBraceOffset = block.end;

      if (openBraceOffset >= 0 &&
          closeBraceOffset >= 0 &&
          closeBraceOffset > openBraceOffset) {
        // Replace only the content inside the braces, leaving empty braces
        replacements.add(
          _BodyReplacement(
            openBraceOffset + 1, // Start after the opening brace
            closeBraceOffset - 1, // End before the closing brace
            '', // Empty content
          ),
        );
      }
    } else if (body is ExpressionFunctionBody) {
      final arrowOffset = body.functionDefinition.offset; // Offset of '=>'
      final endOffset = body.end;

      if (arrowOffset >= 0 && endOffset >= 0 && endOffset > arrowOffset) {
        // Replace the arrow function with empty block function
        replacements.add(_BodyReplacement(arrowOffset, endOffset, '{}'));
      }
    }
  }
}
