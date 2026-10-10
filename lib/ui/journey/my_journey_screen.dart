import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/journey.dart';
import '../../logic/assistant/fact_sheet.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../alternatives/alternatives_screen.dart';
import '../support/support_screen.dart';
import '../widgets/common.dart';
import '../widgets/journey_widgets.dart';
import 'add_journey_screen.dart';

/// Saved journeys. Tap one for the details of each train and connection.
class MyJourneyScreen extends StatelessWidget {
  const MyJourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final l10n = controller.l10n;
    final journeys = controller.journeys;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.journeyTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AddJourneyScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.addJourney),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.m,
          Space.s,
          Space.m,
          96, // Space for the button.
        ),
        children: [
          if (controller.data.isSimulated) ...[
            DemoBanner(l10n: l10n),
            const SizedBox(height: Space.m),
          ],
          DataStatusBanners(
            controller: controller,
            view: controller.activeView,
          ),
          if (journeys.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xl),
              child: Text(l10n.noJourneys, style: context.text.bodyLarge),
            ),
          for (final journey in journeys) ...[
            _JourneyTile(journey: journey, controller: controller),
            const SizedBox(height: Space.s + 4),
          ],
        ],
      ),
    );
  }
}

class _JourneyTile extends StatelessWidget {
  const _JourneyTile({required this.journey, required this.controller});

  final Journey journey;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = controller.l10n;
    final view = controller.viewOf(journey);
    final style = styleForHealth(context, view.health);
    final trains = [
      for (var i = 0; i < journey.legs.length; i++)
        view.schedules[i]?.displayName ?? journey.legs[i].trainNumber,
    ].join(' + ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => JourneyDetailScreen(journeyId: journey.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${view.originName} → ${view.destinationName}',
                style: context.text.titleMedium,
              ),
              const SizedBox(height: Space.xs),
              Text(trains, style: context.text.bodyMedium),
              const SizedBox(height: Space.s + 4),
              StatusChip(
                icon: style.icon,
                label: l10n.healthHeadline(view.health, view.maxDelayMinutes),
                container: style.container,
                onContainer: style.onContainer,
              ),
              const SizedBox(height: Space.s + 4),
              FreshnessLine(
                updatedAt: view.oldestUpdate,
                now: controller.now,
                source: controller.data.sourceLabel,
                l10n: l10n,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Each train of a journey, with the connection checks between them.
class JourneyDetailScreen extends StatelessWidget {
  const JourneyDetailScreen({super.key, required this.journeyId});

  final String journeyId;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final l10n = controller.l10n;
    final matches = controller.journeys.where((j) => j.id == journeyId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.journeyTitle)),
        body: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: Text(l10n.noJourneys),
        ),
      );
    }
    final view = controller.viewOf(matches.first);
    final style = styleForHealth(context, view.health);
    final names = JourneyNames(view);

    return Scaffold(
      appBar: AppBar(
        title: Text('${view.originName} → ${view.destinationName}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.xl),
        children: [
          if (controller.data.isSimulated) ...[
            DemoBanner(l10n: l10n),
            const SizedBox(height: Space.m),
          ],
          DataStatusBanners(controller: controller, view: view),
          Card(
            color: style.container,
            child: Padding(
              padding: const EdgeInsets.all(Space.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(style.icon, color: style.onContainer),
                      const SizedBox(width: Space.s + 4),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            l10n.healthHeadline(
                              view.health,
                              view.maxDelayMinutes,
                            ),
                            style: context.text.titleLarge?.copyWith(
                              color: style.onContainer,
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
                  const SizedBox(height: Space.s + 4),
                  FreshnessLine(
                    updatedAt: view.oldestUpdate,
                    now: controller.now,
                    source: controller.data.sourceLabel,
                    l10n: l10n,
                    color: style.onContainer,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          for (var i = 0; i < view.journey.legs.length; i++) ...[
            LegCard(view: view, index: i, l10n: l10n),
            const SizedBox(height: Space.s + 4),
            if (i < view.connections.length) ...[
              ConnectionCard(
                view: view,
                connection: view.connections[i],
                l10n: l10n,
              ),
              const SizedBox(height: Space.s + 4),
            ],
          ],
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlternativesScreen(journeyId: journeyId),
                  ),
                ),
                icon: const Icon(Icons.alt_route),
                label: Text(l10n.seeAlternatives),
              ),
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
          const SizedBox(height: Space.l),
          TextButton.icon(
            onPressed: () => _confirmRemove(context, controller),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.removeJourney),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    AppController controller,
  ) async {
    final l10n = controller.l10n;
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.removeJourneyTitle),
        content: Text(l10n.removeJourneyBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await controller.removeJourney(journeyId);
      navigator.pop();
    }
  }
}
