import 'package:analyzer/dart/element/element.dart';
import 'serialization_utils.dart';

/// Extension methods for serializing analyzer elements to JSON strings.

/// Extension for the base Element class.
extension ElementSerializer on Element {
  /// Converts this element to a serialized JSON string.
  String toSerializedString() {
    final data = SerializationUtils.getBaseElementInfo(this);
    return SerializationUtils.mapToJsonString(data);
  }

  /// Converts this element to a JSON map.
  Map<String, dynamic> toJsonMap() {
    return SerializationUtils.getBaseElementInfo(this);
  }
}

/// Extension for ClassElement.
extension ClassElementSerializer on ClassElement {
  /// Converts this class element to a serialized JSON string.
  String toSerializedString() {
    final data = {
      ...SerializationUtils.getBaseElementInfo(this),
      'isAbstract': isAbstract,
      'isBase': isBase,
      'isFinal': isFinal,
      'isInterface': isInterface,
      'isMixinApplication': isMixinApplication,
      'isSealed': isSealed,
      'constructors':
          constructors
              .map(
                (c) => {
                  'name': c.name,
                  'displayName': c.displayName,
                  'isConst': c.isConst,
                  'isFactory': c.isFactory,
                  'isDefaultConstructor': c.isDefaultConstructor,
                  'parameters':
                      c.parameters
                          .map(
                            (p) => {
                              'name': p.name,
                              'type': p.type.getDisplayString(),
                              'isRequired': p.isRequired,
                              'isOptional': p.isOptional,
                              'hasDefaultValue': p.hasDefaultValue,
                            },
                          )
                          .toList(),
                },
              )
              .toList(),
      'fields':
          fields
              .map(
                (f) => {
                  'name': f.name,
                  'type': f.type.getDisplayString(),
                  'isStatic': f.isStatic,
                  'isFinal': f.isFinal,
                  'isConst': f.isConst,
                  'isLate': f.isLate,
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
                  'isAbstract': m.isAbstract,
                  'isOperator': m.isOperator,
                  'parameters':
                      m.parameters
                          .map(
                            (p) => {
                              'name': p.name,
                              'type': p.type.getDisplayString(),
                              'isRequired': p.isRequired,
                              'isOptional': p.isOptional,
                            },
                          )
                          .toList(),
                },
              )
              .toList(),
      'supertype': supertype?.getDisplayString(),
      'interfaces': interfaces.map((i) => i.getDisplayString()).toList(),
      'mixins': mixins.map((m) => m.getDisplayString()).toList(),
      'typeParameters':
          typeParameters
              .map(
                (tp) => {
                  'name': tp.name,
                  'bound': tp.bound?.getDisplayString(),
                },
              )
              .toList(),
    };
    return SerializationUtils.mapToJsonString(data);
  }

  /// Provides a focused, readable context format for AI models.
  String toContextString() {
    final buffer = StringBuffer();

    // Class declaration line
    buffer.write('class ${name}');

    // Type parameters
    if (typeParameters.isNotEmpty) {
      buffer.write('<${typeParameters.map((tp) => tp.name).join(', ')}>');
    }

    // Inheritance
    if (supertype != null && !supertype!.isDartCoreObject) {
      buffer.write(' extends ${supertype!.getDisplayString()}');
    }
    if (interfaces.isNotEmpty) {
      buffer.write(
        ' implements ${interfaces.map((i) => i.getDisplayString()).join(', ')}',
      );
    }
    if (mixins.isNotEmpty) {
      buffer.write(
        ' with ${mixins.map((m) => m.getDisplayString()).join(', ')}',
      );
    }

    buffer.writeln(' {');

    // Fields
    for (final field in fields) {
      buffer.write('  ');
      if (field.isStatic) buffer.write('static ');
      if (field.isConst) buffer.write('const ');
      if (field.isFinal) buffer.write('final ');
      if (field.isLate) buffer.write('late ');
      buffer.writeln('${field.type.getDisplayString()} ${field.name};');
    }

    if (fields.isNotEmpty && (constructors.isNotEmpty || methods.isNotEmpty)) {
      buffer.writeln();
    }

    // Constructors
    for (final constructor in constructors) {
      buffer.write('  ');
      if (constructor.isConst) buffer.write('const ');
      if (constructor.isFactory) buffer.write('factory ');
      buffer.write('${name}');
      if (constructor.name.isNotEmpty) {
        buffer.write('.${constructor.name}');
      }
      buffer.write('(');
      buffer.write(
        constructor.parameters
            .map((p) {
              final param = StringBuffer();
              if (p.isRequired) param.write('required ');
              param.write('${p.type.getDisplayString()} ${p.name}');
              if (p.hasDefaultValue && p.defaultValueCode != null) {
                param.write(' = ${p.defaultValueCode}');
              }
              return param.toString();
            })
            .join(', '),
      );
      buffer.writeln(');');
    }

    if (constructors.isNotEmpty && methods.isNotEmpty) {
      buffer.writeln();
    }

    // Methods
    for (final method in methods) {
      buffer.write('  ');
      if (method.isStatic) buffer.write('static ');
      if (method.isAbstract) buffer.write('abstract ');
      buffer.write('${method.returnType.getDisplayString()} ${method.name}(');
      buffer.write(
        method.parameters
            .map((p) {
              final param = StringBuffer();
              if (p.isRequired) param.write('required ');
              param.write('${p.type.getDisplayString()} ${p.name}');
              return param.toString();
            })
            .join(', '),
      );
      buffer.writeln(');');
    }

    buffer.writeln('}');

    return buffer.toString();
  }
}

