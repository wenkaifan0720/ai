// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:ast_context/dart_parser.dart';
import 'package:dart_mcp/server.dart';

/// Implementation of the get_dart_file_outline tool.
Future<CallToolResult> getDartFileOutline(CallToolRequest request) async {
  final uriString = request.arguments?['uri'] as String?;
  if (uriString == null) {
    return CallToolResult(
      content: [TextContent(text: 'Missing required argument `uri`.')],
      isError: true,
    );
  }

  // Convert URI to file path
  final uri = Uri.parse(uriString);
  final filePath = uri.scheme == 'file' ? uri.toFilePath() : uriString;

  final skipExpressionBodies = true;
  final omitSkipComments = true;
  final skipPrivate = true;
  final skipComments = request.arguments?['skip_comments'] as bool? ?? true;
  final skipImports = false;
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      return CallToolResult(
        content: [TextContent(text: 'File not found: $filePath')],
        isError: true,
      );
    }

    final content = await file.readAsString();
    final outline = parseDartFileSkipMethods(
      content,
      skipExpressionBodies: skipExpressionBodies,
      omitSkipComments: omitSkipComments,
      skipImports: skipImports,
      skipPrivate: skipPrivate,
      skipComments: skipComments,
    );

    return CallToolResult(
      content: [
        TextContent(
          text: 'Dart file outline for $filePath:\n\n```dart\n$outline\n```',
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
