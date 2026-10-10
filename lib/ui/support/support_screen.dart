import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../domain/support_rules.dart';
import '../../logic/assistant/fact_sheet.dart';
import '../../state/app_scope.dart';
import '../widgets/common.dart';

/// Opens an official page. Says so when it cannot, and shows the address.
Future<void> openOfficialLink(BuildContext context, Uri url, L10n l10n) async {
  var opened = false;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  } on Object {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.openFailed(url.toString()))));
  }
}

/// Official guidance after a disruption. Railocity does not act for the
/// passenger here. It explains and links.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final l10n = controller.l10n;
    final view = controller.activeView;
    final hint = view == null
        ? RefundHint.unknown
        : FactSheet(
            view: view,
            alternatives: const [],
            sourceLabel: controller.data.sourceLabel,
            simulated: controller.data.isSimulated,
            now: controller.now,
            refreshFailed: controller.lastRefreshFailed,
          ).refundHint;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.xl),
        children: [
          if (controller.data.isSimulated) ...[
            DemoBanner(l10n: l10n),
            const SizedBox(height: Space.m),
          ],
          DataStatusBanners(controller: controller, view: view),
          SectionTitle(l10n.supportYourSituation),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.refundHint(hint), style: context.text.bodyLarge),
                  const SizedBox(height: Space.s + 4),
                  StatusChip(
                    icon: Icons.calculate_outlined,
                    label: l10n.calculatedByRailocity,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          NoticePanel(
            icon: Icons.info_outline,
            message: '${l10n.supportLimits} ${l10n.supportVerify}',
          ),
          SectionTitle(l10n.supportSources),
          for (final resource in SupportRules.resources) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.resourceTitle(resource),
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      l10n.resourceUseFor(resource),
                      style: context.text.bodyMedium,
                    ),
                    if (resource.phone != null) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        l10n.helpline(resource.phone!),
                        style: context.text.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: Space.s + 4),
                    Wrap(
                      spacing: Space.s,
                      runSpacing: Space.s,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              openOfficialLink(context, resource.url, l10n),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(l10n.openLink),
                        ),
                        if (resource.phone != null)
                          OutlinedButton.icon(
                            onPressed: () => openOfficialLink(
                              context,
                              Uri(scheme: 'tel', path: resource.phone),
                              l10n,
                            ),
                            icon: const Icon(Icons.call),
                            label: Text(resource.phone!),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.s),
                    Text(
                      resource.url.toString(),
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.s + 4),
          ],
        ],
      ),
    );
  }
}