/// Extension for FunctionElement.
extension FunctionElementSerializer on FunctionElement {
  /// Converts this function element to a serialized JSON string.
  String toSerializedString() {
    final data = {
      ...SerializationUtils.getBaseElementInfo(this),
      'returnType': returnType.getDisplayString(),
      'isExternal': isExternal,
      'isStatic': isStatic,
      'parameters':
          parameters
              .map(
                (p) => {
                  'name': p.name,
                  'type': p.type.getDisplayString(),
                  'isRequired': p.isRequired,
                  'isOptional': p.isOptional,
                  'hasDefaultValue': p.hasDefaultValue,
                  'defaultValueCode': p.defaultValueCode,
                },
              )
              .toList(),
      'typeParameters':
          typeParameters
              .map(
                (tp) => {
                  'name': tp.name,
                  'bound': tp.bound?.getDisplayString(),
                },
              )
              .toList(),
    };
    return SerializationUtils.mapToJsonString(data);
  }
}

/// Extension for VariableElement.
extension VariableElementSerializer on VariableElement {
  /// Converts this variable element to a serialized JSON string.
  String toSerializedString() {
    final data = {
      ...SerializationUtils.getBaseElementInfo(this),
      'type': type.getDisplayString(),
      'isConst': isConst,
      'isFinal': isFinal,
      'isLate': isLate,
      'isStatic': isStatic,
    };
    return SerializationUtils.mapToJsonString(data);
  }
}

/// Extension for PropertyAccessorElement.
extension PropertyAccessorElementSerializer on PropertyAccessorElement {
  /// Converts this property accessor element to a serialized JSON string.
  String toSerializedString() {
    final data = {
      ...SerializationUtils.getBaseElementInfo(this),
      'isGetter': isGetter,
      'isSetter': isSetter,
      'isStatic': isStatic,
      'returnType': returnType.getDisplayString(),
      'correspondingGetter': correspondingGetter?.name,
      'correspondingSetter': correspondingSetter?.name,
    };
    return SerializationUtils.mapToJsonString(data);
  }
}

/// Extension for EnumElement.
extension EnumElementSerializer on EnumElement {
  /// Converts this enum element to a serialized JSON string.
  String toSerializedString() {
    final data = {
      ...SerializationUtils.getBaseElementInfo(this),
      'constants':
          fields
              .where((f) => f.isEnumConstant)
              .map((c) => {'name': c.name, 'index': fields.indexOf(c)})
              .toList(),
      'constructors':
          constructors
              .map(
                (c) => {
                  'name': c.name,
                  'parameters':
                      c.parameters
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
      'methods':
          methods
              .map(
                (m) => {
                  'name': m.name,
                  'returnType': m.returnType.getDisplayString(),
                  'isStatic': m.isStatic,
                },
              )
              .toList(),
    };
    return SerializationUtils.mapToJsonString(data);
  }
}
