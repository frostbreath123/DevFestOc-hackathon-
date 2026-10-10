import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/clock.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../domain/connection.dart';
import '../../domain/journey_view.dart';
import '../../domain/train_status.dart';
import '../../logic/assistant/fact_sheet.dart';
import 'common.dart';

/// One train of a journey: name, status, times and platform.
class LegCard extends StatelessWidget {
  const LegCard({
    super.key,
    required this.view,
    required this.index,
    required this.l10n,
  });

  final JourneyView view;
  final int index;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final leg = view.journey.legs[index];
    final schedule = view.schedules[index];
    final status = view.statuses[index];
    final title = schedule?.displayName ?? leg.trainNumber;
    final delay = status == null ? 0 : math.max(0, status.delayMinutes);

    final departure = schedule?.stopAt(leg.boardCode)?.scheduledDeparture;
    final arrival = schedule?.stopAt(leg.alightCode)?.scheduledArrival;
    final platform = status?.platforms[leg.boardCode];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.text.titleMedium),
            const SizedBox(height: Space.s),
            _TrainStatusChip(status: status, l10n: l10n),
            const SizedBox(height: Space.s + 4),
            if (departure != null)
              _TimeLine(
                station: view.stationName(leg.boardCode),
                scheduled: departure,
                expected: departure.add(Duration(minutes: delay)),
                showExpected: status != null && !status.cancelled,
                l10n: l10n,
              ),
            if (arrival != null) ...[
              const SizedBox(height: Space.s),
              _TimeLine(
                station: view.stationName(leg.alightCode),
                scheduled: arrival,
                expected: arrival.add(
                  Duration(minutes: status?.delayMinutes ?? 0),
                ),
                showExpected: status != null && !status.cancelled,
                l10n: l10n,
              ),
            ],
            if (status != null && !status.cancelled) ...[
              const SizedBox(height: Space.s + 4),
              Text(
                platform == null
                    ? '${l10n.platformLabel}: ${l10n.platformUnknown}'
                    : '${l10n.platformLabel} $platform · ${view.stationName(leg.boardCode)}',
                style: context.text.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrainStatusChip extends StatelessWidget {
  const _TrainStatusChip({required this.status, required this.l10n});

  final TrainStatus? status;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null) {
      final style = styleForHealth(context, JourneyHealth.unknown);
      return StatusChip(
        icon: style.icon,
        label: l10n.statusUnknown,
        container: style.container,
        onContainer: style.onContainer,
      );
    }
    if (s.cancelled) {
      final style = styleForHealth(context, JourneyHealth.cancelled);
      return StatusChip(
        icon: style.icon,
        label: l10n.cancelledLabel,
        container: style.container,
        onContainer: style.onContainer,
      );
    }
    if (s.delayMinutes < 5) {
      final style = styleForHealth(context, JourneyHealth.onTrack);
      return StatusChip(
        icon: style.icon,
        label: l10n.onTime,
        container: style.container,
        onContainer: style.onContainer,
      );
    }
    final style = styleForHealth(context, JourneyHealth.delayed);
    return StatusChip(
      icon: style.icon,
      label: l10n.delayedBy(s.delayMinutes),
      container: style.container,
      onContainer: style.onContainer,
    );
  }
}

class _TimeLine extends StatelessWidget {
  const _TimeLine({
    required this.station,
    required this.scheduled,
    required this.expected,
    required this.showExpected,
    required this.l10n,
  });

  final String station;
  final DateTime scheduled;
  final DateTime expected;
  final bool showExpected;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final changed = showExpected && expected != scheduled;
    final shownTime = formatClockWithDay(
      changed ? expected : scheduled,
      scheduled,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(station, style: context.text.bodyLarge)),
        const SizedBox(width: Space.s),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(shownTime, style: context.text.titleMedium),
            if (changed)
              Text(
                '${l10n.scheduled} ${formatClock(scheduled)}',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The result of one connection check, in words and numbers.
class ConnectionCard extends StatelessWidget {
  const ConnectionCard({
    super.key,
    required this.view,
    required this.connection,
    required this.l10n,
  });

  final JourneyView view;
  final ConnectionAssessment connection;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final style = styleForVerdict(context, connection.verdict);
    final station = view.stationName(connection.stationCode);
    final names = JourneyNames(view);
    final window = connection.windowMinutes;
    final slack = connection.slackMinutes;

    return Card(
      color: style.container,
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.transfer_within_a_station, color: style.onContainer),
                const SizedBox(width: Space.s + 4),
                Expanded(
                  child: Text(
                    l10n.changeAt(station),
                    style: context.text.titleMedium?.copyWith(
                      color: style.onContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.s + 4),
            StatusChip(
              icon: style.icon,
              label: l10n.verdictLabel(connection.verdict),
              container: context.colors.surface,
              onContainer: context.colors.onSurface,
            ),
            const SizedBox(height: Space.s + 4),
            Text(
              l10n.connectionDetail(connection, names: names),
              style: context.text.bodyLarge?.copyWith(color: style.onContainer),
            ),
            if (window != null) ...[
              const SizedBox(height: Space.m),
              _NumberRow(
                label: l10n.timeBetweenTrains,
                value: window >= 0
                    ? l10n.duration(window)
                    : '−${l10n.duration(window)}',
                color: style.onContainer,
              ),
              _NumberRow(
                label: l10n.timeToChange,
                value: connection.transferMinutes == null
                    ? l10n.notKnown
                    : l10n.duration(connection.transferMinutes!),
                color: style.onContainer,
              ),
              if (slack != null)
                _NumberRow(
                  label: l10n.spareTime,
                  value: slack >= 0
                      ? l10n.duration(slack)
                      : '−${l10n.duration(slack)}',
                  color: style.onContainer,
                ),
            ],
            const SizedBox(height: Space.s),
            Text(
              l10n.calculatedByRailocity,
              style: context.text.bodySmall?.copyWith(color: style.onContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.bodyMedium?.copyWith(color: color),
            ),
          ),
          Text(value, style: context.text.titleSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}
