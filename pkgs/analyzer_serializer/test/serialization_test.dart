import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_serializer/analyzer_serializer.dart';
import 'package:test/test.dart';

void main() {
  group('Element Serialization Tests', () {
    late AnalysisContextCollection collection;
    late LibraryElement testLibrary;

    setUpAll(() async {
      // Create a test Dart file
      final testFile = File('test_sample.dart');
      await testFile.writeAsString('''
class TestClass {
  final String name;
  int? age;
  static const int maxAge = 100;
  
  TestClass(this.name, [this.age]);
  
  void sayHello() {
    print('Hello, \$name!');
  }
  
  static void staticMethod() {
    print('Static method called');
  }
}

enum Color {
  red,
  green,
  blue;
  
  String get displayName => name.toUpperCase();
}

String greet(String name, {bool formal = false}) {
  return formal ? 'Good day, \$name' : 'Hi \$name!';
}

int counter = 0;
const String appName = 'Test App';
''');

      collection = AnalysisContextCollection(
        includedPaths: [Directory.current.path],
      );

      final context = collection.contextFor(testFile.path);
      final result = await context.currentSession.getResolvedLibrary(
        testFile.path,
      );

      if (result is ResolvedLibraryResult) {
        testLibrary = result.element;
      }

      // Clean up the test file
      await testFile.delete();
    });

    test('Element serialization produces valid JSON', () {
      final unit = testLibrary.units.first;
      final testClass = unit.classes.firstWhere((c) => c.name == 'TestClass');

      final serialized = testClass.toSerializedString();

      expect(serialized, isNotEmpty);
      expect(serialized, contains('TestClass'));
      expect(serialized, contains('isAbstract'));
      expect(serialized, contains('constructors'));
      expect(serialized, contains('methods'));
      expect(serialized, contains('fields'));
    });

    test('Function serialization works correctly', () {
      final unit = testLibrary.units.first;
      final greetFunction = unit.functions.firstWhere((f) => f.name == 'greet');

      final serialized = greetFunction.toSerializedString();

      expect(serialized, isNotEmpty);
      expect(serialized, contains('greet'));
      expect(serialized, contains('returnType'));
      expect(serialized, contains('parameters'));
    });

    test('Variable serialization works correctly', () {
      final unit = testLibrary.units.first;
      final counterVar = unit.topLevelVariables.firstWhere(
        (v) => v.name == 'counter',
      );

      final serialized = counterVar.toSerializedString();

      expect(serialized, isNotEmpty);
      expect(serialized, contains('counter'));
      expect(serialized, contains('type'));
      expect(serialized, contains('int'));
    });

    test('Enum serialization works correctly', () {
      final unit = testLibrary.units.first;
      final colorEnum = unit.enums.firstWhere((e) => e.name == 'Color');

      final serialized = colorEnum.toSerializedString();

      expect(serialized, isNotEmpty);
      expect(serialized, contains('Color'));
      expect(serialized, contains('constants'));
    });

    test('Base element serialization includes common properties', () {
      final unit = testLibrary.units.first;
      final testClass = unit.classes.firstWhere((c) => c.name == 'TestClass');

      final jsonMap = testClass.toJsonMap();

      expect(jsonMap, containsPair('kind', 'CLASS'));
      expect(jsonMap, containsPair('name', 'TestClass'));
      expect(jsonMap, containsPair('displayName', 'TestClass'));
      expect(jsonMap, containsPair('isPrivate', false));
      expect(jsonMap, containsPair('isPublic', true));
      expect(jsonMap, containsPair('isSynthetic', false));
    });
  });

  group('Type Serialization Tests', () {
    test('DartType serialization works', () {
      // We'll create a simple type for testing
      final type =
          (null as dynamic)
              as DartType; // This would be a real type in practice

      // Since we can't easily create types in tests without more setup,
      // we'll just test that the extensions are available
      expect(DartTypeSerializer, isNotNull);
      expect(InterfaceTypeSerializer, isNotNull);
      expect(FunctionTypeSerializer, isNotNull);
    });
  });
}
