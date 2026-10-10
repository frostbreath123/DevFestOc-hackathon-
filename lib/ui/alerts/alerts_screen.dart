import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../state/app_scope.dart';
import '../widgets/alert_card.dart';
import '../widgets/common.dart';

/// Alerts, most urgent first. Alerts that need action come before updates.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final l10n = controller.l10n;
    final alerts = controller.alerts;
    final urgent = [
      for (final a in alerts)
        if (!a.read && a.needsAction) a,
    ];
    final others = [
      for (final a in alerts)
        if (a.read || !a.needsAction) a,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.alertsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.xl),
        children: [
          if (controller.data.isSimulated) ...[
            DemoBanner(l10n: l10n),
            const SizedBox(height: Space.s),
          ],
          // In the body, not the app bar, so a long label can wrap.
          if (controller.unreadAlertCount > 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: controller.markAllAlertsRead,
                icon: const Icon(Icons.done_all),
                label: Text(l10n.markAllRead),
              ),
            ),
          if (alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.l),
              child: Text(l10n.noAlerts, style: context.text.bodyLarge),
            ),
          if (urgent.isNotEmpty) ...[
            SectionTitle(l10n.needsYourAction),
            for (final alert in urgent) ...[
              AlertCard(
                key: ValueKey(alert.id),
                alert: alert,
                controller: controller,
              ),
              const SizedBox(height: Space.s + 4),
            ],
          ],
          if (others.isNotEmpty) ...[
            SectionTitle(l10n.otherUpdates),
            for (final alert in others) ...[
              AlertCard(
                key: ValueKey(alert.id),
                alert: alert,
                controller: controller,
              ),
              const SizedBox(height: Space.s + 4),
            ],
          ],
        ],
      ),
    );
  }
}
