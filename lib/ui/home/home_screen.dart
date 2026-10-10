import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/journey_view.dart';
import '../../logic/assistant/fact_sheet.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../alternatives/alternatives_screen.dart';
import '../journey/add_journey_screen.dart';
import '../support/support_screen.dart';
import '../widgets/alert_card.dart';
import '../widgets/common.dart';
import '../shell/tabs.dart';

/// Answers three questions at once: what is happening, does it affect me,
/// and what should I do next.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final ValueChanged<AppTab> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final l10n = controller.l10n;
    final view = controller.activeView;
    final loading = controller.refreshState == RefreshState.loading;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: controller.journeys.isEmpty || loading
                ? null
                : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: Semantics(
                  label: l10n.refreshing,
                  child: const LinearProgressIndicator(minHeight: 4),
                ),
              )
            : null,
      ),
      body: !controller.loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  Space.m,
                  Space.s,
                  Space.m,
                  Space.xl,
                ),
                children: [
                  if (controller.data.isSimulated) ...[
                    DemoBanner(l10n: l10n),
                    const SizedBox(height: Space.m),
                  ],
                  DataStatusBanners(controller: controller, view: view),
                  if (view == null)
                    _EmptyHome(controller: controller)
                  else
                    ..._journeyContent(context, controller, view),
                ],
              ),
            ),
    );
  }

  List<Widget> _journeyContent(
    BuildContext context,
    AppController controller,
    JourneyView view,
  ) {
    final l10n = controller.l10n;
    final health = view.health;
    final style = styleForHealth(context, health);
    final needsAttention =
        health == JourneyHealth.atRisk ||
        health == JourneyHealth.likelyMissed ||
        health == JourneyHealth.cancelled;
    final names = JourneyNames(view);
    final urgent = controller.alerts
        .where((a) => !a.read && a.needsAction)
        .take(2)
        .toList();
    final other = controller.unreadAlertCount - urgent.length;

    return [
      Card(
        color: style.container,
        child: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${view.originName} → ${view.destinationName}',
                style: context.text.labelLarge?.copyWith(
                  color: style.onContainer,
                ),
              ),
              const SizedBox(height: Space.s + 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(style.icon, size: 32, color: style.onContainer),
                  const SizedBox(width: Space.s + 4),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.healthHeadline(health, view.maxDelayMinutes),
                        style: context.text.headlineSmall?.copyWith(
                          color: style.onContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s + 4),
              Text(
                l10n.healthDetail(view, names: names),
                style: context.text.bodyLarge?.copyWith(
                  color: style.onContainer,
                ),
              ),
              const SizedBox(height: Space.m),
              FreshnessLine(
                updatedAt: view.oldestUpdate,
                now: controller.now,
                source: controller.data.sourceLabel,
                l10n: l10n,
                color: style.onContainer,
              ),
              const SizedBox(height: Space.m),
              Text(
                l10n.nextStep(health),
                style: context.text.titleSmall?.copyWith(
                  color: style.onContainer,
                ),
              ),
              const SizedBox(height: Space.s + 4),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  if (needsAttention) ...[
                    FilledButton.icon(
                      onPressed: () => _open(
                        context,
                        AlternativesScreen(journeyId: view.journey.id),
                      ),
                      icon: const Icon(Icons.alt_route),
                      label: Text(l10n.seeAlternatives),
                    ),
                    OutlinedButton(
                      onPressed: () => _open(context, const SupportScreen()),
                      child: Text(l10n.officialHelp),
                    ),
                  ] else
                    FilledButton.tonalIcon(
                      onPressed: () => onOpenTab(AppTab.assistant),
                      icon: const Icon(Icons.chat_outlined),
                      label: Text(l10n.askAssistant),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: Space.s),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => onOpenTab(AppTab.journey),
          icon: const Icon(Icons.route),
          label: Text(l10n.navJourney),
        ),
      ),
      SectionTitle(urgent.isEmpty ? l10n.otherUpdates : l10n.needsYourAction),
      if (urgent.isEmpty && controller.unreadAlertCount == 0)
        Text(l10n.noAlerts, style: context.text.bodyMedium),
      for (final alert in urgent) ...[
        AlertCard(alert: alert, controller: controller),
        const SizedBox(height: Space.s + 4),
      ],
      if (other > 0 || (urgent.isEmpty && controller.unreadAlertCount > 0))
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => onOpenTab(AppTab.alerts),
            child: Text(l10n.seeAllAlerts),
          ),
        ),
    ];
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = controller.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.train_outlined, size: 40, color: context.colors.primary),
            const SizedBox(height: Space.m),
            Semantics(
              header: true,
              child: Text(
                l10n.homeEmptyTitle,
                style: context.text.headlineSmall,
              ),
            ),
            const SizedBox(height: Space.s),
            Text(l10n.homeEmptyBody, style: context.text.bodyLarge),
            const SizedBox(height: Space.l),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AddJourneyScreen(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.addJourney),
            ),
          ],
        ),
      ),
    );
  }
}
