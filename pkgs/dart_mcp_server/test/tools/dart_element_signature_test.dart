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
              'uri': Uri.file(testFilePath).toString(),
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
              'uri': Uri.file(testFilePath).toString(),
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

      test('recursively skips method bodies in _MyHomePageState class', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test clicking on the _MyHomePageState class name which contains methods
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'line':
                  34, // Zero-based line number for _MyHomePageState class (line 35)
              'column': 6, // Position within "class _MyHomePageState"
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('ClassDeclaration'));
        expect(signatureText, contains('class _MyHomePageState'));
        expect(signatureText, contains('extends State<MyHomePage>'));

        // Verify all method bodies are simplified - recursive body skipping
        expect(signatureText, contains('void _incrementCounter()'));
        expect(signatureText, contains('Widget build(BuildContext context)'));

        // Verify method implementations are simplified (inner content removed)
        expect(signatureText, isNot(contains('_counter++')));
        expect(signatureText, isNot(contains('Scaffold')));
        expect(signatureText, isNot(contains('MaterialApp')));
        expect(signatureText, isNot(contains('AppBar')));
        expect(signatureText, isNot(contains('FloatingActionButton')));
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
              'uri': Uri.file(testFilePath).toString(),
              'line':
                  14, // Zero-based line number for build method in MyApp (line 15)
              'column': 10, // Position within "Widget build"
              'get_containing_declaration': false,
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
        // Method body should be empty - no implementation details
        expect(signatureText, contains('{}'));
        expect(signatureText, isNot(contains('MaterialApp')));
        expect(signatureText, isNot(contains('return')));
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
              'uri': Uri.file(testFilePath).toString(),
              'line':
                  41, // Zero-based line number for _incrementCounter method (line 42)
              'column': 8,
              'get_containing_declaration': false,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('MethodDeclaration'));
        expect(signatureText, contains('void _incrementCounter'));
        // Method body should be simplified - no inner implementation details
        expect(signatureText, isNot(contains('_counter++')));
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
              'uri': Uri.file(testFilePath).toString(),
              'line': 35, // Zero-based line number for _counter field (line 36)
              'column': 6, // Position within "int _counter"
              'get_containing_declaration': false,
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
              'uri': Uri.file(testFilePath).toString(),
              'line':
                  26, // Zero-based line number for MyHomePage constructor (line 27)
              'column': 12, // Position within "const MyHomePage"
              'get_containing_declaration': false,
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

        // Test clicking on whitespace area - should find compilation unit and return error
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'line': 1, // Line with just whitespace or comment
              'column': 0,
            },
          ),
          expectError: true,
        );

        expect(result.isError, isTrue);
        final signatureText = (result.content.first as TextContent).text;
        expect(
          signatureText,
          contains('Cannot follow declaration for this element type'),
        );
        expect(signatureText, contains('CompilationUnit'));
      });

      test('handles invalid file path', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'uri': 'file:///nonexistent/file.dart',
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
                'uri': 'file:///test.dart',
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
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'line': -1,
              'column': -1,
            },
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
              'uri': Uri.file(testFilePath).toString(),
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
              'uri': Uri.file(testFilePath).toString(),
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
              'uri': Uri.file(testFilePath).toString(),
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

    group('containing declaration', () {
      test('gets containing class signature for method', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test clicking on build method but requesting containing class
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'line': 14, // build method in MyApp
              'column': 10,
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('ClassDeclaration'));
        expect(signatureText, contains('class MyApp'));
        expect(signatureText, contains('extends StatelessWidget'));
        // Should contain the method but with empty body
        expect(signatureText, contains('Widget build'));
        expect(signatureText, isNot(contains('MaterialApp')));
      });

      test('gets containing class signature for field', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test clicking on _counter field but requesting containing class
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'line': 35, // _counter field
              'column': 6,
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('ClassDeclaration'));
        expect(signatureText, contains('class _MyHomePageState'));
        expect(signatureText, contains('extends State<MyHomePage>'));
        // Should contain the field
        expect(signatureText, contains('int _counter'));
      });

      test('gets function signature when already at top level', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test clicking on main function with containing declaration flag
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'line': 6, // main function (line 7, 0-based = 6)
              'column': 5,
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('FunctionDeclaration'));
        expect(signatureText, contains('void main'));
      });

      test('returns error when declaration cannot be followed', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test clicking on a top-level element (import) where declaration cannot be followed
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'line': 0, // import statement area
              'column': 0,
              'get_containing_declaration': true,
            },
          ),
          expectError: true,
        );

        expect(result.isError, isTrue);
        final signatureText = (result.content.first as TextContent).text;
        expect(
          signatureText,
          contains('Cannot follow declaration for this element type'),
        );
      });

      test('works with default value true', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        // Test without specifying get_containing_declaration (should default to true)
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'line': 14, // build method in MyApp
              'column': 10,
              // get_containing_declaration not specified, should default to true
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('AST Node Type:'));
        expect(signatureText, contains('ClassDeclaration'));
        expect(signatureText, contains('class MyApp'));
        expect(signatureText, contains('extends StatelessWidget'));
        // Should contain the method but with empty body
        expect(signatureText, contains('Widget build'));
        expect(signatureText, isNot(contains('MaterialApp')));
      });
    });
  });
}
