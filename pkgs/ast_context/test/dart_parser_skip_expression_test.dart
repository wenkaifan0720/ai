import 'package:flutter_test/flutter_test.dart';
import 'package:ast_context/dart_parser.dart';

void main() {
  group('parseDartFileSkipMethods - skipExpressionBodies = true', () {
    test('should skip method expression bodies', () {
      final input = '''
class ArrowTest {
  int double(int x) => x * 2;
  String getName() => "Test Name";
}
''';

      final result =
          parseDartFileSkipMethods(input, skipExpressionBodies: true);
      expect(result, contains(' => // Expression body skipped (Lines 2-2);'));
      expect(result, contains(' => // Expression body skipped (Lines 3-3);'));
      expect(result.contains('x * 2'), isFalse); // Original body removed
      expect(result.contains('"Test Name"'), isFalse); // Original body removed
    });

    test('should skip function expression bodies', () {
      final input = '''
int timesTwo(int x) => x * 2;
String greeting() => "Hello";
''';
      final result =
          parseDartFileSkipMethods(input, skipExpressionBodies: true);
      expect(result, contains(' => // Expression body skipped (Lines 1-1);'));
      expect(result, contains(' => // Expression body skipped (Lines 2-2);'));
      expect(result.contains('x * 2'), isFalse);
      expect(result.contains('"Hello"'), isFalse);
    });

    test('should skip async expression bodies', () {
      final input = '''
Future<int> calculateAsync() async => 5;
''';
      final result =
          parseDartFileSkipMethods(input, skipExpressionBodies: true);
      expect(
          result, contains('async => // Expression body skipped (Lines 1-1);'));
      expect(result.contains(' 5'), isFalse);
    });

    test('should still skip block bodies when skipExpressionBodies is true',
        () {
      final input = '''
class Mixed {
  void blockMethod() {
    print("block");
  }
  int exprMethod() => 10;
}
''';
      final result =
          parseDartFileSkipMethods(input, skipExpressionBodies: true);
      expect(result, contains('{\n  // Lines 2-4 skipped.\n}'));
      expect(result, contains(' => // Expression body skipped (Lines 5-5);'));
    });
  });
}
