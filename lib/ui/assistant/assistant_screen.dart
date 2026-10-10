import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../logic/assistant/assistant_models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../alternatives/alternatives_screen.dart';
import '../support/support_screen.dart';
import '../widgets/common.dart';

/// Context-aware help. Every reply shows which parts are verified data,
/// which are calculated, and which are written text.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _shownCount = 0;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(AppController controller, [String? text]) {
    final question = (text ?? _input.text).trim();
    if (question.isEmpty) return;
    _input.clear();
    controller.askAssistant(question);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final l10n = controller.l10n;
    final chat = controller.chat;
    if (chat.length != _shownCount) {
      _shownCount = chat.length;
      _scrollToEnd();
    }

    final suggestions = [
      l10n.suggestConnection,
      l10n.suggestOptions,
      l10n.suggestRefund,
      l10n.suggestPlatform,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.assistantTitle)),
      body: Column(
        children: [
          Expanded(
            // A chat is short, so every child is built. That keeps it simple
            // for screen readers and keeps scrolling to the end reliable.
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(Space.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (controller.data.isSimulated) ...[
                    DemoBanner(l10n: l10n),
                    const SizedBox(height: Space.m),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.m),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.support_agent,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: Space.s + 4),
                          Expanded(
                            child: Text(
                              l10n.assistantIntro,
                              style: context.text.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.m),
                  for (final message in chat) ...[
                    if (message.isUser)
                      _UserBubble(text: message.text!)
                    else
                      _ReplyView(reply: message.reply!, controller: controller),
                    const SizedBox(height: Space.m),
                  ],
                  if (controller.assistantBusy)
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: Space.s + 4),
                          Text(l10n.thinking),
                        ],
                      ),
                    )
                  else
                    // Part of the conversation, not pinned. The chips wrap, so
                    // they stay readable at large text sizes, and the input
                    // below always keeps its space.
                    Wrap(
                      spacing: Space.s,
                      runSpacing: Space.s,
                      children: [
                        for (final suggestion in suggestions)
                          ActionChip(
                            label: Text(suggestion),
                            onPressed: () => _send(controller, suggestion),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.m,
                Space.s,
                Space.m,
                Space.s,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(controller),
                          decoration: InputDecoration(hintText: l10n.askHint),
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      IconButton.filled(
                        tooltip: l10n.send,
                        onPressed: controller.assistantBusy
                            ? null
                            : () => _send(controller),
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.m,
          vertical: Space.s + 4,
        ),
        decoration: BoxDecoration(
          color: context.colors.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _ReplyView extends StatelessWidget {
  const _ReplyView({required this.reply, required this.controller});

  final AssistantReply reply;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = controller.l10n;
    final active = controller.activeView;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final notice in reply.notices) ...[
          NoticePanel(
            icon: notice == AssistantNotice.dataProblem
                ? Icons.cloud_off
                : Icons.info_outline,
            message: _noticeText(notice, l10n),
          ),
          const SizedBox(height: Space.s),
        ],
        for (final section in reply.sections) ...[
          _SectionCard(section: section, controller: controller),
          const SizedBox(height: Space.s),
        ],
        if (active != null &&
            (reply.suggestAlternatives || reply.suggestSupport))
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              if (reply.suggestAlternatives)
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AlternativesScreen(journeyId: active.journey.id),
                    ),
                  ),
                  icon: const Icon(Icons.alt_route),
                  label: Text(l10n.seeAlternatives),
                ),
              if (reply.suggestSupport)
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SupportScreen(),
                    ),
                  ),
                  child: Text(l10n.officialHelp),
                ),
            ],
          ),
      ],
    );
  }

  String _noticeText(AssistantNotice notice, L10n l10n) => switch (notice) {
    AssistantNotice.aiOff => l10n.noticeAiOff,
    AssistantNotice.aiUnavailable => l10n.noticeAiUnavailable,
    AssistantNotice.aiRejected => l10n.noticeAiRejected,
    AssistantNotice.dataProblem => l10n.assistantDataProblem,
  };
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.controller});

  final ReplySection section;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = controller.l10n;
    final (IconData, String)? badge = switch (section.provenance) {
      Provenance.verified => (
        Icons.verified_outlined,
        section.simulated ? l10n.badgeDemo : l10n.badgeVerified,
      ),
      Provenance.calculated => (Icons.calculate_outlined, l10n.badgeCalculated),
      Provenance.aiExplanation => (Icons.auto_awesome, l10n.badgeAi),
      Provenance.railocitySummary => (Icons.edit_note, l10n.badgeRailocity),
      Provenance.nextSteps => null,
    };
    final highlight = section.provenance == Provenance.nextSteps;

    return Card(
      color: highlight ? context.colors.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(section.title, style: context.text.titleSmall),
            ),
            if (badge != null) ...[
              const SizedBox(height: Space.s),
              StatusChip(icon: badge.$1, label: badge.$2),
            ],
            const SizedBox(height: Space.s + 4),
            for (final line in section.lines) ...[
              Text(line, style: context.text.bodyLarge),
              const SizedBox(height: Space.s),
            ],
            if (section.asOf != null && section.source != null)
              FreshnessLine(
                updatedAt: section.asOf,
                now: controller.now,
                source: section.source!,
                l10n: l10n,
              ),
          ],
        ),
      ),
    );
  }
}
