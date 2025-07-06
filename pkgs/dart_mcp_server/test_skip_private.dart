import 'dart:io';
import 'package:dart_mcp_server/src/analyzer/dart_parser.dart';

void main() async {
  final file = File('example_private_members.dart');
  final content = await file.readAsString();
  
  print('=== Original file ===');
  print(content);
  
  print('\n=== With skip_private: false (default) ===');
  final withPrivate = parseDartFileSkipMethods(
    content,
    skipPrivate: false,
    omitSkipComments: true,
  );
  print(withPrivate);
  
  print('\n=== With skip_private: true ===');
  final withoutPrivate = parseDartFileSkipMethods(
    content,
    skipPrivate: true,
    omitSkipComments: true,
  );
  print(withoutPrivate);
}
