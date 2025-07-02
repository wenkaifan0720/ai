import 'package:analyzer/dart/element/type.dart';
import 'serialization_utils.dart';

/// Extension methods for serializing analyzer types to JSON strings.

/// Extension for the base DartType class.
extension DartTypeSerializer on DartType {
  /// Converts this type to a serialized JSON string.
  String toSerializedString() {
    final data = SerializationUtils.getBaseTypeInfo(this);
    return SerializationUtils.mapToJsonString(data);
  }

  /// Converts this type to a JSON map.
  Map<String, dynamic> toJsonMap() {
    return SerializationUtils.getBaseTypeInfo(this);
  }
}

/// Extension for InterfaceType.
extension InterfaceTypeSerializer on InterfaceType {
  /// Converts this interface type to a serialized JSON string.
  String toSerializedString() {
    final data = {
      ...SerializationUtils.getBaseTypeInfo(this),
      'className': element.name,
      'typeArguments': typeArguments.map((t) => t.getDisplayString()).toList(),
      'superclass': superclass?.getDisplayString(),
      'interfaces': interfaces.map((i) => i.getDisplayString()).toList(),
      'mixins': mixins.map((m) => m.getDisplayString()).toList(),
      'constructors':
          constructors
              .map(
                (c) => {
                  'name': c.name,
                  'isFactory': c.isFactory,
                  'isConst': c.isConst,
                  'parameters':
                      c.parameters
                          .map(
                            (p) => {
                              'name': p.name,
                              'type': p.type.getDisplayString(),
                              'isRequired': p.isRequired,
                            },
                          )
                          .toList(),
                },
              )
              .toList(),
      'methods':
          methods
              .map(
                (m) => {
                  'name': m.name,
                  'returnType': m.returnType.getDisplayString(),
                  'isStatic': m.isStatic,
                  'parameters':
                      m.parameters
                          .map(
                            (p) => {
                              'name': p.name,
                              'type': p.type.getDisplayString(),
                            },
                          )
                          .toList(),
                },
              )
              .toList(),
      'accessors':
          accessors
              .map(
                (a) => {
                  'name': a.name,
                  'isGetter': a.isGetter,
                  'isSetter': a.isSetter,
                  'returnType': a.returnType.getDisplayString(),
                  'isStatic': a.isStatic,
                },
              )
              .toList(),
    };
    return SerializationUtils.mapToJsonString(data);
  }
}

/// Extension for FunctionType.
extension FunctionTypeSerializer on FunctionType {
  /// Converts this function type to a serialized JSON string.
  String toSerializedString() {
    final data = {
      ...SerializationUtils.getBaseTypeInfo(this),
      'returnType': returnType.getDisplayString(),
      'parameters':
          parameters
              .map(
                (p) => {
                  'name': p.name,
                  'type': p.type.getDisplayString(),
                  'isRequired': p.isRequired,
                  'isOptional': p.isOptional,
                  'isNamed': p.isNamed,
                  'isPositional': p.isPositional,
                  'hasDefaultValue': p.hasDefaultValue,
                },
              )
              .toList(),
      'typeFormals':
          typeFormals
              .map(
                (tf) => {
                  'name': tf.name,
                  'bound': tf.bound?.getDisplayString(),
                },
              )
              .toList(),
    };
    return SerializationUtils.mapToJsonString(data);
  }
}

/// Extension for RecordType.
extension RecordTypeSerializer on RecordType {
  /// Converts this record type to a serialized JSON string.
  String toSerializedString() {
    final data = {
      ...SerializationUtils.getBaseTypeInfo(this),
      'positionalFields':
          positionalFields
              .map((f) => {'type': f.type.getDisplayString()})
              .toList(),
      'namedFields':
          namedFields
              .map((f) => {'name': f.name, 'type': f.type.getDisplayString()})
              .toList(),
    };
    return SerializationUtils.mapToJsonString(data);
  }
}

/// Extension for TypeParameterType.
extension TypeParameterTypeSerializer on TypeParameterType {
  /// Converts this type parameter type to a serialized JSON string.
  String toSerializedString() {
    final data = {
      ...SerializationUtils.getBaseTypeInfo(this),
      'bound': bound?.getDisplayString(),
    };
    return SerializationUtils.mapToJsonString(data);
  }
}

/// Extension for DynamicType.
extension DynamicTypeSerializer on DynamicType {
  /// Converts this dynamic type to a serialized JSON string.
  String toSerializedString() {
    final data = {
      ...SerializationUtils.getBaseTypeInfo(this),
      'typeName': 'dynamic',
    };
    return SerializationUtils.mapToJsonString(data);
  }
}

/// Extension for VoidType.
extension VoidTypeSerializer on VoidType {
  /// Converts this void type to a serialized JSON string.
  String toSerializedString() {
    final data = {
      ...SerializationUtils.getBaseTypeInfo(this),
      'typeName': 'void',
    };
    return SerializationUtils.mapToJsonString(data);
  }
}

/// Extension for NeverType.
extension NeverTypeSerializer on NeverType {
  /// Converts this never type to a serialized JSON string.
  String toSerializedString() {
    final data = {
      ...SerializationUtils.getBaseTypeInfo(this),
      'typeName': 'Never',
    };
    return SerializationUtils.mapToJsonString(data);
  }
}
