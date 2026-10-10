import 'package:flutter/foundation.dart';

import '../../core/l10n.dart';
import 'ai_explainer.dart';
import 'ai_guard.dart';
import 'assistant_models.dart';
import 'deterministic_assistant.dart';
import 'fact_sheet.dart';

/// Combines the built-in answer with an optional AI explanation.
///
/// The deterministic sections (verified data and calculations) are always
/// shown. The AI can only replace the plain-language summary, and only when
/// its text passes [AiResponseGuard]. Any failure falls back to the built-in
/// summary and says why.
class AssistantOrchestrator {
  const AssistantOrchestrator({
    this.deterministic = const DeterministicAssistant(),
    this.ai,
    this.guard = const AiResponseGuard(),
  });

  final DeterministicAssistant deterministic;

  /// `null` when no AI service is connected.
  final AiExplainer? ai;
  final AiResponseGuard guard;

  bool get aiConnected => ai != null;

  Future<AssistantReply> ask({
    required String question,
    required FactSheet? facts,
    required L10n l10n,
  }) async {
    final base = deterministic.reply(
      question: question,
      facts: facts,
      l10n: l10n,
    );
    if (facts == null) return base;

    final explainer = ai;
    if (explainer == null) {
      return base.copyWith(notices: [...base.notices, AssistantNotice.aiOff]);
    }

    try {
      final text = await explainer.explain(
        question: question,
        facts: facts,
        language: l10n.language,
      );
      final result = guard.validate(text, facts);
      if (!result.ok) {
        debugPrint(
          '[AssistantOrchestrator.ask] AI text rejected: ${result.problems.join('; ')}',
        );
        return base.copyWith(
          notices: [...base.notices, AssistantNotice.aiRejected],
        );
      }
      final sections = [
        for (final section in base.sections)
          if (section.provenance == Provenance.railocitySummary)
            ReplySection(
              provenance: Provenance.aiExplanation,
              title: l10n.sectionAi,
              lines: [text.trim()],
            )
          else
            section,
      ];
      return base.copyWith(sections: sections, usedAi: true);
    } on AssistantUnavailable catch (error) {
      debugPrint('[AssistantOrchestrator.ask] AI service failed: $error');
      return base.copyWith(
        notices: [...base.notices, AssistantNotice.aiUnavailable],
      );
    }
  }
}
