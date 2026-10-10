/// Where a part of an assistant reply comes from.
///
/// The screen shows this next to each part, so the passenger can tell
/// verified data, calculated values and generated text apart.
enum Provenance {
  /// Taken directly from railway data.
  verified,

  /// Worked out by deterministic Railocity code.
  calculated,

  /// Written by an AI model. Checked by the guard before it is shown.
  aiExplanation,

  /// Written by Railocity code from the facts. Not AI.
  railocitySummary,

  /// Suggested next steps.
  nextSteps,
}

enum AssistantNotice {
  /// No AI service is connected.
  aiOff,

  /// The AI service did not answer.
  aiUnavailable,

  /// The AI text did not match the verified data.
  aiRejected,

  /// The last data refresh failed, so the answer may use old data.
  dataProblem,
}

class ReplySection {
  const ReplySection({
    required this.provenance,
    required this.title,
    required this.lines,
    this.asOf,
    this.source,
    this.simulated = false,
  });

  final Provenance provenance;
  final String title;
  final List<String> lines;

  /// When the underlying data was last confirmed, for verified sections.
  final DateTime? asOf;
  final String? source;

  /// `true` when the data behind this section is simulated demo data.
  final bool simulated;
}

class AssistantReply {
  const AssistantReply({
    required this.sections,
    this.notices = const [],
    this.usedAi = false,
    this.suggestAlternatives = false,
    this.suggestSupport = false,
  });

  final List<ReplySection> sections;
  final List<AssistantNotice> notices;
  final bool usedAi;

  /// Show a button to the "other trains" screen.
  final bool suggestAlternatives;

  /// Show a button to the "official help" screen.
  final bool suggestSupport;

  AssistantReply copyWith({
    List<ReplySection>? sections,
    List<AssistantNotice>? notices,
    bool? usedAi,
  }) => AssistantReply(
    sections: sections ?? this.sections,
    notices: notices ?? this.notices,
    usedAi: usedAi ?? this.usedAi,
    suggestAlternatives: suggestAlternatives,
    suggestSupport: suggestSupport,
  );
}

/// One entry in the chat.
class ChatMessage {
  const ChatMessage.user(this.text) : reply = null, isUser = true;

  const ChatMessage.assistant(AssistantReply this.reply)
    : text = null,
      isUser = false;

  final bool isUser;
  final String? text;
  final AssistantReply? reply;
}
