// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element2.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/ast/element_locator.dart';
import 'package:path/path.dart' as path;

/// Gets the AST node at a specific location in a Dart file.
///
/// This method finds the most specific AST node (class, method, variable, etc.)
/// at the given line and column position.
///
/// Returns null if no node is found at that location or if there's an error.
Future<AstNode?> getAstNodeAtLocation(
  AnalysisContext analysisContext,
  String filePath,
  int line,
  int column,
) async {
  try {
    // Normalize the file path
    final normalizedPath = path.normalize(filePath);

    // Get the resolved library result (includes full library context)
    final libraryResult = await analysisContext.currentSession
        .getResolvedLibrary(normalizedPath);

    if (libraryResult is! ResolvedLibraryResult) {
      return null;
    }

    // Find the specific unit within the library that matches our file
    ResolvedUnitResult? unitResult;
    for (final unit in libraryResult.units) {
      if (path.normalize(unit.path) == normalizedPath) {
        unitResult = unit;
        break;
      }
    }

    if (unitResult == null) {
      return null;
    }

    // Find the node at the specific location
    final offset = _getOffsetFromLineColumn(unitResult.content, line, column);
    if (offset == null) {
      return null;
    }

    // Use our simplified node locator to find the most specific node
    final node = _locateNode(unitResult.unit, offset);

    return node;
  } catch (e) {
    return null;
  }
}

/// Gets the Element2 at a specific location in a Dart file.
///
/// This method finds the semantic element (class, method, variable, etc.)
/// at the given line and column position.
///
/// Returns null if no element is found at that location or if there's an error.
Future<Element2?> getElementAtLocation(
  AnalysisContext analysisContext,
  String filePath,
  int line,
  int column,
) async {
  try {
    // Get the AST node at the location
    final node = await getAstNodeAtLocation(
      analysisContext,
      filePath,
      line,
      column,
    );
    if (node == null) {
      return null;
    }

    // Use the built-in ElementLocator for robust and comprehensive element
    // extraction
    final element = ElementLocator.locate2(node);

    return element;
  } catch (e) {
    return null;
  }
}

/// Converts line and column to character offset in the file content
int? _getOffsetFromLineColumn(String content, int line, int column) {
  try {
    final lines = content.split('\n');

    if (line < 0 || line >= lines.length) {
      return null;
    }

    if (column < 0 || column > lines[line].length) {
      return null;
    }

    int offset = 0;
    for (int i = 0; i < line; i++) {
      offset += lines[i].length + 1; // +1 for newline
    }
    offset += column;

    return offset;
  } catch (e) {
    return null;
  }
}

/// Uses a simple approach to locate the most specific node at the given offset
/// This is similar to NodeLocator but simplified for our needs
AstNode? _locateNode(AstNode root, int offset) {
  // Find the node that contains the offset
  AstNode? result;

  void visitNode(AstNode node) {
    if (node.offset <= offset && offset <= node.end) {
      result = node;
      // Continue to find more specific child nodes
      node.childEntities.whereType<AstNode>().forEach(visitNode);
    }
  }

  visitNode(root);
  return result;
}
