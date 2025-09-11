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

    test('resolves class signature by name', () async {
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
            'name': 'MyApp',
            'get_containing_declaration': true,
          },
        ),
      );

      expect(result.isError, isNot(true));
      expect(result.content, hasLength(1));

      final signatureText = (result.content.first as TextContent).text;
      expect(signatureText, contains('class MyApp extends StatelessWidget'));
      expect(signatureText, contains('Widget build(BuildContext context)'));
    });

    test('resolves method signature by name', () async {
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
            'name': 'build',
            'get_containing_declaration': false,
          },
        ),
      );

      expect(result.isError, isNot(true));
      expect(result.content, hasLength(1));

      final signatureText = (result.content.first as TextContent).text;
      expect(signatureText, contains('Widget build(BuildContext context)'));
    });

    test('finds multiple signatures for same method name', () async {
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
            'name': 'build',
            'get_containing_declaration': true,
          },
        ),
      );

      expect(result.isError, isNot(true));
      expect(result.content, hasLength(1));

      final signatureText = (result.content.first as TextContent).text;
      // Should find multiple build methods in different classes
      expect(signatureText, contains('Found 2 signature(s) for "build"'));
      expect(signatureText, contains('MyApp'));
      expect(signatureText, contains('_MyHomePageState'));
    });

    test('resolves variable to its type signature', () async {
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
            'name': '_counter',
            'get_containing_declaration': true,
          },
        ),
      );

      expect(result.isError, isNot(true));
      expect(result.content, hasLength(1));

      final signatureText = (result.content.first as TextContent).text;
      // Should resolve to int type or contain int-related signature
      expect(
        signatureText,
        anyOf([
          contains('abstract final class int'),
          contains('class int'),
          contains('int'),
        ]),
      );
    });

    test('resolves widget parameter types', () async {
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
            'name': 'context',
            'get_containing_declaration': true,
          },
        ),
      );

      expect(result.isError, isNot(true));
      expect(result.content, hasLength(1));

      final signatureText = (result.content.first as TextContent).text;
      expect(signatureText, contains('BuildContext'));
    });

    test('handles private identifiers', () async {
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
            'name': '_MyHomePageState',
            'get_containing_declaration': true,
          },
        ),
      );

      expect(result.isError, isNot(true));
      expect(result.content, hasLength(1));

      final signatureText = (result.content.first as TextContent).text;
      expect(signatureText, contains('_MyHomePageState'));
      expect(signatureText, contains('State<MyHomePage>'));
    });

    test('resolves method parameters and return types', () async {
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
            'name': '_incrementCounter',
            'get_containing_declaration': false,
          },
        ),
      );

      expect(result.isError, isNot(true));
      expect(result.content, hasLength(1));

      final signatureText = (result.content.first as TextContent).text;
      expect(signatureText, contains('_incrementCounter'));
      expect(signatureText, contains('void'));
    });

    test('returns no results for non-existent symbol', () async {
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
            'name': 'NonExistentSymbol',
            'get_containing_declaration': true,
          },
        ),
      );

      expect(result.isError, isNot(true));
      expect(result.content, hasLength(1));

      final signatureText = (result.content.first as TextContent).text;
      expect(
        signatureText,
        contains('No elements found with name "NonExistentSymbol"'),
      );
    });

    test('returns error for missing name argument', () async {
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
            'get_containing_declaration': true,
          },
        ),
        expectError: true,
      );

      expect(result.isError, isTrue);
      expect(
        (result.content.first as TextContent).text,
        contains('Required property "name" is missing'),
      );
    });

    test('handles missing file gracefully', () async {
      final result = await testHarness.callToolWithRetry(
        CallToolRequest(
          name: getSignatureTool.name,
          arguments: {
            'uri': 'file:///non/existent/file.dart',
            'name': 'SomeSymbol',
            'get_containing_declaration': true,
          },
        ),
      );

      expect(result.isError, isNot(true));
      expect(result.content, hasLength(1));

      final signatureText = (result.content.first as TextContent).text;
      expect(
        signatureText,
        contains('No element found at the specified location'),
      );
    });
  });
}
