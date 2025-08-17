// ignore_for_file: implementation_imports

import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:analyzer/src/dart/ast/to_source_visitor.dart';

class SignatureVisitor extends ToSourceVisitor {
  SignatureVisitor(super.sink);

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _visitNodeList(node.metadata, separator: ' ', suffix: ' ');
    _visitToken(node.augmentKeyword, suffix: ' ');
    _visitToken(node.externalKeyword, suffix: ' ');
    _visitToken(node.constKeyword, suffix: ' ');
    _visitToken(node.factoryKeyword, suffix: ' ');
    _visitNode(node.returnType);
    _visitToken(node.name, prefix: '.');
    _visitNode(node.parameters);
    _visitNodeList(node.initializers, prefix: ' : ', separator: ', ');
    _visitNode(node.redirectedConstructor, prefix: ' = ');
    sink.write(' {}');
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    _visitNode(node.typeParameters);
    _visitNode(node.parameters);
    sink.write(' {}');
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _visitNodeList(node.metadata, separator: ' ', suffix: ' ');
    _visitToken(node.augmentKeyword, suffix: ' ');
    _visitToken(node.externalKeyword, suffix: ' ');
    _visitToken(node.modifierKeyword, suffix: ' ');
    _visitNode(node.returnType, suffix: ' ');
    _visitToken(node.propertyKeyword, suffix: ' ');
    _visitToken(node.operatorKeyword, suffix: ' ');
    _visitToken(node.name);
    if (!node.isGetter) {
      _visitNode(node.typeParameters);
      _visitNode(node.parameters);
    }
    sink.write(' {}');
  }

  /// Print the given [node], printing the [prefix] before the node,
  /// and [suffix] after the node, if it is non-`null`.
  void _visitNode(AstNode? node, {String prefix = '', String suffix = ''}) {
    if (node != null) {
      sink.write(prefix);
      node.accept(this);
      sink.write(suffix);
    }
  }

  /// Print a list of [nodes], separated by the given [separator]; if the list
  /// is not empty print [prefix] before the first node, and [suffix] after
  /// the last node.
  void _visitNodeList(
    List<AstNode> nodes, {
    String prefix = '',
    String separator = '',
    String suffix = '',
  }) {
    final length = nodes.length;
    if (length > 0) {
      sink.write(prefix);
      for (int i = 0; i < length; i++) {
        if (i > 0) {
          sink.write(separator);
        }
        nodes[i].accept(this);
      }
      sink.write(suffix);
    }
  }

  /// Print the given [token].
  void _visitToken(Token? token, {String prefix = '', String suffix = ''}) {
    if (token != null) {
      sink.write(prefix);
      sink.write(token.lexeme);
      sink.write(suffix);
    }
  }
}
