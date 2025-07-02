/// A library for serializing Dart analyzer elements and types to JSON strings.
///
/// This library provides extension methods on analyzer element and type classes
/// to convert them to serialized string representations for use with AI models
/// via MCP (Model Context Protocol).
library analyzer_serializer;

export 'src/element_extensions.dart';
export 'src/type_extensions.dart';
export 'src/serialization_utils.dart';
