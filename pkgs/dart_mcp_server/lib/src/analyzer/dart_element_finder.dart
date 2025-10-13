// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
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

    // Get the resolved unit result directly (more reliable than library)
    final unitResult = await analysisContext.currentSession.getResolvedUnit(
      normalizedPath,
    );

    if (unitResult is! ResolvedUnitResult) {
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

    // If ElementLocator couldn't find an element, try to get it directly from the node
    if (element == null && node is ExtensionTypeDeclaration) {
      final declaredElement = node.declaredElement;
      if (declaredElement != null) {
        // Try to cast to Element2 directly (extension types should support this)
        try {
          return declaredElement as Element2;
        } catch (e) {
          // If casting fails, return null to indicate we couldn't resolve
          return null;
        }
      }
    }

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

/// Finds all locations of a symbol with the given name in a Dart file.
///
/// This method searches for all occurrences of identifiers, method names, class names,
/// etc. that match the given name and returns their line/column positions.
///
/// Returns a list of LocationInfo objects containing the positions and types of matches.
Future<List<LocationInfo>> findSymbolLocationsByName(
  AnalysisContext analysisContext,
  String filePath,
  String symbolName,
) async {
  try {
    // Normalize the file path
    final normalizedPath = path.normalize(filePath);

    // Get the resolved unit result directly
    final unitResult = await analysisContext.currentSession.getResolvedUnit(
      normalizedPath,
    );

    if (unitResult is! ResolvedUnitResult) {
      return [];
    }

    final locations = <LocationInfo>[];

    // Visit all nodes in the AST and find matches
    _findSymbolMatches(
      unitResult.unit,
      unitResult.content,
      symbolName,
      locations,
    );

    return locations;
  } catch (e) {
    return [];
  }
}

/// Recursively searches for symbol matches in the AST
void _findSymbolMatches(
  AstNode node,
  String content,
  String symbolName,
  List<LocationInfo> locations,
) {
  // Helper to add a location if the position is valid
  void addLocationAtOffset(int offset) {
    final pos = _getLineColumnFromOffset(content, offset);
    if (pos != null) {
      locations.add(LocationInfo(line: pos.line, column: pos.column));
    }
  }

  // Helper to check named declarations (classes, methods, functions, etc.)
  void checkNamedDeclaration(Token name) {
    if (name.lexeme == symbolName) {
      addLocationAtOffset(name.offset);
    }
  }

  // Handle different node types
  switch (node) {
    case ClassDeclaration(:var name):
    case MethodDeclaration(:var name):
    case FunctionDeclaration(:var name):
    case VariableDeclaration(:var name):
    case EnumDeclaration(:var name):
    case MixinDeclaration(:var name):
    case TypeAlias(:var name):
    case ExtensionTypeDeclaration(:var name):
      checkNamedDeclaration(name);

    case ConstructorDeclaration(:var name?):
    case ExtensionDeclaration(:var name?):
      checkNamedDeclaration(name);

    case FieldDeclaration(:var fields):
      // Fields can contain multiple variables
      for (final variable in fields.variables) {
        checkNamedDeclaration(variable.name);
      }

    case NamedType():
      // Type references (e.g., "Widget" in "Widget build()")
      final nameToken = node.name2;
      if (nameToken is Token && nameToken.lexeme == symbolName) {
        addLocationAtOffset(nameToken.offset);
      }
      // Also check import prefix (e.g., "prefix.Widget")
      final prefix = node.importPrefix;
      if (prefix != null && prefix.name.lexeme == symbolName) {
        addLocationAtOffset(prefix.name.offset);
      }

    case SimpleIdentifier(:var name) when name == symbolName:
      // Identifier references (in expressions, etc.)
      addLocationAtOffset(node.offset);

    default:
      break;
  }

  // Recursively search child nodes
  node.childEntities.whereType<AstNode>().forEach((child) {
    _findSymbolMatches(child, content, symbolName, locations);
  });
}

/// Converts character offset to line and column
LineColumnPosition? _getLineColumnFromOffset(String content, int offset) {
  try {
    final lines = content.split('\n');
    int currentOffset = 0;

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final lineLength = lines[lineIndex].length;
      if (currentOffset + lineLength >= offset) {
        final column = offset - currentOffset;
        return LineColumnPosition(line: lineIndex, column: column);
      }
      currentOffset += lineLength + 1; // +1 for newline
    }

    return null;
  } catch (e) {
    return null;
  }
}

/// Represents a location in a file
class LocationInfo {
  final int line;
  final int column;

  LocationInfo({required this.line, required this.column});
}

/// Represents a line/column position
class LineColumnPosition {
  final int line;
  final int column;

  LineColumnPosition({required this.line, required this.column});
}
