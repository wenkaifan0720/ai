// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_mcp/server.dart';

import 'dart_element_finder.dart' as element_finder;

/// Gets the signature and detailed information about an element at a specific location.
///
/// This function finds the AST node at the given location and returns its
/// source code representation, optionally with method bodies omitted.
///
/// Returns a [CallToolResult] with the signature information or an error message.
Future<CallToolResult> getElementSignature(
  AnalysisContextCollection collection,
  String filePath,
  int line,
  int column,
) async {
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

    // Generate signature using the node's source code
    final signature = _generateSignatureFromAstNode(node);

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

/// Generates a signature from an AST node using its source representation.
String _generateSignatureFromAstNode(AstNode node) {
  final buffer = StringBuffer();

  // Add node type information
  buffer.writeln('AST Node Type: ${node.runtimeType}');
  buffer.writeln('');

  // Get the source code for this node
  final sourceCode = node.toSource();

  // For method and function declarations, we might want to omit the body
  // to save tokens while keeping the signature
  if (node is MethodDeclaration || node is FunctionDeclaration) {
    final processedCode = _simplifyMethodBody(sourceCode);
    buffer.writeln('Signature:');
    buffer.writeln(processedCode);
  } else {
    buffer.writeln('Source:');
    buffer.writeln(sourceCode);
  }

  return buffer.toString();
}

/// Simplifies method/function bodies by replacing them with placeholders.
String _simplifyMethodBody(String source) {
  // For now, just return the source as-is
  // We could later apply the same logic from dart_parser.dart
  // to remove method bodies if needed
  return source;
}
