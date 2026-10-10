import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/l10n.dart';
import 'fact_sheet.dart';

/// The AI service could not give a usable answer.
class AssistantUnavailable implements Exception {
  const AssistantUnavailable(this.detail);

  /// Developer detail. Never show this text to a passenger.
  final String detail;

  @override
  String toString() => 'AssistantUnavailable($detail)';
}

/// Turns a fact sheet into a plain-language explanation.
///
/// An implementation must explain only what is in [FactSheet]. The caller
/// checks the text with `AiResponseGuard` before it is shown.
abstract interface class AiExplainer {
  Future<String> explain({
    required String question,
    required FactSheet facts,
    required AppLanguage language,
  });
}

/// Calls an AI proxy over HTTPS.
///
/// The app never holds an AI provider key. The proxy holds it and adds the
/// instructions. See `tools/ai_proxy/README.md`.
///
/// Request: `POST` JSON `{ "question", "language", "facts" }`.
/// Response: `200` JSON `{ "text": "..." }`.
class HttpAiExplainer implements AiExplainer {
  HttpAiExplainer(this.endpoint, {this.timeout = const Duration(seconds: 15)});

  final Uri endpoint;
  final Duration timeout;

  @override
  Future<String> explain({
    required String question,
    required FactSheet facts,
    required AppLanguage language,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(endpoint).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'question': question,
          'language': language.name,
          'facts': facts.toJson(),
        }),
      );
      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw AssistantUnavailable('HTTP ${response.statusCode}');
      }
      final json = jsonDecode(body);
      final text = json is Map ? json['text'] : null;
      if (text is! String || text.trim().isEmpty) {
        throw const AssistantUnavailable('response has no text');
      }
      return text;
    } on AssistantUnavailable {
      rethrow;
    } on Object catch (error) {
      throw AssistantUnavailable('$error');
    } finally {
      client.close(force: true);
    }
  }
}
