import 'dart:io';
import 'package:args/args.dart';
import 'package:ast_context/dart_parser.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('input', abbr: 'i', help: 'Input Dart file path')
    ..addOption('output', abbr: 'o', help: 'Output file path (optional)')
    ..addFlag('skip-expression-bodies',
        help: 'Skip expression function bodies (=>) as well as block bodies',
        negatable: false)
    ..addFlag('omit-skip-comments',
        help: 'Omit the "// Lines X-Y skipped" comments', negatable: false)
    ..addFlag('skip-imports',
        help: 'Skip import directives entirely', negatable: false)
    ..addFlag('skip-private',
        help: 'Skip private fields, methods, functions, and classes',
        negatable: false)
    ..addFlag('help', abbr: 'h', help: 'Show usage help', negatable: false);

  try {
    final results = parser.parse(arguments);

    if (results['help'] == true) {
      _printUsage(parser);
      exit(0);
    }

    final inputPath = results['input'] as String?;
    if (inputPath == null) {
      stderr.writeln('Error: Input file path is required');
      _printUsage(parser);
      exit(1);
    }

    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      stderr.writeln('Error: Input file not found: $inputPath');
      exit(1);
    }

    // Read the input file
    final content = await inputFile.readAsString();

    // Process the content with the specified flags
    final processedContent = parseDartFileSkipMethods(
      content,
      skipExpressionBodies: results['skip-expression-bodies'] == true,
      omitSkipComments: results['omit-skip-comments'] == true,
      skipImports: results['skip-imports'] == true,
      skipPrivate: results['skip-private'] == true,
    );

    // Output the result
    final outputPath = results['output'] as String?;
    if (outputPath != null) {
      await File(outputPath).writeAsString(processedContent);
      stdout.writeln('Processed content written to: $outputPath');
    } else {
      stdout.write(processedContent);
    }
  } catch (e) {
    stderr.writeln('Error: $e');
    _printUsage(parser);
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  stdout.writeln('Usage: dart_parser_cli.dart [options]');
  stdout.writeln('A tool to parse Dart files and remove method bodies.');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(parser.usage);
  stdout.writeln();
  stdout.writeln('Examples:');
  stdout.writeln('  # Basic usage - remove method bodies only');
  stdout.writeln(
      '  dart bin/dart_parser_cli.dart -i lib/main.dart -o output.dart');
  stdout.writeln('');
  stdout.writeln('  # Skip private members and imports');
  stdout.writeln(
      '  dart bin/dart_parser_cli.dart -i lib/main.dart --skip-private --skip-imports');
  stdout.writeln('');
  stdout.writeln('  # Skip everything and omit comments');
  stdout.writeln(
      '  dart bin/dart_parser_cli.dart -i lib/main.dart --skip-private --skip-imports --skip-expression-bodies --omit-skip-comments');
}
