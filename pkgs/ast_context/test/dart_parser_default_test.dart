import 'package:flutter_test/flutter_test.dart';
import 'package:ast_context/dart_parser.dart';

void main() {
  group('parseDartFileSkipMethods - Default Behavior', () {
    test('should add line skipped comments to method bodies', () {
      final input = '''
class Test {
  void method1() {
    print('This should be removed');
    doSomething();
  }
  
  int calculate(int x) {
    int result = x * 2;
    return result;
  }
}
''';

      final result = parseDartFileSkipMethods(input);

      // Check that we're replacing method bodies with comments about skipped lines
      expect(result.contains('void method1()'), isTrue);
      expect(result.contains('int calculate(int x)'), isTrue);
      // Corrected line numbers based on previous run's actual output
      expect(result, contains('{\n  // Lines 2-5 skipped.\n}'));
      expect(result, contains('{\n  // Lines 7-10 skipped.\n}'));
    });

    test('should keep expression bodies unchanged by default', () {
      final input = '''
class ArrowTest {
  int double(int x) => x * 2;
  String getName() => "Test Name";
}
''';

      final result = parseDartFileSkipMethods(input);
      expect(result.contains('int double(int x) => x * 2;'), isTrue);
      expect(result.contains('String getName() => "Test Name";'), isTrue);
    });

    test('should handle function declarations correctly (default)', () {
      final input = '''
void topLevelFunction() { // Line 1
  print('This is a top level function'); // Line 2
  doSomething(); // Line 3
} // Line 4

int calculateSum(List<int> numbers) { // Line 6
  int sum = 0; // Line 7
  for (var num in numbers) { // Line 8
    sum += num; // Line 9
  } // Line 10
  return sum; // Line 11
} // Line 12

String getGreeting() => 'Hello, world!'; // Line 14
''';

      final result = parseDartFileSkipMethods(input);
      expect(result.contains('void topLevelFunction()'), isTrue);
      // Corrected line numbers and exact string match
      expect(result, contains('{\n  // Lines 1-4 skipped.\n}'));
      expect(result.contains('int calculateSum(List<int> numbers)'), isTrue);
      // Corrected line numbers and exact string match
      expect(result, contains('{\n  // Lines 6-12 skipped.\n}'));
      expect(
          result.contains("String getGreeting() => 'Hello, world!';"), isTrue);
    });

    test('should preserve comments and structure (default)', () {
      final input = '''
/// This is a class documentation // Line 1
class DocumentedClass { // Line 2
  // Field declaration // Line 3
  final int id; // Line 4
   // Line 5
  DocumentedClass(this.id); // Line 6
   // Line 7
  /// Method documentation // Line 8
  /// Multiple lines // Line 9
  void documentedMethod() { // Line 10
    // This comment should be removed // Line 11
    print('This content should be removed'); // Line 12
  } // Line 13
} // Line 14
''';

      final result = parseDartFileSkipMethods(input);
      expect(result.contains('/// This is a class documentation'), isTrue);
      expect(result.contains('// Field declaration'), isTrue);
      expect(result.contains('/// Method documentation'), isTrue);
      expect(result.contains('/// Multiple lines'), isTrue);
      expect(result.contains('void documentedMethod()'), isTrue);
      // Corrected line numbers and exact string match
      expect(result, contains('{\n  // Lines 10-13 skipped.\n}'));
      expect(result.contains('// This comment should be removed'), isFalse);
    });

    test('should handle async block functions correctly (default)', () {
      final input = '''
Future<void> fetchData() async { // Line 1
  await Future.delayed(Duration(seconds: 1)); // Line 2
  print("Data fetched"); // Line 3
} // Line 4
''';
      final result = parseDartFileSkipMethods(input);
      expect(result.contains('Future<void> fetchData() async'), isTrue);
      // Corrected line numbers and exact string match
      expect(result, contains('{\n  // Lines 1-4 skipped.\n}'));
    });
  });
}
