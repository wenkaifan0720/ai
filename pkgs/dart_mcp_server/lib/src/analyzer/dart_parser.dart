import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Parses a Dart file content, removes the body content of all methods/functions,
/// and optionally skips import directives. Returns the modified string.
String parseDartFileSkipMethods(String content,
    {bool skipExpressionBodies = false,
    bool omitSkipComments = false,
    bool skipImports = false}) {
  // Parse the Dart code
  final parseResult = parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
  );

  final unit = parseResult.unit;

  // Create a visitor to collect all method/function/import nodes
  final nodeVisitor = _NodeCollectorVisitor();
  unit.accept(nodeVisitor);

  // Sort ranges in reverse order to avoid affecting offsets
  final replacements = nodeVisitor.nodes
    ..sort((a, b) => b.offset.compareTo(a.offset));

  // Create a buffer with the original content
  String result = content;

  // Replace each method body with empty content
  for (final node in replacements) {
    if (node is MethodDeclaration) {
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
            result = result.replaceRange(arrowOffset, endOffset, '=> ;');
          } else {
            // Always replace starting from arrow
            final replacement =
                '=> // Expression body skipped (Lines $startLine-$endLine);';
            result = result.replaceRange(arrowOffset, endOffset, replacement);
          }
        }
      }
    } else if (node is FunctionDeclaration) {
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
            result = result.replaceRange(arrowOffset, endOffset, '=> ;');
          } else {
            // Always replace starting from arrow
            final replacement =
                '=> // Expression body skipped (Lines $startLine-$endLine);';
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
    }
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

/// Visitor to collect all method, function, and import declarations
class _NodeCollectorVisitor extends RecursiveAstVisitor<void> {
  final List<AstNode> nodes = [];

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
}
