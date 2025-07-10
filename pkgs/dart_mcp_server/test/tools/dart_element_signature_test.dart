// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp_server/src/mixins/dart_file_analyzer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../test_harness.dart';

void main() {
  late TestHarness testHarness;
  late AppDebugSession debugSession;

  setUp(() async {
    testHarness = await TestHarness.start();

    // Start a debug session to establish the counter_app as a project root
    // This allows the shared analysis context to be properly initialized
    debugSession = await testHarness.startDebugSession(
      p.join('test_fixtures', 'counter_app'),
      'lib/main.dart',
      isFlutter: true,
    );
  });

  tearDown(() async {
    await testHarness.stopDebugSession(debugSession);
  });

  group('get_signature tool', () {
    late Tool getSignatureTool;

    setUp(() async {
      final tools = (await testHarness.mcpServerConnection.listTools()).tools;
      getSignatureTool = tools.singleWhere(
        (t) => t.name == DartFileAnalyzerSupport.getSignatureTool.name,
      );
    });

    group('class elements', () {
      test('gets signature for MyApp class', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test clicking on the MyApp class name
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'file_path': testFilePath,
              'line': 10, // Zero-based line number for MyApp class (line 11)
              'column': 6, // Position within "class MyApp"
            },
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('ClassDeclaration'));
        expect(signatureText, contains('class MyApp'));
        expect(signatureText, contains('extends StatelessWidget'));
      });

      test('gets signature for MyHomePage class', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test clicking on the MyHomePage class name
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'file_path': testFilePath,
              'line':
                  25, // Zero-based line number for MyHomePage class (line 26)
              'column': 6, // Position within "class MyHomePage"
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('ClassDeclaration'));
        expect(signatureText, contains('class MyHomePage'));
        expect(signatureText, contains('extends StatefulWidget'));
      });
    });

    group('method elements', () {
      test('gets signature for build method', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test clicking on the build method name in MyApp
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'file_path': testFilePath,
              'line':
                  14, // Zero-based line number for build method in MyApp (line 15)
              'column': 10, // Position within "Widget build"
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('MethodDeclaration'));
        expect(signatureText, contains('Widget build'));
        expect(signatureText, contains('BuildContext context'));
        expect(signatureText, contains('@override'));
      });

      test('gets signature for _incrementCounter method', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test clicking on the _incrementCounter method name
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'file_path': testFilePath,
              'line':
                  41, // Zero-based line number for _incrementCounter method (line 42)
              'column': 8,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('MethodDeclaration'));
        expect(signatureText, contains('void _incrementCounter'));
        expect(signatureText, contains('setState'));
      });
    });

    group('field/variable elements', () {
      test('gets signature for _counter field', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test clicking on the _counter field
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'file_path': testFilePath,
              'line': 35, // Zero-based line number for _counter field (line 36)
              'column': 6, // Position within "int _counter"
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('VariableDeclaration'));
        expect(signatureText, contains('_counter'));
      });
    });

    group('constructor elements', () {
      test('gets signature for MyHomePage constructor', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test clicking on the MyHomePage constructor
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'file_path': testFilePath,
              'line':
                  26, // Zero-based line number for MyHomePage constructor (line 27)
              'column': 12, // Position within "const MyHomePage"
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('SimpleIdentifier'));
        expect(signatureText, contains('MyHomePage'));
      });
    });

    group('edge cases', () {
      test('handles location with compilation unit element', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test clicking on whitespace area - should find compilation unit
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'file_path': testFilePath,
              'line': 1, // Line with just whitespace or comment
              'column': 0,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('CompilationUnit'));
      });

      test('handles invalid file path', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'file_path': '/nonexistent/file.dart',
              'line': 0,
              'column': 0,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('No element found'));
      });

      test('handles missing arguments', () async {
        try {
          final result = await testHarness.callToolWithRetry(
            CallToolRequest(
              name: getSignatureTool.name,
              arguments: {
                'file_path': 'test.dart',
                // Missing line and column
              },
            ),
          );

          expect(result.isError, isTrue);
          final errorText = (result.content.first as TextContent).text;
          expect(errorText, contains('Missing required argument'));
        } catch (e) {
          // Expected to throw due to missing required arguments
          expect(e.toString(), contains('Missing required argument'));
        }
      });

      test('handles negative line/column values', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {'file_path': testFilePath, 'line': -1, 'column': -1},
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('No element found'));
      });
    });

    group('library information', () {
      test('includes library information in signature', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'file_path': testFilePath,
              'line': 10, // MyApp class
              'column': 6,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('ClassDeclaration'));
        expect(signatureText, contains('class MyApp'));
      });
    });

    group('element properties', () {
      test('shows correct visibility information', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test public class
        final publicResult = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'file_path': testFilePath,
              'line': 10, // MyApp class (public)
              'column': 6,
            },
          ),
        );

        expect(publicResult.isError, isNot(true));
        final publicSignature =
            (publicResult.content.first as TextContent).text;
        expect(publicSignature, contains('AST Node Type:'));
        expect(publicSignature, contains('class MyApp'));

        // Test private field
        final privateResult = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'file_path': testFilePath,
              'line': 35, // _counter field (private)
              'column': 6, // Position within "int _counter"
            },
          ),
        );

        expect(privateResult.isError, isNot(true));
        final privateSignature =
            (privateResult.content.first as TextContent).text;
        expect(privateSignature, contains('AST Node Type:'));
        expect(privateSignature, contains('_counter'));
      });
    });
  });
}
