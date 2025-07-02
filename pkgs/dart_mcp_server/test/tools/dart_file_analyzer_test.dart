// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp_server/src/mixins/dart_file_analyzer.dart';
import 'package:dart_mcp_server/src/utils/constants.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

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
    late Tool getFileSkeletonTool;
    late Tool checkSubtypeTool;
    late Tool getTypeHierarchyTool;
    late Tool findImplementationsTool;
    late Tool convertDartUriTool;

    setUp(() async {
      final tools = (await testHarness.mcpServerConnection.listTools()).tools;
      getFileSkeletonTool = tools.singleWhere(
        (t) => t.name == DartFileAnalyzerSupport.getDartFileSkeletonTool.name,
      );
      checkSubtypeTool = tools.singleWhere(
        (t) => t.name == DartFileAnalyzerSupport.checkDartSubtypeTool.name,
      );
      getTypeHierarchyTool = tools.singleWhere(
        (t) => t.name == DartFileAnalyzerSupport.getDartTypeHierarchyTool.name,
      );
      findImplementationsTool = tools.singleWhere(
        (t) =>
            t.name == DartFileAnalyzerSupport.findDartImplementationsTool.name,
      );
      convertDartUriTool = tools.singleWhere(
        (t) => t.name == DartFileAnalyzerSupport.convertDartUriTool.name,
      );
    });

    group('get_dart_file_skeleton', () {
      test('creates skeleton for Flutter counter app', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getFileSkeletonTool.name,
            arguments: {
              'file_path': testFilePath,
              'skip_expression_bodies': false,
              'omit_skip_comments': false,
              'skip_imports': false,
            },
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final skeletonText = (result.content.first as TextContent).text;
        expect(skeletonText, contains('Dart file skeleton'));
        expect(skeletonText, contains('class MyApp extends StatelessWidget'));
        expect(
          skeletonText,
          contains('class MyHomePage extends StatefulWidget'),
        );
        expect(skeletonText, contains('// Lines'));
        expect(skeletonText, contains('skipped'));

        // Should preserve imports
        expect(
          skeletonText,
          contains("import 'package:flutter/material.dart'"),
        );

        // Should preserve method signatures but remove bodies
        expect(skeletonText, contains('Widget build(BuildContext context)'));
        expect(skeletonText, contains('void _incrementCounter()'));
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
            name: getFileSkeletonTool.name,
            arguments: {
              'file_path': testFilePath,
              'skip_expression_bodies': true,
              'omit_skip_comments': false,
              'skip_imports': false,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final skeletonText = (result.content.first as TextContent).text;
        expect(skeletonText, contains('Expression body skipped'));
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
            name: getFileSkeletonTool.name,
            arguments: {
              'file_path': testFilePath,
              'skip_expression_bodies': false,
              'omit_skip_comments': true,
              'skip_imports': false,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final skeletonText = (result.content.first as TextContent).text;
        expect(skeletonText, isNot(contains('Lines')));
        expect(skeletonText, isNot(contains('skipped')));
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
            name: getFileSkeletonTool.name,
            arguments: {
              'file_path': testFilePath,
              'skip_expression_bodies': false,
              'omit_skip_comments': false,
              'skip_imports': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final skeletonText = (result.content.first as TextContent).text;
        expect(skeletonText, isNot(contains('import')));
      });

      test('returns error for missing file', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getFileSkeletonTool.name,
            arguments: {
              'file_path': '/non/existent/file.dart',
              'skip_expression_bodies': false,
              'omit_skip_comments': false,
              'skip_imports': false,
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
            name: getFileSkeletonTool.name,
            arguments: {
              'skip_expression_bodies': false,
              'omit_skip_comments': false,
              'skip_imports': false,
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

    group('check_dart_subtype', () {
      test('correctly identifies inheritance relationship', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: checkSubtypeTool.name,
            arguments: {
              'file_path': testFilePath,
              'subtype': 'MyApp',
              'supertype': 'StatelessWidget',
            },
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final subtypeText = (result.content.first as TextContent).text;
        expect(subtypeText, contains('MyApp IS assignable to StatelessWidget'));
        expect(subtypeText, contains('Details:'));
        expect(subtypeText, contains('Subtype:'));
        expect(subtypeText, contains('Supertype:'));
        expect(subtypeText, contains('location:'));
      });

      test('correctly identifies non-inheritance relationship', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: checkSubtypeTool.name,
            arguments: {
              'file_path': testFilePath,
              'subtype': 'MyApp',
              'supertype': 'StatefulWidget',
            },
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final subtypeText = (result.content.first as TextContent).text;
        expect(
          subtypeText,
          contains('MyApp IS NOT assignable to StatefulWidget'),
        );
      });

      test('returns error for missing subtype', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: checkSubtypeTool.name,
            arguments: {
              'file_path': testFilePath,
              'subtype': 'NonExistentClass',
              'supertype': 'StatelessWidget',
            },
          ),
          expectError: true,
        );

        expect(result.isError, isTrue);
        expect(
          (result.content.first as TextContent).text,
          contains('Type "NonExistentClass" not found'),
        );
      });

      test('returns error for missing supertype', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: checkSubtypeTool.name,
            arguments: {
              'file_path': testFilePath,
              'subtype': 'MyApp',
              'supertype': 'NonExistentClass',
            },
          ),
          expectError: true,
        );

        expect(result.isError, isTrue);
        expect(
          (result.content.first as TextContent).text,
          contains('Type "NonExistentClass" not found'),
        );
      });

      test('returns error for missing arguments', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: checkSubtypeTool.name,
            arguments: {
              'file_path': '/some/file.dart',
              'subtype': 'MyClass',
              // Missing supertype
            },
          ),
          expectError: true,
        );

        expect(result.isError, isTrue);
        expect(
          (result.content.first as TextContent).text,
          contains('Missing required arguments'),
        );
      });
    });

    group('get_dart_type_hierarchy', () {
      test('shows hierarchy for StatelessWidget subclass', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getTypeHierarchyTool.name,
            arguments: {'file_path': testFilePath, 'type_name': 'MyApp'},
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final hierarchyText = (result.content.first as TextContent).text;
        expect(hierarchyText, contains('Type hierarchy for MyApp'));
        expect(hierarchyText, contains('StatelessWidget'));
        expect(
          hierarchyText,
          anyOf([
            contains('Direct superclass:'),
            contains('All superclasses:'),
          ]),
        );
      });

      test('shows hierarchy for StatefulWidget subclass', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getTypeHierarchyTool.name,
            arguments: {'file_path': testFilePath, 'type_name': 'MyHomePage'},
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final hierarchyText = (result.content.first as TextContent).text;
        expect(hierarchyText, contains('Type hierarchy for MyHomePage'));
        expect(hierarchyText, contains('StatefulWidget'));
      });

      test('returns error for missing type', () async {
        final testFilePath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
          'lib',
          'main.dart',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getTypeHierarchyTool.name,
            arguments: {
              'file_path': testFilePath,
              'type_name': 'NonExistentClass',
            },
          ),
          expectError: true,
        );

        expect(result.isError, isTrue);
        expect(
          (result.content.first as TextContent).text,
          contains('Type "NonExistentClass" not found'),
        );
      });

      test('returns error for missing arguments', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getTypeHierarchyTool.name,
            arguments: {
              'file_path': '/some/file.dart',
              // Missing type_name
            },
          ),
          expectError: true,
        );

        expect(result.isError, isTrue);
        expect(
          (result.content.first as TextContent).text,
          contains('Missing required arguments'),
        );
      });
    });

    group('find_dart_implementations', () {
      test('finds StatelessWidget implementations', () async {
        final projectPath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: findImplementationsTool.name,
            arguments: {
              'project_path': projectPath,
              'interface_name': 'StatelessWidget',
            },
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final implementationsText = (result.content.first as TextContent).text;
        expect(
          implementationsText,
          contains('Implementations of "StatelessWidget"'),
        );
        expect(implementationsText, contains('MyApp'));
        expect(implementationsText, contains('lib/main.dart'));
      });

      test('finds StatefulWidget implementations', () async {
        final projectPath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: findImplementationsTool.name,
            arguments: {
              'project_path': projectPath,
              'interface_name': 'StatefulWidget',
            },
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final implementationsText = (result.content.first as TextContent).text;
        expect(
          implementationsText,
          contains('Implementations of "StatefulWidget"'),
        );
        expect(implementationsText, contains('MyHomePage'));
      });

      test('finds State implementations', () async {
        final projectPath = p.join(
          testHarness.fileSystem.currentDirectory.path,
          'test_fixtures',
          'counter_app',
        );

        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: findImplementationsTool.name,
            arguments: {'project_path': projectPath, 'interface_name': 'State'},
          ),
        );

        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));

        final implementationsText = (result.content.first as TextContent).text;
        expect(implementationsText, contains('Implementations of "State"'));
        expect(implementationsText, contains('_MyHomePageState'));
      });

      test(
        'returns no implementations message for non-existent interface',
        () async {
          final projectPath = p.join(
            testHarness.fileSystem.currentDirectory.path,
            'test_fixtures',
            'counter_app',
          );

          final result = await testHarness.callToolWithRetry(
            CallToolRequest(
              name: findImplementationsTool.name,
              arguments: {
                'project_path': projectPath,
                'interface_name': 'NonExistentInterface',
              },
            ),
          );

          expect(result.isError, isNot(true));
          expect(result.content, hasLength(1));

          final implementationsText =
              (result.content.first as TextContent).text;
          expect(
            implementationsText,
            contains('No implementations of "NonExistentInterface" found'),
          );
        },
      );

      test('returns error for missing arguments', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: findImplementationsTool.name,
            arguments: {
              'project_path': '/some/project',
              // Missing interface_name
            },
          ),
          expectError: true,
        );

        expect(result.isError, isTrue);
        expect(
          (result.content.first as TextContent).text,
          contains('Missing required arguments'),
        );
      });

      test('returns error for non-existent project path', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: findImplementationsTool.name,
            arguments: {
              'project_path': '/non/existent/project',
              'interface_name': 'SomeInterface',
            },
          ),
          expectError: true,
        );

        expect(result.isError, isNot(false));
        expect(
          (result.content.first as TextContent).text,
          anyOf([
            contains('Could not find Dart SDK path'),
            contains('Failed to find implementations'),
            contains('No implementations'),
          ]),
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
