// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_mcp/server.dart';
import 'package:path/path.dart' as path;

import '../utils/sdk.dart';

/// Implementation of the convert_dart_uri tool.
Future<CallToolResult> convertDartUri(
  CallToolRequest request,
  SdkSupport sdkSupport,
  AnalysisContextCollection analysisCollection,
) async {
  final uri = request.arguments?['uri'] as String?;
  final contextPath = request.arguments?['context_path'] as String?;

  if (uri == null) {
    return CallToolResult(
      content: [TextContent(text: 'Missing required argument `uri`.')],
      isError: true,
    );
  }

  try {
    final dartSdkPath = sdkSupport.sdk.dartSdkPath;
    if (dartSdkPath == null) {
      return CallToolResult(
        content: [TextContent(text: 'Could not find Dart SDK path.')],
        isError: true,
      );
    }

    // Parse the URI
    final parsedUri = Uri.parse(uri);

    // For package: URIs, we need a context to resolve dependencies
    if (parsedUri.scheme == 'package' && contextPath == null) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'For package: URIs, a context_path is required to resolve dependencies.',
          ),
        ],
        isError: true,
      );
    }

    // Determine the appropriate context to use
    final contextForUri =
        contextPath != null
            ? analysisCollection.contextFor(path.dirname(contextPath))
            : analysisCollection.contexts.first;

    final session = contextForUri.currentSession;
    final uriConverter = session.uriConverter;

    // Use the URI converter to convert the URI to a file path
    final filePath = uriConverter.uriToPath(parsedUri);

    if (filePath != null) {
      // Check if the file exists
      if (await File(filePath).exists()) {
        return CallToolResult(
          content: [
            TextContent(text: 'URI "$uri" resolved to file path:\n$filePath'),
          ],
        );
      } else {
        return CallToolResult(
          content: [
            TextContent(
              text:
                  'URI "$uri" resolved to file path:\n$filePath\n\nNote: File does not exist at this location.',
            ),
          ],
        );
      }
    } else {
      return CallToolResult(
        content: [
          TextContent(text: 'Could not resolve URI "$uri" to a file path.'),
        ],
        isError: true,
      );
    }
  } on Exception catch (e) {
    return CallToolResult(
      content: [TextContent(text: 'Failed to convert URI: $e')],
      isError: true,
    );
  }
}

/// Implementation of the convert_dart_uri tool using AnalysisContext directly.
/// This is more efficient when you already have the correct context.
Future<CallToolResult> convertDartUriWithContext(
  CallToolRequest request,
  SdkSupport sdkSupport,
  AnalysisContext analysisContext,
) async {
  final uri = request.arguments?['uri'] as String?;
  final contextPath = request.arguments?['context_path'] as String?;

  if (uri == null) {
    return CallToolResult(
      content: [TextContent(text: 'Missing required argument `uri`.')],
      isError: true,
    );
  }

  try {
    final dartSdkPath = sdkSupport.sdk.dartSdkPath;
    if (dartSdkPath == null) {
      return CallToolResult(
        content: [TextContent(text: 'Could not find Dart SDK path.')],
        isError: true,
      );
    }

    // Parse the URI
    final parsedUri = Uri.parse(uri);

    // For package: URIs, we need a context to resolve dependencies
    if (parsedUri.scheme == 'package' && contextPath == null) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'For package: URIs, a context_path is required to resolve dependencies.',
          ),
        ],
        isError: true,
      );
    }

    final session = analysisContext.currentSession;
    final uriConverter = session.uriConverter;

    // Use the URI converter to convert the URI to a file path
    final filePath = uriConverter.uriToPath(parsedUri);

    if (filePath != null) {
      // Check if the file exists
      if (await File(filePath).exists()) {
        return CallToolResult(
          content: [
            TextContent(text: 'URI "$uri" resolved to file path:\n$filePath'),
          ],
        );
      } else {
        return CallToolResult(
          content: [
            TextContent(
              text:
                  'URI "$uri" resolved to file path:\n$filePath\n\nNote: File does not exist at this location.',
            ),
          ],
        );
      }
    } else {
      return CallToolResult(
        content: [
          TextContent(text: 'Could not resolve URI "$uri" to a file path.'),
        ],
        isError: true,
      );
    }
  } on Exception catch (e) {
    return CallToolResult(
      content: [TextContent(text: 'Failed to convert URI: $e')],
      isError: true,
    );
  }
}
