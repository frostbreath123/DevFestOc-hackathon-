import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../domain/alert.dart';
import '../../domain/connection.dart';
import '../../domain/journey_view.dart';
import '../../domain/train_status.dart';
import '../../state/app_controller.dart';

/// Icon and colours for a status. Colour never carries the meaning alone.
class StatusStyle {
  const StatusStyle(this.icon, this.container, this.onContainer);

  final IconData icon;
  final Color container;
  final Color onContainer;
}

StatusStyle styleForHealth(BuildContext context, JourneyHealth health) {
  final c = context.colors;
  final s = context.statusColors;
  return switch (health) {
    JourneyHealth.onTrack => StatusStyle(
      Icons.check_circle_outline,
      s.success,
      s.onSuccess,
    ),
    JourneyHealth.delayed => StatusStyle(
      Icons.schedule,
      s.warning,
      s.onWarning,
    ),
    JourneyHealth.atRisk => StatusStyle(
      Icons.warning_amber_rounded,
      s.warning,
      s.onWarning,
    ),
    JourneyHealth.likelyMissed => StatusStyle(
      Icons.error_outline,
      c.errorContainer,
      c.onErrorContainer,
    ),
    JourneyHealth.cancelled => StatusStyle(
      Icons.cancel_outlined,
      c.errorContainer,
      c.onErrorContainer,
    ),
    JourneyHealth.unknown => StatusStyle(
      Icons.help_outline,
      c.surfaceContainerHighest,
      c.onSurface,
    ),
  };
}

StatusStyle styleForVerdict(BuildContext context, ConnectionVerdict verdict) =>
    styleForHealth(context, switch (verdict) {
      ConnectionVerdict.feasible => JourneyHealth.onTrack,
      ConnectionVerdict.atRisk => JourneyHealth.atRisk,
      ConnectionVerdict.likelyMissed => JourneyHealth.likelyMissed,
      ConnectionVerdict.cancelled => JourneyHealth.cancelled,
      ConnectionVerdict.unknown => JourneyHealth.unknown,
    });

/// A small label with an icon. Used for verdicts and data provenance.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    this.container,
    this.onContainer,
  });

  final IconData icon;
  final String label;
  final Color? container;
  final Color? onContainer;

  @override
  Widget build(BuildContext context) {
    final bg = container ?? context.colors.surfaceContainerHighest;
    final fg = onContainer ?? context.colors.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: context.text.labelLarge?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner that says the data is simulated. Shown on every main screen.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.l10n});

  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: context.colors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.science_outlined,
              color: context.colors.onSecondaryContainer,
            ),
            const SizedBox(width: Space.s + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.demoBannerTitle,
                    style: context.text.titleSmall?.copyWith(
                      color: context.colors.onSecondaryContainer,
                    ),
                  ),
                  Text(
                    l10n.demoBannerBody,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A message with a clear next step. Used for stale data and errors.
class NoticePanel extends StatelessWidget {
  const NoticePanel({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.error = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final bool error;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final bg = error
        ? context.colors.errorContainer
        : context.statusColors.warning;
    final fg = error
        ? context.colors.onErrorContainer
        : context.statusColors.onWarning;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: fg),
                const SizedBox(width: Space.s + 4),
                Expanded(
                  child: Text(
                    message,
                    style: context.text.bodyMedium?.copyWith(color: fg),
                  ),
                ),
              ],
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Space.s),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(foregroundColor: fg),
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Updated 14:05 (3 min ago) · Source: Demo data (simulated)".
class FreshnessLine extends StatelessWidget {
  const FreshnessLine({
    super.key,
    required this.updatedAt,
    required this.now,
    required this.source,
    required this.l10n,
    this.color,
  });

  final DateTime? updatedAt;
  final DateTime now;
  final String source;
  final L10n l10n;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.colors.onSurfaceVariant;
    final text = updatedAt == null
        ? l10n.noStatusYet
        : l10n.updatedLine(updatedAt!, now, source);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.update, size: 18, color: fg),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: context.text.bodySmall?.copyWith(color: fg)),
        ),
      ],
    );
  }
}

/// Stale-data and refresh-error banners for a journey, or nothing.
class DataStatusBanners extends StatelessWidget {
  const DataStatusBanners({
    super.key,
    required this.controller,
    required this.view,
  });

  final AppController controller;
  final JourneyView? view;

  @override
  Widget build(BuildContext context) {
    final l10n = controller.l10n;
    final children = <Widget>[];
    if (controller.lastRefreshFailed) {
      children.add(
        NoticePanel(
          icon: Icons.cloud_off,
          message: l10n.refreshFailed,
          actionLabel: l10n.retry,
          onAction: controller.refresh,
        ),
      );
    } else if (view != null &&
        view!.freshness == DataFreshness.stale &&
        view!.oldestUpdate != null) {
      children.add(
        NoticePanel(
          icon: Icons.history,
          message: l10n.staleBanner(view!.oldestUpdate!, controller.now),
          actionLabel: l10n.refresh,
          onAction: controller.refresh,
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Column(children: children),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: Space.l, bottom: Space.s),
        child: Text(text, style: context.text.titleMedium),
      ),
    );
  }
}

/// The two data badges used in alerts and replies.
class DataBadge extends StatelessWidget {
  const DataBadge({
    super.key,
    required this.origin,
    required this.source,
    required this.l10n,
  });

  final AlertOrigin origin;
  final DataSource source;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final demo = source == DataSource.demo;
    final label = origin == AlertOrigin.railwayData
        ? l10n.fromRailwayData
        : l10n.calculatedByRailocity;
    return StatusChip(
      icon: origin == AlertOrigin.railwayData
          ? Icons.verified_outlined
          : Icons.calculate_outlined,
      label: demo ? '$label · ${l10n.badgeDemo}' : label,
    );
  }
}
