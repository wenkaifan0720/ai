// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_mcp/server.dart';

import 'dart_parser.dart';

/// Implementation of the get_dart_file_skeleton tool.
Future<CallToolResult> getDartFileSkeleton(CallToolRequest request) async {
  final filePath = request.arguments?['file_path'] as String?;
  if (filePath == null) {
    return CallToolResult(
      content: [TextContent(text: 'Missing required argument `file_path`.')],
      isError: true,
    );
  }

  final skipExpressionBodies =
      request.arguments?['skip_expression_bodies'] as bool? ?? false;
  final omitSkipComments =
      request.arguments?['omit_skip_comments'] as bool? ?? false;
  final skipImports = request.arguments?['skip_imports'] as bool? ?? false;

  try {
    final file = File(filePath);
    if (!await file.exists()) {
      return CallToolResult(
        content: [TextContent(text: 'File not found: $filePath')],
        isError: true,
      );
    }

    final content = await file.readAsString();
    final skeleton = parseDartFileSkipMethods(
      content,
      skipExpressionBodies: skipExpressionBodies,
      omitSkipComments: omitSkipComments,
      skipImports: skipImports,
    );

    return CallToolResult(
      content: [
        TextContent(
          text: 'Dart file skeleton for $filePath:\n\n```dart\n$skeleton\n```',
        ),
      ],
    );
  } on Exception catch (e) {
    return CallToolResult(
      content: [TextContent(text: 'Failed to parse file: $e')],
      isError: true,
    );
  }
}
