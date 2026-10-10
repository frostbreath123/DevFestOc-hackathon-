import 'package:flutter/material.dart';

import '../../core/clock.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../domain/alert.dart';
import '../../state/app_controller.dart';
import 'common.dart';

IconData _iconFor(RailAlert alert) => switch (alert.type) {
  AlertType.cancellation => Icons.cancel_outlined,
  AlertType.connectionRisk => Icons.warning_amber_rounded,
  AlertType.platformChange => Icons.sync_alt,
  AlertType.delay => Icons.schedule,
  AlertType.boardingReminder => Icons.notifications_none,
};

/// One alert. Shows what changed, what it means and where the data came from.
class AlertCard extends StatefulWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.controller,
    this.showActions = true,
  });

  final RailAlert alert;
  final AppController controller;
  final bool showActions;

  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard> {
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final alert = widget.alert;
    final shown = controller.l10n;
    final canShowOriginal = !shown.isEnglish;
    final l10n = _showOriginal ? const L10n(AppLanguage.en) : shown;

    final Color background;
    final Color foreground;
    switch (alert.priority) {
      case AlertPriority.critical:
        background = context.colors.errorContainer;
        foreground = context.colors.onErrorContainer;
      case AlertPriority.high:
        background = context.statusColors.warning;
        foreground = context.statusColors.onWarning;
      case AlertPriority.medium:
      case AlertPriority.low:
        background = context.colors.surfaceContainerLow;
        foreground = context.colors.onSurface;
    }

    final title = l10n.alertTitle(alert);
    final body = l10n.alertBody(alert);

    return Semantics(
      container: true,
      label: '${alert.read ? '' : '${shown.unreadLabel}. '}$title. $body',
      child: Card(
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_iconFor(alert), color: foreground),
                    const SizedBox(width: Space.s + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: context.text.titleMedium?.copyWith(
                              color: foreground,
                              fontWeight: alert.read
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            body,
                            style: context.text.bodyMedium?.copyWith(
                              color: foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.s + 4),
              ExcludeSemantics(
                child: Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    DataBadge(
                      origin: alert.origin,
                      source: alert.source,
                      l10n: shown,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.s),
              FreshnessLine(
                updatedAt: alert.dataUpdatedAt,
                now: controller.now,
                source: controller.data.sourceLabel,
                l10n: shown,
                color: foreground,
              ),
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  formatClock(alert.createdAt),
                  style: context.text.bodySmall?.copyWith(color: foreground),
                ),
              ),
              if (widget.showActions && (!alert.read || canShowOriginal))
                Wrap(
                  spacing: Space.s,
                  children: [
                    if (!alert.read)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: foreground,
                        ),
                        onPressed: () => controller.markAlertRead(alert.id),
                        child: Text(shown.markRead),
                      ),
                    if (canShowOriginal)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: foreground,
                        ),
                        onPressed: () =>
                            setState(() => _showOriginal = !_showOriginal),
                        child: Text(
                          _showOriginal
                              ? shown.showTranslation
                              : shown.showOriginal,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
