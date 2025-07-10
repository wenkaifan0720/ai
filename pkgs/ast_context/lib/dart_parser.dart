import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/token.dart';

/// Parses a Dart file content, removes the body content of all methods/functions,
/// and optionally skips import directives and private members. Returns the modified string.
String parseDartFileSkipMethods(String content,
    {bool skipExpressionBodies = false,
    bool omitSkipComments = false,
    bool skipImports = false,
    bool skipPrivate = false,
    bool skipComments = false}) {
  // Parse the Dart code
  final parseResult = parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
  );

  final unit = parseResult.unit;

  // Create a visitor to collect all method/function/import nodes
  final nodeVisitor = _NodeCollectorVisitor(skipPrivate: skipPrivate);
  unit.accept(nodeVisitor);

  // Sort ranges in reverse order to avoid affecting offsets
  final replacements = nodeVisitor.nodes
    ..sort((a, b) => b.offset.compareTo(a.offset));

  // Create a buffer with the original content
  String result = content;

  // Replace each method body with empty content
  for (final node in replacements) {
    if (node is MethodDeclaration) {
      // If skipPrivate is true and this is a private method, remove it entirely
      if (skipPrivate && _isPrivate(node.name.lexeme)) {
        result = _removeEntireNode(result, node);
        continue;
      }

      // Only process block function bodies
      if (node.body is BlockFunctionBody) {
        final body = node.body as BlockFunctionBody;
        final openBraceOffset = body.block.offset;
        final closeBraceOffset = body.block.end;

        if (openBraceOffset != -1 && closeBraceOffset != -1) {
          // Calculate the line numbers for the skipped content
          final startLine = _getLineNumber(result, openBraceOffset);
          final endLine = _getLineNumber(result, closeBraceOffset - 1);

          // Replace the body with a comment on its own line showing the line range
          final replacement = omitSkipComments
              ? '{}'
              : '{\n  // Lines $startLine-$endLine skipped.\n}';
          result = result.replaceRange(
              openBraceOffset, closeBraceOffset, replacement);
        }
      } else if (skipExpressionBodies && node.body is ExpressionFunctionBody) {
        final body = node.body as ExpressionFunctionBody;
        final arrowOffset = body.functionDefinition.offset; // Offset of '=>'
        final expressionOffset = body.expression.offset; // Offset after '=>'

        // Adjust endOffset to potentially include trailing comments on the same line
        int endOffset = body.end;
        if (body.semicolon != null) {
          // Find the next newline character after the semicolon
          int newlinePos = result.indexOf('\n', body.semicolon!.end);
          if (newlinePos != -1) {
            // Include everything up to the newline
            endOffset = newlinePos;
          } else {
            // If no newline, go to the end of the string
            endOffset = result.length;
          }
        } else {
          // If no semicolon (rare for expression bodies, but possible?), use body.end
          endOffset = body.end;
        }

        if (arrowOffset != -1 && endOffset != -1) {
          // Calculate the line numbers for the skipped content
          final startLine = _getLineNumber(result, expressionOffset);
          final endLine = _getLineNumber(result, endOffset - 1);

          // Replace the body with a comment showing the line range
          if (omitSkipComments) {
            // Always replace starting from arrow
            result = result.replaceRange(arrowOffset, endOffset, '{}');
          } else {
            // Always replace starting from arrow
            final replacement = '{\n  // Lines $startLine-$endLine skipped.\n}';
            result = result.replaceRange(arrowOffset, endOffset, replacement);
          }
        }
      }
    } else if (node is FunctionDeclaration) {
      // If skipPrivate is true and this is a private function, remove it entirely
      if (skipPrivate && _isPrivate(node.name.lexeme)) {
        result = _removeEntireNode(result, node);
        continue;
      }

      // Only process block function bodies
      if (node.functionExpression.body is BlockFunctionBody) {
        final body = node.functionExpression.body as BlockFunctionBody;
        final openBraceOffset = body.block.offset;
        final closeBraceOffset = body.block.end;

        if (openBraceOffset != -1 && closeBraceOffset != -1) {
          // Calculate the line numbers for the skipped content
          final startLine = _getLineNumber(result, openBraceOffset);
          final endLine = _getLineNumber(result, closeBraceOffset - 1);

          // Replace the body with a comment on its own line showing the line range
          final replacement = omitSkipComments
              ? '{}'
              : '{\n  // Lines $startLine-$endLine skipped.\n}';
          result = result.replaceRange(
              openBraceOffset, closeBraceOffset, replacement);
        }
      } else if (skipExpressionBodies &&
          node.functionExpression.body is ExpressionFunctionBody) {
        final body = node.functionExpression.body as ExpressionFunctionBody;
        final arrowOffset = body.functionDefinition.offset; // Offset of '=>'
        final expressionOffset = body.expression.offset; // Offset after '=>'

        // Adjust endOffset to potentially include trailing comments on the same line
        int endOffset = body.end;
        if (body.semicolon != null) {
          // Find the next newline character after the semicolon
          int newlinePos = result.indexOf('\n', body.semicolon!.end);
          if (newlinePos != -1) {
            // Include everything up to the newline
            endOffset = newlinePos;
          } else {
            // If no newline, go to the end of the string
            endOffset = result.length;
          }
        } else {
          // If no semicolon (rare for expression bodies, but possible?), use body.end
          endOffset = body.end;
        }

        if (arrowOffset != -1 && endOffset != -1) {
          // Calculate the line numbers for the skipped content
          final startLine = _getLineNumber(result, expressionOffset);
          final endLine = _getLineNumber(result, endOffset - 1);

          // Replace the body with a comment showing the line range
          if (omitSkipComments) {
            // Always replace starting from arrow
            result = result.replaceRange(arrowOffset, endOffset, '{}');
          } else {
            // Always replace starting from arrow
            final replacement = '{\n  // Lines $startLine-$endLine skipped.\n}';
            result = result.replaceRange(arrowOffset, endOffset, replacement);
          }
        }
      }
    } else if (node is ImportDirective) {
      if (skipImports) {
        // Find the start of the line
        int lineStartOffset = result.lastIndexOf('\n', node.offset) + 1;
        // Find the end of the line (offset of the next newline, or end of string)
        int lineEndOffset = result.indexOf('\n', node.end);
        if (lineEndOffset == -1) {
          lineEndOffset = result.length; // End of file
        } else {
          lineEndOffset = lineEndOffset + 1; // Include the newline itself
        }

        // Always replace the entire line with an empty string
        final replacement = '';
        // Ensure offsets are valid before replacing
        if (lineStartOffset < lineEndOffset &&
            lineStartOffset >= 0 &&
            lineEndOffset <= result.length) {
          result =
              result.replaceRange(lineStartOffset, lineEndOffset, replacement);
        }
      }
    } else if (node is FieldDeclaration) {
      // If skipPrivate is true and this field contains private variables, remove it entirely
      if (skipPrivate) {
        // Check if any of the fields in this declaration are private
        bool hasPrivateFields = node.fields.variables
            .any((variable) => _isPrivate(variable.name.lexeme));
        if (hasPrivateFields) {
          result = _removeEntireNode(result, node);
        }
      }
    } else if (node is ClassDeclaration) {
      // If skipPrivate is true and this is a private class, remove it entirely
      if (skipPrivate && _isPrivate(node.name.lexeme)) {
        result = _removeEntireNode(result, node);
      }
    }
  }

  // If skipComments is true, do a separate pass to remove comments
  if (skipComments) {
    result = _removeComments(result);
  }

  return result;
}

