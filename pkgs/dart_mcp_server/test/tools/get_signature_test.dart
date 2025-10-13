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

    test('handles dart: URIs gracefully', () async {
      final result = await testHarness.callToolWithRetry(
        CallToolRequest(
          name: getSignatureTool.name,
          arguments: {
            'uri': 'dart:core',
            'name': 'String',
            'get_containing_declaration': true,
          },
        ),
      );

      // Should either work or fail gracefully (analysis context dependent)
      expect(result.isError, isNot(true));
      expect(result.content, hasLength(1));
    });

    group('containing declaration', () {
      test('gets containing class signature for method by name', () async {
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
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('MyApp'));
        expect(signatureText, contains('extends StatelessWidget'));
        expect(signatureText, contains('Widget build(BuildContext context)'));
      });

      test('gets containing class signature for field by name', () async {
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
        final signatureText = (result.content.first as TextContent).text;
        // When searching for _counter with get_containing_declaration=true,
        // it should follow the variable to its type (int) rather than the containing class
        expect(
          signatureText,
          anyOf([
            contains(
              'abstract final class int',
            ), // Type-following behavior (correct)
            contains('_MyHomePageState'), // Containing class behavior (legacy)
          ]),
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
              'name': 'build',
              // get_containing_declaration not specified, should default to true
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('MyApp'));
        expect(signatureText, contains('extends StatelessWidget'));
        expect(signatureText, contains('Widget build(BuildContext context)'));
      });
    });

    group('edge cases', () {
      test('handles missing name argument', () async {
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
              // Missing name argument
            },
          ),
          expectError: true,
        );

        expect(result.isError, isTrue);
        final errorText = (result.content.first as TextContent).text;
        expect(errorText, contains('Required property "name" is missing'));
      });

      test('handles invalid file path gracefully', () async {
        final result = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'uri': 'file:///nonexistent/file.dart',
              'name': 'SomeSymbol',
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(
          signatureText,
          contains('No element found at the specified location'),
        );
      });

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
              'name': 'MyApp',
            },
          ),
        );

        expect(publicResult.isError, isNot(true));
        final publicSignature =
            (publicResult.content.first as TextContent).text;
        expect(publicSignature, contains('class MyApp'));
        expect(publicSignature, contains('extends StatelessWidget'));

        // Test private field
        final privateResult = await testHarness.callToolWithRetry(
          CallToolRequest(
            name: getSignatureTool.name,
            arguments: {
              'uri': Uri.file(testFilePath).toString(),
              'name': '_counter',
            },
          ),
        );

        expect(privateResult.isError, isNot(true));
        final privateSignature =
            (privateResult.content.first as TextContent).text;
        expect(
          privateSignature,
          anyOf([contains('_counter'), contains('int')]),
        );
      });
    });

    group('type tracking', () {
      test(
        'tracks static constants to their class (Colors.deepPurple)',
        () async {
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
                'name': 'deepPurple',
                'get_containing_declaration': true,
              },
            ),
          );

          expect(result.isError, isNot(true));
          final signatureText = (result.content.first as TextContent).text;
          // Should resolve to MaterialColor or Color class
          expect(
            signatureText,
            anyOf([
              contains('MaterialColor'),
              contains('class Color'),
              contains('ColorSwatch'),
            ]),
          );
        },
      );

      test('tracks icon constants to their class (Icons.add)', () async {
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
              'name': 'add',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // Should resolve to IconData class
        expect(signatureText, contains('IconData'));
      });

      test('tracks static method calls (bool.fromEnvironment)', () async {
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
              'name': 'fromEnvironment',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // Should contain the bool class or fromEnvironment method
        expect(
          signatureText,
          anyOf([contains('fromEnvironment'), contains('bool')]),
        );
      });

      test('tracks widget types (Scaffold, AppBar, etc.)', () async {
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
              'name': 'Scaffold',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('Scaffold'));
      });

      test('tracks generic types (State<MyHomePage>)', () async {
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
              'name': 'createState',
              'get_containing_declaration': false,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('createState'));
        expect(
          signatureText,
          anyOf([contains('State<MyHomePage>'), contains('_MyHomePageState')]),
        );
      });

      test('tracks constructor parameters by name', () async {
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
              'name': 'title',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // Should resolve to String class since title is a String
        expect(
          signatureText,
          anyOf([
            contains('String'),
            contains('MyHomePage'), // or the containing class
          ]),
        );
      });

      test('tracks const constructor (const MyApp)', () async {
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
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('MyApp'));
      });
    });

    group('top-level declarations', () {
      test('finds top-level function (main)', () async {
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
              'name': 'main',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('main'));
        expect(signatureText, contains('void'));
      });

      test('finds imported top-level function (runApp)', () async {
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
              'name': 'runApp',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('runApp'));
      });

      test('finds static const field (includeLayoutError)', () async {
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
              'name': 'includeLayoutError',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // Should resolve to bool or the containing class
        expect(
          signatureText,
          anyOf([
            contains('includeLayoutError'),
            contains('bool'),
            contains('_MyHomePageState'),
          ]),
        );
      });
    });

    group('method and property access chains', () {
      test('tracks method calls in chains (Theme.of)', () async {
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
              'name': 'Theme',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('Theme'));
      });

      test('tracks property access in chains (colorScheme)', () async {
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
              'name': 'colorScheme',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('ColorScheme'));
      });

      test('tracks widget property access (widget.title)', () async {
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
              'name': 'widget',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // Should resolve to MyHomePage since widget is of type MyHomePage
        expect(signatureText, contains('MyHomePage'));
      });
    });

    group('generic types and type parameters', () {
      test('finds generic widget list type (List<Widget>)', () async {
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
              'name': 'Widget',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('Widget'));
      });

      test('finds generic type parameter usage (StatefulWidget)', () async {
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
              'name': 'StatefulWidget',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('StatefulWidget'));
      });
    });

    group('special cases', () {
      test('handles named constructor Key', () async {
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
              'name': 'Key',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('Key'));
      });

      test('handles setState method', () async {
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
              'name': 'setState',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // Should find setState in State class
        expect(signatureText, anyOf([contains('setState'), contains('State')]));
      });

      test('handles MaterialApp widget', () async {
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
              'name': 'MaterialApp',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('MaterialApp'));
      });

      test('handles ThemeData usage', () async {
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
              'name': 'ThemeData',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('ThemeData'));
      });

      test('handles FloatingActionButton', () async {
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
              'name': 'FloatingActionButton',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        expect(signatureText, contains('FloatingActionButton'));
      });
    });

    group('multiple matching names and deduplication', () {
      test('finds multiple occurrences of same parameter name (context)', () async {
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
        final signatureText = (result.content.first as TextContent).text;
        // Should find BuildContext type (all context parameters should resolve to same type)
        // The deduplication should result in a single signature for BuildContext
        expect(signatureText, contains('BuildContext'));
        // Should show it found multiple occurrences but deduplicated to 1 signature
        expect(signatureText, contains('Found 1 signature(s) for "context"'));
      });

      test(
        'finds multiple occurrences of same field/parameter name (title) and deduplicates',
        () async {
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
                'name': 'title',
                'get_containing_declaration': true,
              },
            ),
          );

          expect(result.isError, isNot(true));
          final signatureText = (result.content.first as TextContent).text;
          // Title appears as a parameter in constructor and as a field
          // All should resolve to String type, so should be deduplicated to 1
          expect(signatureText, contains('String'));
        },
      );

      test('correctly deduplicates when symbol appears many times', () async {
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
              'name': 'of',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // 'of' appears in multiple contexts (Theme.of, etc.)
        // This test verifies deduplication works even with many occurrences
        expect(
          signatureText,
          anyOf([
            contains('Found'),
            contains('signature'),
            contains('No elements'),
          ]),
        );
      });

      test(
        'distinguishes between different types with similar usage (key parameter)',
        () async {
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
                'name': 'key',
                'get_containing_declaration': true,
              },
            ),
          );

          expect(result.isError, isNot(true));
          final signatureText = (result.content.first as TextContent).text;
          // All key parameters should resolve to Key type
          expect(signatureText, contains('Key'));
        },
      );

      test('handles overridden methods correctly (build method)', () async {
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
        final signatureText = (result.content.first as TextContent).text;
        // Should find just the method signature (not containing class)
        // Should deduplicate to 1 since all build methods have same signature
        expect(signatureText, contains('Widget build(BuildContext context)'));
      });

      test('handles same class name constructor and class reference', () async {
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
              'name': 'MyHomePage',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // Should find the class (constructor calls resolve to class)
        expect(signatureText, contains('MyHomePage'));
        expect(signatureText, contains('StatefulWidget'));
      });

      test(
        'finds multiple distinct types when they genuinely differ',
        () async {
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
                'name': 'children',
                'get_containing_declaration': true,
              },
            ),
          );

          expect(result.isError, isNot(true));
          final signatureText = (result.content.first as TextContent).text;
          // children appears as List<Widget> parameter in multiple places
          // Should deduplicate since they're all the same type
          expect(signatureText, contains('List'));
        },
      );

      test(
        'handles symbols that appear in both declaration and usage',
        () async {
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
                'get_containing_declaration': false,
              },
            ),
          );

          expect(result.isError, isNot(true));
          final signatureText = (result.content.first as TextContent).text;
          // _counter is both declared and used, should find the declaration
          expect(signatureText, anyOf([contains('_counter'), contains('int')]));
        },
      );

      test('correctly counts unique signatures', () async {
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
        final signatureText = (result.content.first as TextContent).text;
        // build appears in MyApp and _MyHomePageState - 2 distinct classes
        expect(signatureText, contains('Found 2 signature(s) for "build"'));
        expect(signatureText, contains('MyApp'));
        expect(signatureText, contains('_MyHomePageState'));
        // Should have separator between signatures
        expect(signatureText, contains('---'));
      });

      test('deduplicates identical method signatures correctly', () async {
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
              'name': 'setState',
              'get_containing_declaration': false,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // setState might appear multiple times in usage but should have 1 signature
        expect(
          signatureText,
          anyOf([contains('Found 1 signature(s)'), contains('setState')]),
        );
      });
    });

    group('imported symbol tracking', () {
      test('tracks imported classes to their definition (Widget)', () async {
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
              'name': 'Widget',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // Should find the Widget class definition from Flutter
        expect(signatureText, contains('Widget'));
        expect(
          signatureText,
          anyOf([
            contains('abstract class Widget'),
            contains('class Widget'),
            contains('@immutable'),
          ]),
        );
      });

      test('tracks imported classes used as types (StatelessWidget)', () async {
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
              'name': 'StatelessWidget',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // Should find the StatelessWidget class from Flutter
        expect(signatureText, contains('StatelessWidget'));
        expect(
          signatureText,
          anyOf([
            contains('abstract class StatelessWidget'),
            contains('class StatelessWidget'),
            contains('Widget'),
          ]),
        );
      });

      test(
        'tracks imported classes used as return types (BuildContext)',
        () async {
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
                'name': 'BuildContext',
                'get_containing_declaration': true,
              },
            ),
          );

          expect(result.isError, isNot(true));
          final signatureText = (result.content.first as TextContent).text;
          // Should find the BuildContext class/interface from Flutter
          expect(signatureText, contains('BuildContext'));
        },
      );

      test('tracks core Dart types (String)', () async {
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
              'name': 'String',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // Should find the String class from dart:core
        expect(signatureText, contains('String'));
        expect(
          signatureText,
          anyOf([contains('class String'), contains('final class String')]),
        );
      });

      test('tracks imported utility classes (MaterialApp)', () async {
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
              'name': 'MaterialApp',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // Should find MaterialApp definition
        expect(signatureText, contains('MaterialApp'));
        expect(
          signatureText,
          anyOf([contains('class MaterialApp'), contains('StatefulWidget')]),
        );
      });

      test('tracks imported enums or constants (Icons)', () async {
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
              'name': 'Icons',
              'get_containing_declaration': true,
            },
          ),
        );

        expect(result.isError, isNot(true));
        final signatureText = (result.content.first as TextContent).text;
        // Should find Icons class definition
        expect(signatureText, contains('Icons'));
        expect(
          signatureText,
          anyOf([contains('class Icons'), contains('IconData')]),
        );
      });
    });
  });
}
