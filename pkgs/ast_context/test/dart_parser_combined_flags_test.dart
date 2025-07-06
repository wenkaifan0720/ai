import 'package:flutter_test/flutter_test.dart';
import 'package:ast_context/dart_parser.dart';

void main() {
  group('parseDartFileSkipMethods - Combined Flags', () {
    test(
        'should omit skip comments for expression bodies when both flags are true',
        () {
      final input = '''
class ArrowTest {
  int double(int x) => x * 2; // Method
}
String getName() => "Test Name"; // Function
''';
      final expected = '''
class ArrowTest {
  int double(int x) => ;
}
String getName() => ;
''';
      final result = parseDartFileSkipMethods(input,
          skipExpressionBodies: true, omitSkipComments: true);
      // Normalize whitespace for comparison
      expect(result.replaceAll(RegExp(r'\\s+'), ''),
          expected.replaceAll(RegExp(r'\\s+'), ''));
      expect(result.contains('// Expression body skipped'), isFalse);
      expect(result.contains('x * 2'), isFalse);
      expect(result.contains('"Test Name"'), isFalse);
    });

    test('should omit skip comments for block bodies when both flags are true',
        () {
      final input = '''
class Mixed {
  void blockMethod() {
    print("block");
  }
  int exprMethod() => 10;
}
''';
      final expected = '''
class Mixed {
  void blockMethod() {}
  int exprMethod() => ;
}
''';
      final result = parseDartFileSkipMethods(input,
          skipExpressionBodies: true, omitSkipComments: true);
      // Normalize whitespace for comparison
      expect(result.replaceAll(RegExp(r'\\s+'), ''),
          expected.replaceAll(RegExp(r'\\s+'), ''));
      expect(result.contains('// Lines'), isFalse);
      expect(result.contains('// Expression body skipped'), isFalse);
    });
  });
}
