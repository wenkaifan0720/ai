import 'package:flutter_test/flutter_test.dart';
import 'package:ast_context/dart_parser.dart';

void main() {
  group('parseDartFileSkipMethods - skipPrivate = true', () {
    test('should skip private methods', () {
      final input = '''
class Test {
  void publicMethod() {
    print('public');
  }

  void _privateMethod() {
    print('private');
  }

  int _privateFunction() => 42;
}
''';
      final expectedWithComment = '''
class Test {
  void publicMethod() {
  // Lines 2-4 skipped.
}

}
''';
      final expectedOmitComment = '''
class Test {
  void publicMethod() {}

}
''';

      final resultWithComment =
          parseDartFileSkipMethods(input, skipPrivate: true);
      final resultOmitComment = parseDartFileSkipMethods(input,
          skipPrivate: true, omitSkipComments: true);

      expect(resultWithComment.contains('_privateMethod'), isFalse);
      expect(resultWithComment.contains('_privateFunction'), isFalse);
      expect(resultWithComment.contains('publicMethod'), isTrue);
      expect(resultOmitComment.contains('_privateMethod'), isFalse);
      expect(resultOmitComment.contains('_privateFunction'), isFalse);
      expect(resultOmitComment.contains('publicMethod'), isTrue);
    });

    test('should skip private fields', () {
      final input = '''
class Test {
  String publicField = 'public';
  String _privateField = 'private';
  int _privateNumber = 42;
  bool publicBool = true;
}
''';
      final result = parseDartFileSkipMethods(input, skipPrivate: true);

      expect(result.contains('publicField'), isTrue);
      expect(result.contains('publicBool'), isTrue);
      expect(result.contains('_privateField'), isFalse);
      expect(result.contains('_privateNumber'), isFalse);
    });

    test('should skip private classes', () {
      final input = '''
class PublicClass {
  void method() {}
}

class _PrivateClass {
  void method() {}
}

class AnotherPublicClass {
  void method() {}
}
''';
      final result = parseDartFileSkipMethods(input, skipPrivate: true);

      expect(result.contains('PublicClass'), isTrue);
      expect(result.contains('AnotherPublicClass'), isTrue);
      expect(result.contains('_PrivateClass'), isFalse);
    });

    test('should skip private functions', () {
      final input = '''
void publicFunction() {
  print('public');
}

void _privateFunction() {
  print('private');
}

int _privateHelper() => 42;
''';
      final result = parseDartFileSkipMethods(input, skipPrivate: true);

      expect(result.contains('publicFunction'), isTrue);
      expect(result.contains('_privateFunction'), isFalse);
      expect(result.contains('_privateHelper'), isFalse);
    });

    test('should handle mixed field declarations', () {
      final input = '''
class Test {
  String publicField = 'public';
  String _privateField = 'private', anotherPublic = 'public';
  int _privateNumber = 42;
}
''';
      final result = parseDartFileSkipMethods(input, skipPrivate: true);

      expect(result.contains('publicField'), isTrue);
      expect(result.contains('_privateField'), isFalse);
      expect(result.contains('anotherPublic'),
          isFalse); // Removed because it's on the same line as a private field
      expect(result.contains('_privateNumber'), isFalse);
    });

    test('should not skip private members when skipPrivate is false (default)',
        () {
      final input = '''
class Test {
  String _privateField = 'private';
  
  void _privateMethod() {
    print('private');
  }
}
''';
      final result =
          parseDartFileSkipMethods(input); // skipPrivate defaults to false

      expect(result.contains('_privateField'), isTrue);
      expect(result.contains('_privateMethod'), isTrue);
    });

    test('should work with combination of flags', () {
      final input = '''
import 'dart:math';

class Test {
  String _privateField = 'private';
  
  void publicMethod() {
    print('public');
  }
  
  void _privateMethod() => print('private');
}
''';
      final result = parseDartFileSkipMethods(input,
          skipPrivate: true, skipImports: true, skipExpressionBodies: true);

      expect(result.contains('dart:math'), isFalse);
      expect(result.contains('_privateField'), isFalse);
      expect(result.contains('_privateMethod'), isFalse);
      expect(result.contains('publicMethod'), isTrue);
    });
  });
}
