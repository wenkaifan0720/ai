import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_serializer/analyzer_serializer.dart';

Future<void> main() async {
  // Create an analysis context collection for the current directory
  final collection = AnalysisContextCollection(
    includedPaths: [Directory.current.path],
  );

  // Find a Dart file to analyze
  final dartFiles = Directory.current
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .take(1);

  if (dartFiles.isEmpty) {
    print('No Dart files found in the current directory.');
    return;
  }

  final file = dartFiles.first;
  print('Analyzing file: ${file.path}');

  // Get the analysis context for the file
  final context = collection.contextFor(file.path);

  // Get the library result
  final result = await context.currentSession.getResolvedLibrary(file.path);

  if (result is ResolvedLibraryResult) {
    final library = result.element;

    // Serialize classes with different formats
    for (final unit in library.units) {
      for (final classElement in unit.classes) {
        print('\n' + '=' * 60);
        print('Class: ${classElement.name}');
        print('=' * 60);

        print('\n--- Focused Context Format ---');
        print(classElement.toContextString());

        print('\n--- Full JSON Serialization ---');
        print(classElement.toSerializedString());
      }

      // Show function context
      for (final functionElement in unit.functions) {
        print('\n--- Function: ${functionElement.name} ---');
        print(
          '${functionElement.returnType.getDisplayString()} ${functionElement.name}(',
        );
        for (final param in functionElement.parameters) {
          print(
            '  ${param.isRequired ? 'required ' : ''}${param.type.getDisplayString()} ${param.name}${param.hasDefaultValue ? ' = ${param.defaultValueCode}' : ''},',
          );
        }
        print(');');
      }

      // Serialize variables
      for (final variable in unit.topLevelVariables) {
        print('\n=== Variable: ${variable.name} ===');
        print(variable.toSerializedString());
      }

      // Serialize enums
      for (final enumElement in unit.enums) {
        print('\n=== Enum: ${enumElement.name} ===');
        print(enumElement.toSerializedString());
      }
    }
  }
}
