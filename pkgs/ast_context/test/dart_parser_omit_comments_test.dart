import 'package:flutter_test/flutter_test.dart';
import 'package:ast_context/dart_parser.dart';

void main() {
  group('parseDartFileSkipMethods - omitSkipComments = true', () {
    test('should omit skip comments for block bodies', () {
      final input = '''
class Test {
  void method1() {
    print('This should be removed');
  }
}
void func1() {
  int x = 1;
}
''';
      final expected = '''
class Test {
  void method1() {}
}
void func1() {}
''';
      final result = parseDartFileSkipMethods(input, omitSkipComments: true);
      // Normalize whitespace for comparison
      expect(result.replaceAll(RegExp(r'\\s+'), ''),
          expected.replaceAll(RegExp(r'\\s+'), ''));
      expect(result.contains('// Lines'), isFalse);
    });

    test(
        'should keep expression bodies when omitSkipComments is true (default skipExpressionBodies is false)',
        () {
      final input = '''
class ArrowTest {
  int double(int x) => x * 2;
}
String getName() => "Test Name";
''';
      final result = parseDartFileSkipMethods(input, omitSkipComments: true);
      expect(result.contains('int double(int x) => x * 2;'), isTrue);
      expect(result.contains('String getName() => "Test Name";'), isTrue);
      expect(result.contains('// Lines'),
          isFalse); // No block bodies to add comments to
    });
  });
}
