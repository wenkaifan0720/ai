import 'dart:convert';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Utility functions for serialization of analyzer elements and types.
class SerializationUtils {
  /// Converts a value to a JSON-serializable format.
  static dynamic toJsonValue(dynamic value) {
    if (value == null) return null;
    if (value is String || value is num || value is bool) return value;
    if (value is List) return value.map(toJsonValue).toList();
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), toJsonValue(val)),
      );
    }
    return value.toString();
  }

  /// Converts a map to a JSON string.
  static String mapToJsonString(Map<String, dynamic> map) {
    return JsonEncoder.withIndent('  ').convert(map);
  }

  /// Gets the source location information for an element.
  static Map<String, dynamic> getSourceInfo(Element element) {
    final source = element.source;
    return {
      'source': source?.fullName,
      'nameOffset': element.nameOffset,
      'nameLength': element.nameLength,
    };
  }

  /// Gets basic element information.
  static Map<String, dynamic> getBaseElementInfo(Element element) {
    return {
      'kind': element.kind.name,
      'name': element.name,
      'displayName': element.displayName,
      'isPrivate': element.isPrivate,
      'isPublic': element.isPublic,
      'isSynthetic': element.isSynthetic,
      'metadata': element.metadata.map((m) => m.toSource()).toList(),
      ...getSourceInfo(element),
    };
  }

  /// Gets basic type information.
  static Map<String, dynamic> getBaseTypeInfo(DartType type) {
    return {
      'displayName': type.getDisplayString(),
      'nullabilitySuffix': type.nullabilitySuffix.name,
      'isDynamic': type is DynamicType,
      'isVoid': type is VoidType,
      'isBottom': type.isBottom,
      'element': type.element?.name,
    };
  }
}
