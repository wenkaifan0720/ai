import 'package:flutter_test/flutter_test.dart';
import 'package:ast_context/dart_parser.dart';

void main() {
  group('parseDartFileSkipMethods with skipComments', () {
    test('should remove single-line comments', () {
      const input = '''
// This is a class comment
class MyClass {
  // This is a field comment
  String name = 'test';
  
  // This is a method comment
  void myMethod() {
    // This is an inline comment
    print('Hello');
  }
}
''';

      final result = parseDartFileSkipMethods(input, skipComments: true);

      // Should not contain any single-line comments
      expect(result, isNot(contains('// This is a class comment')));
      expect(result, isNot(contains('// This is a field comment')));
      expect(result, isNot(contains('// This is a method comment')));
      expect(result, isNot(contains('// This is an inline comment')));

      // Should still contain the class and method structure
      expect(result, contains('class MyClass'));
      expect(result, contains('String name = \'test\''));
      expect(result, contains('void myMethod()'));
    });

    test('should remove multi-line comments', () {
      const input = '''
/*
 * This is a multi-line comment
 * describing the class
 */
class MyClass {
  /* Field comment */
  String name = 'test';
  
  /*
   * Method comment
   */
  void myMethod() {
    /* Inline comment */ print('Hello');
  }
}
''';

      final result = parseDartFileSkipMethods(input, skipComments: true);

      // Should not contain any multi-line comments
      expect(result, isNot(contains('/*')));
      expect(result, isNot(contains('*/')));
      expect(result, isNot(contains('* This is a multi-line comment')));

      // Should still contain the class and method structure
      expect(result, contains('class MyClass'));
      expect(result, contains('String name = \'test\''));
      expect(result, contains('void myMethod()'));
    });

    test('should preserve comments when skipComments is false', () {
      const input = '''
// This is a class comment
class MyClass {
  // This is a field comment
  String name = 'test';
  
  // This is a method comment
  void myMethod() {
    // This is an inline comment
    print('Hello');
  }
}
''';

      final result = parseDartFileSkipMethods(input, skipComments: false);

      // Should contain all comments
      expect(result, contains('// This is a class comment'));
      expect(result, contains('// This is a field comment'));
      expect(result, contains('// This is a method comment'));
    });

        test('should work with both skipComments and method body removal', () {
      const input = '''
// This is a class comment
class MyClass {
  // This is a field comment
  String name = 'test';
  
  // This is a method comment
  void myMethod() {
    // This is an inline comment
    print('Hello');
  }
}
''';

      final result = parseDartFileSkipMethods(
        input,
        skipComments: true,
        omitSkipComments: true, // Don't add "Lines X-Y skipped" comments since we're removing all comments
      );
      
      // Should not contain any comments at all
      expect(result, isNot(contains('// This is a class comment')));
      expect(result, isNot(contains('// This is a field comment')));
      expect(result, isNot(contains('// This is a method comment')));
      expect(result, isNot(contains('// This is an inline comment')));
      expect(result, isNot(contains('// Lines')));
      expect(result, isNot(contains('//')));
      
      // Should contain the class and method structure
      expect(result, contains('class MyClass'));
      expect(result, contains('String name = \'test\''));
      expect(result, contains('void myMethod()'));
      expect(result, contains('{}'));
    });
  });
}
