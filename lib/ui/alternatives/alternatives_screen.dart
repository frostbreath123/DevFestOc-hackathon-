import 'package:flutter/material.dart';

import '../../core/clock.dart';
import '../../core/theme.dart';
import '../../domain/alternative.dart';
import '../../domain/support_rules.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../support/support_screen.dart';
import '../widgets/common.dart';

/// Later trains the passenger could use. This is not a booking.
class AlternativesScreen extends StatefulWidget {
  const AlternativesScreen({super.key, required this.journeyId});

  final String journeyId;

  @override
  State<AlternativesScreen> createState() => _AlternativesScreenState();
}

class _AlternativesScreenState extends State<AlternativesScreen> {
  Future<AlternativesResult>? _future;

  void _load() {
    final controller = AppScope.read(context);
    final matches = controller.journeys.where((j) => j.id == widget.journeyId);
    if (matches.isEmpty) return;
    _future = controller.loadAlternatives(matches.first);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final l10n = controller.l10n;
    final matches = controller.journeys.where((j) => j.id == widget.journeyId);
    final view = matches.isEmpty ? null : controller.viewOf(matches.first);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.alternativesTitle),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_load),
          ),
        ],
      ),
      body: view == null || _future == null
          ? Padding(
              padding: const EdgeInsets.all(Space.m),
              child: Text(l10n.noJourneys),
            )
          : FutureBuilder<AlternativesResult>(
              future: _future,
              builder: (context, snapshot) {
                final children = <Widget>[
                  if (controller.data.isSimulated) ...[
                    DemoBanner(l10n: l10n),
                    const SizedBox(height: Space.m),
                  ],
                ];
                if (snapshot.connectionState != ConnectionState.done) {
                  children.add(
                    Semantics(
                      liveRegion: true,
                      label: l10n.refreshing,
                      child: const LinearProgressIndicator(),
                    ),
                  );
                } else if (snapshot.hasError ||
                    (snapshot.data?.failed ?? true)) {
                  children.add(
                    NoticePanel(
                      error: true,
                      icon: Icons.cloud_off,
                      message: l10n.refreshFailed,
                      actionLabel: l10n.retry,
                      onAction: () => setState(_load),
                    ),
                  );
                } else {
                  final options = snapshot.data!.options;
                  children.add(
                    Text(
                      l10n.alternativesBasis,
                      style: context.text.bodyMedium,
                    ),
                  );
                  children.add(const SizedBox(height: Space.m));
                  if (options.isEmpty) {
                    children.add(
                      Text(l10n.noAlternatives, style: context.text.bodyLarge),
                    );
                  }
                  for (final option in options) {
                    children
                      ..add(
                        _OptionCard(
                          option: option,
                          controller: controller,
                          destinationName: view.destinationName,
                        ),
                      )
                      ..add(const SizedBox(height: Space.s + 4));
                  }
                }
                children
                  ..add(const SizedBox(height: Space.s))
                  ..add(
                    NoticePanel(
                      message: l10n.alternativesNote,
                      icon: Icons.info_outline,
                    ),
                  )
                  ..add(const SizedBox(height: Space.s))
                  ..add(
                    Wrap(
                      spacing: Space.s,
                      children: [
                        OutlinedButton(
                          onPressed: () => openOfficialLink(
                            context,
                            SupportRules.resource('irctc').url,
                            l10n,
                          ),
                          child: Text(l10n.checkAvailability),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SupportScreen(),
                            ),
                          ),
                          child: Text(l10n.officialHelp),
                        ),
                      ],
                    ),
                  );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.m,
                    Space.s,
                    Space.m,
                    Space.xl,
                  ),
                  children: children,
                );
              },
            ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.controller,
    required this.destinationName,
  });

  final AlternativeOption option;
  final AppController controller;
  final String destinationName;

  @override
  Widget build(BuildContext context) {
    final l10n = controller.l10n;
    final style = styleForVerdict(context, option.verdict);
    final fromName =
        option.train.stopAt(option.fromCode)?.station.name ?? option.fromCode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(option.train.displayName, style: context.text.titleMedium),
            const SizedBox(height: Space.s),
            StatusChip(
              icon: style.icon,
              label: l10n.verdictLabel(option.verdict),
              container: style.container,
              onContainer: style.onContainer,
            ),
            const SizedBox(height: Space.s + 4),
            Text(
              l10n.leavesAt(fromName, formatClock(option.departure)),
              style: context.text.bodyLarge,
            ),
            Text(
              l10n.arrivesAt(
                destinationName,
                formatClockWithDay(option.arrival, option.departure),
              ),
              style: context.text.bodyLarge,
            ),
            Text(
              '${l10n.journeyTime}: ${l10n.duration(option.durationMinutes)}',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: Space.s + 4),
            if (option.statusKnown)
              FreshnessLine(
                updatedAt: option.dataUpdatedAt,
                now: controller.now,
                source: controller.data.sourceLabel,
                l10n: l10n,
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.timetableOnly,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
