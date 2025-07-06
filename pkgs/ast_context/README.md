# AST Context

A Flutter project with tools for working with Dart Abstract Syntax Trees.

## Dart Parser CLI

This package provides a CLI tool to parse Dart files and extract their structure while skipping method/function implementations. The parser preserves the overall structure of the code while replacing method bodies with comments indicating the skipped line numbers.

### Features

- Parses Dart files using the analyzer package
- Preserves the complete structure including classes, methods, and functions
- Removes method/function implementation details
- Adds comments with line number information to show skipped blocks
- Preserves arrow functions (=>)
- CLI tool for easy usage

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd ast_context

# Install dependencies
flutter pub get
```

### Usage

You can use the Dart Parser CLI tool to process Dart files:

```bash
# Process a file and print to stdout
dart bin/dart_parser_cli.dart -i lib/main.dart

# Process a file and save the output to a new file
dart bin/dart_parser_cli.dart -i lib/main.dart -o output.dart

# Show help
dart bin/dart_parser_cli.dart --help
```

### API Usage

You can also use the parseDartFileSkipMethods function directly in your code:

```dart
import 'package:ast_context/dart_parser.dart';

void main() {
  final dartCode = '''
class Example {
  void method() {
    print('This will be removed');
  }
  
  String arrowMethod() => 'This will be preserved';
}
''';

  final result = parseDartFileSkipMethods(dartCode);
  print(result);
}
```

### Example Output

```dart
// Original code
class Example {
  void method() {
    print('Implementation details');
    for (var i = 0; i < 10; i++) {
      doSomething(i);
    }
  }
  
  String arrowMethod() => 'Preserved';
}

// Parsed output
class Example {
  void method() {
    // Lines 3-7 skipped.
  }
  
  String arrowMethod() => 'Preserved';
}
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
