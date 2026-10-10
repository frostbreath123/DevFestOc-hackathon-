import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/mock_railway_data_service.dart';
import '../../domain/alert.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final l10n = controller.l10n;
    final prefs = controller.preferences;
    final demo = controller.demoService;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.xl),
        children: [
          if (controller.data.isSimulated) ...[
            DemoBanner(l10n: l10n),
            const SizedBox(height: Space.s),
          ],
          SectionTitle(l10n.languageSection),
          SegmentedButton<AppLanguage>(
            segments: [
              for (final language in AppLanguage.values)
                ButtonSegment(
                  value: language,
                  label: Text(language.nativeName),
                ),
            ],
            selected: {controller.language},
            onSelectionChanged: (selection) =>
                controller.setLanguage(selection.first),
          ),
          const SizedBox(height: Space.s),
          Text(l10n.translationNote, style: context.text.bodySmall),
          SectionTitle(l10n.notificationsSection),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.delayAlerts),
            value: prefs.delays,
            onChanged: (v) =>
                controller.setPreferences(prefs.copyWith(delays: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.platformAlerts),
            value: prefs.platformChanges,
            onChanged: (v) =>
                controller.setPreferences(prefs.copyWith(platformChanges: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.reminderAlerts),
            value: prefs.reminders,
            onChanged: (v) =>
                controller.setPreferences(prefs.copyWith(reminders: v)),
          ),
          const SizedBox(height: Space.s),
          Text(l10n.minDelay, style: context.text.bodyLarge),
          const SizedBox(height: Space.s),
          // Chips wrap onto a new line when the text size is large.
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final minutes in AlertPreferences.delayThresholdChoices)
                ChoiceChip(
                  label: Text(l10n.duration(minutes)),
                  selected: prefs.minDelayMinutes == minutes,
                  onSelected: (_) => controller.setPreferences(
                    prefs.copyWith(minDelayMinutes: minutes),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.s),
          Text(l10n.alwaysOn, style: context.text.bodySmall),
          SectionTitle(l10n.aboutDataSection),
          Text(
            l10n.dataSourceInfo(
              controller.data.sourceLabel,
              simulated: controller.data.isSimulated,
            ),
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: Space.s),
          Text(
            l10n.aiStatus(connected: controller.aiConnected),
            style: context.text.bodyMedium,
          ),
          if (demo != null) ..._demoControls(context, controller, demo),
        ],
      ),
    );
  }

  List<Widget> _demoControls(
    BuildContext context,
    AppController controller,
    MockRailwayDataService demo,
  ) {
    final l10n = controller.l10n;
    String minutes(int m) => l10n.duration(m);

    return [
      SectionTitle(l10n.demoControlsSection),
      Text(l10n.demoControlsBody, style: context.text.bodyMedium),
      const SizedBox(height: Space.s + 4),
      Wrap(
        spacing: Space.s,
        runSpacing: Space.s,
        children: [
          for (final delay in const [15, 30, 90])
            OutlinedButton(
              onPressed: () =>
                  controller.applyDemo((d) => d.setDelay('90101', delay)),
              child: Text('90101 +${minutes(delay)}'),
            ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Cancel train 90101'),
        value: demo.isCancelled('90101'),
        onChanged: (v) =>
            controller.applyDemo((d) => d.setCancelled('90101', cancelled: v)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Platform change for train 90202'),
        value: demo.platformChanged,
        onChanged: (v) => controller.applyDemo((d) => d.platformChanged = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Data is 25 minutes old'),
        value: demo.stale,
        onChanged: (v) => controller.applyDemo((d) => d.stale = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Data service is not reachable'),
        value: demo.failing,
        onChanged: (v) => controller.applyDemo((d) => d.failing = v),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => controller.applyDemo((d) => d.resetScenario()),
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset demo'),
        ),
      ),
    ];
  }
}