/// Calculate the 1-based line number for a given position in the text
int _getLineNumber(String text, int position) {
  if (position < 0 || position >= text.length) {
    return -1;
  }

  int lineCount = 1;
  for (int i = 0; i < position; i++) {
    if (text[i] == '\n') {
      lineCount++;
    }
  }

  return lineCount;
}

/// Check if a name is private (starts with underscore)
bool _isPrivate(String name) {
  return name.startsWith('_');
}

/// Remove an entire node from the text, including surrounding whitespace
String _removeEntireNode(String text, AstNode node) {
  int startOffset = node.offset;
  int endOffset = node.end;

  if (startOffset < 0 ||
      endOffset < 0 ||
      startOffset >= text.length ||
      endOffset > text.length) {
    return text;
  }

  // Find the start of the line containing the node
  int lineStartOffset = text.lastIndexOf('\n', startOffset) + 1;

  // Find the end of the line containing the node's end, or the next line
  int lineEndOffset = text.indexOf('\n', endOffset);
  if (lineEndOffset == -1) {
    lineEndOffset = text.length; // End of file
  } else {
    lineEndOffset = lineEndOffset + 1; // Include the newline itself
  }

  // Remove the entire line(s)
  return text.replaceRange(lineStartOffset, lineEndOffset, '');
}

/// Visitor to collect all method, function, and import declarations
class _NodeCollectorVisitor extends RecursiveAstVisitor<void> {
  final List<AstNode> nodes = [];
  final bool skipPrivate;

  _NodeCollectorVisitor({required this.skipPrivate});

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    nodes.add(node);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    nodes.add(node);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    nodes.add(node);
    super.visitImportDirective(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (skipPrivate) {
      // Check if any of the fields in this declaration are private
      bool hasPrivateFields = node.fields.variables
          .any((variable) => _isPrivate(variable.name.lexeme));
      if (hasPrivateFields) {
        nodes.add(node);
      }
    }
    super.visitFieldDeclaration(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (skipPrivate && _isPrivate(node.name.lexeme)) {
      nodes.add(node);
    }
    super.visitClassDeclaration(node);
  }
}

/// Remove all comments from the given Dart code
String _removeComments(String content) {
  try {
    // Parse the content to get tokens
    final parseResult = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    final unit = parseResult.unit;
    final commentRanges = <_Range>[];

    // Walk through all tokens to find comments
    var token = unit.beginToken;
    while (token != null) {
      // Check for preceding comments
      Token? commentToken = token.precedingComments;
      while (commentToken != null) {
        // Find the start and end of the comment
        int startOffset = commentToken.offset;
        int endOffset = commentToken.end;

        // For single-line comments, include the trailing newline if present
        if (commentToken.lexeme.startsWith('//')) {
          // Find the next newline character after the comment
          if (endOffset < content.length) {
            int newlinePos = content.indexOf('\n', endOffset);
            if (newlinePos != -1 && newlinePos == endOffset) {
              endOffset = newlinePos + 1; // Include the newline
            }
          }
        }

        commentRanges.add(_Range(startOffset, endOffset));
        commentToken = commentToken.next;
      }

      if (token.isEof) break;
      token = token.next!;
    }

    // Sort comment ranges in reverse order to avoid affecting offsets
    commentRanges.sort((a, b) => b.start.compareTo(a.start));

    // Remove all comments
    String result = content;
    for (final range in commentRanges) {
      // Validate range to avoid errors
      if (range.start >= 0 &&
          range.end <= result.length &&
          range.start <= range.end) {
        result = result.replaceRange(range.start, range.end, '');
      }
    }

    return result;
  } catch (e) {
    // If parsing fails, return original content
    return content;
  }
}

/// Represents a range with start and end offsets
class _Range {
  final int start;
  final int end;

  _Range(this.start, this.end);
}
