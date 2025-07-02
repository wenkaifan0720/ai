# analyzer_serializer

A code generation package for serializing Dart analyzer elements and types to JSON, designed for use with AI models via MCP (Model Context Protocol).

## Features

- **Element Serialization**: Generate serializers for Dart analyzer elements (classes, functions, variables, etc.)
- **Type Serialization**: Generate serializers for Dart types (interfaces, functions, generics, etc.)
- **Code Generation**: Automatic generation of serialization methods using build_runner
- **JSON Compatible**: Output is JSON-serializable for easy transmission to AI models

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  analyzer_serializer: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.11
```

## Usage

### 1. Annotate Classes for Code Generation

```dart
import 'package:analyzer_serializer/analyzer_serializer.dart';

@GenerateElementSerializer()
class MyElementHandler {
  // Element serializer will be generated
}

@GenerateTypeSerializer()
class MyTypeHandler {
  // Type serializer will be generated
}
```

### 2. Run Code Generation

```bash
dart run build_runner build
```

### 3. Use Generated Serializers

```dart
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

// Example: Serialize an analyzer element
void serializeElement(Element element) {
  final serializer = MyElementHandlerSerializer();
  final json = serializer.toJson(element);
  print(json); // JSON representation of the element
}

// Example: Serialize a Dart type
void serializeType(DartType type) {
  final serializer = MyTypeHandlerSerializer();
  final json = serializer.toJson(type);
  print(json); // JSON representation of the type
}
```

### 4. Manual Serialization (Without Code Generation)

You can also use the built-in serializable classes directly:

```dart
import 'package:analyzer_serializer/analyzer_serializer.dart';

// Serialize an element manually
final serializableElement = SerializableElement.fromElement(element);
final json = serializableElement.toJson();

// Serialize a type manually
final serializableType = SerializableType.fromDartType(type);
final typeJson = serializableType.toJson();
```

## Architecture

The package provides:

1. **Base Interfaces**: `ElementSerializer` and `TypeSerializer` for implementing custom serializers
2. **Serializable Models**: `SerializableElement`, `SerializableType`, etc. for JSON-compatible representations
3. **Code Generators**: `ElementSerializerBuilder` and `TypeSerializerBuilder` for automatic generation
4. **Annotations**: `@GenerateElementSerializer()` and `@GenerateTypeSerializer()` for marking classes

## Example Output

When serializing a class element, you might get:

```json
{
  "kind": "ClassElement",
  "name": "MyClass",
  "displayName": "MyClass",
  "isPrivate": false,
  "isPublic": true,
  "isSynthetic": false,
  "metadata": [],
  "source": "file:///path/to/file.dart",
  "nameOffset": 123,
  "nameLength": 7
}
```

## Use Cases

- **AI Code Analysis**: Provide structured code information to AI models
- **MCP Servers**: Serialize analyzer data for Model Context Protocol
- **Code Documentation**: Generate structured documentation from code analysis
- **IDE Tools**: Build development tools that need to transmit code structure

## Contributing

Contributions are welcome! Please see the [repository](https://github.com/dart-lang/ai) for more details.