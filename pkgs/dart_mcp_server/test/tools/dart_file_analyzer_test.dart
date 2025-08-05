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

  // TODO: Use setUpAll, currently this fails due to an apparent TestProcess
  // issue.
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

  group('dart file analyzer tools', () {
    late Tool getFileOutlineTool;
    late Tool convertDartUriTool;

    setUp(() async {
      final tools = (await testHarness.mcpServerConnection.listTools()).tools;
      getFileOutlineTool = tools.singleWhere(
        (t) => t.name == DartFileAnalyzerSupport.getDartFileOutlineTool.name,
      );
      convertDartUriTool = tools.singleWhere(
        (t) => t.name == DartFileAnalyzerSupport.convertDartUriTool.name,
      );
    });

    group('get_dart_file_outline', () {
      test('creates outline for Flutter counter app', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getFileOutlineTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'skip_expression_bodies': false,
              'omit_skip_comments': false,
              'skip_imports': false,
              'skip_comments': false,
            },
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final outlineText = (result.content.first as TextContent).text;
        expect(outlineText, contains('Dart file outline'));
        expect(outlineText, contains('class MyApp extends StatelessWidget'));
        expect(
          outlineText,
          contains('class MyHomePage extends StatefulWidget'),
        );
        expect(outlineText, contains('// Lines'));
        expect(outlineText, contains('skipped'));

        // Should preserve imports
        expect(outlineText, contains("import 'package:flutter/material.dart'"));

        // Should preserve method signatures but remove bodies
        expect(outlineText, contains('Widget build(BuildContext context)'));
        expect(
          outlineText,
          contains('class _MyHomePageState extends State<MyHomePage>'),
        );
      });

      test('works with skip_expression_bodies option', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getFileOutlineTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'skip_expression_bodies': false,
              'omit_skip_comments': false,
              'skip_imports': false,
              'skip_comments': false,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final outlineText = (result.content.first as TextContent).text;
        expect(outlineText, contains('State<MyHomePage> createState() =>'));
      });

      test('works with omit_skip_comments option', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getFileOutlineTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'skip_expression_bodies': false,
              'omit_skip_comments': true,
              'skip_imports': false,
              'skip_comments': false,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final outlineText = (result.content.first as TextContent).text;
        expect(outlineText, isNot(contains('Lines')));
        expect(outlineText, isNot(contains('skipped')));
      });

      test('works with skip_imports option', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getFileOutlineTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'skip_expression_bodies': false,
              'omit_skip_comments': false,
              'skip_imports': true,
              'skip_comments': false,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final outlineText = (result.content.first as TextContent).text;
        expect(outlineText, isNot(contains('import')));
      });

      test('works with skip_comments option', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getFileOutlineTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'skip_expression_bodies': false,
              'omit_skip_comments': true,
              'skip_imports': false,
              'skip_comments': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final outlineText = (result.content.first as TextContent).text;

        // Should not contain any comment syntax
        expect(outlineText, isNot(contains('//')));
        expect(outlineText, isNot(contains('/*')));
        expect(outlineText, isNot(contains('*/')));

        // Should still contain class and method structure
        expect(outlineText, contains('class MyApp extends StatelessWidget'));
        expect(outlineText, contains('Widget build(BuildContext context)'));
        expect(
          outlineText,
          contains('class _MyHomePageState extends State<MyHomePage>'),
        );
      });

      test('returns error for missing file', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getFileOutlineTool.name,
            arguments: {
              'uri': 'file:///non/existent/file.dart',
              'skip_expression_bodies': false,
              'omit_skip_comments': false,
              'skip_imports': false,
              'skip_comments': false,
            },
          ),
          expectError: true,
        );

        expect(result.isError, isTrue);
        expect(
          (result.content.first as TextContent).text,
          contains('File not found'),
        );
      });

      test('returns error for missing file_path argument', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getFileOutlineTool.name,
            arguments: {
              'skip_expression_bodies': false,
              'omit_skip_comments': false,
              'skip_imports': false,
              'skip_comments': false,
            },
          ),
          expectError: true,
        );

        expect(result.isError, isTrue);
        expect(
          (result.content.first as TextContent).text,
          contains('Missing required argument'),
        );
      });
    });

    group('convert_dart_uri', () {
      test('converts dart: URI to file path', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: convertDartUriTool.name,
            arguments: {'uri': 'dart:core'},
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final resultText = (result.content.first as TextContent).text;
        expect(resultText, contains('URI "dart:core" resolved to file path:'));
        expect(resultText, contains('core'));
        expect(resultText, contains('.dart'));
      });

      test('converts dart:ui URI to file path', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: convertDartUriTool.name,
            arguments: {'uri': 'dart:ui'},
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final resultText = (result.content.first as TextContent).text;
        expect(resultText, contains('URI "dart:ui" resolved to file path:'));
        expect(resultText, contains('ui'));
        expect(resultText, contains('.dart'));
      });

      test('converts package: URI with context', () async {
        final contextPath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: convertDartUriTool.name,
            arguments: {
              'uri': 'package:flutter/material.dart',
              'context_path': contextPath,
            },
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final resultText = (result.content.first as TextContent).text;
        expect(
          resultText,
          contains(
            'URI "package:flutter/material.dart" resolved to file path:',
          ),
        );
        expect(resultText, contains('material.dart'));
      });

      test('returns error for package: URI without context', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: convertDartUriTool.name,
            arguments: {'uri': 'package:flutter/material.dart'},
          ),
          expectError: true,
        );

        expect(result.isError, isTrue);
        expect(
          (result.content.first as TextContent).text,
          contains('For package: URIs, a context_path is required'),
        );
      });

      test('returns error for missing uri argument', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(name: convertDartUriTool.name, arguments: {}),
          expectError: true,
        );

        expect(result.isError, isTrue);
        expect(
          (result.content.first as TextContent).text,
          contains('Missing required argument `uri`'),
        );
      });

      test('handles file: URI', () async {
        final contextPath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final fileUri = 'file://$contextPath';

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: convertDartUriTool.name,
            arguments: {'uri': fileUri},
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final resultText = (result.content.first as TextContent).text;
        expect(resultText, contains('resolved to file path:'));
        expect(resultText, contains('main.dart'));
      });

      test('reports when URI cannot be resolved', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: convertDartUriTool.name,
            arguments: {'uri': 'dart:nonexistent'},
          ),
          expectError: true,
        );

        // Should fail to resolve non-existent dart: URI
        expect(result.isError, isTrue);
        expect(result.content, hasLength(1));
        final resultText = (result.content.first as TextContent).text;
        expect(resultText, contains('Could not resolve URI'));
      });
    });
  });
}
