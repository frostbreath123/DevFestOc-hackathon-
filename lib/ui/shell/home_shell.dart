import 'package:flutter/material.dart';

import '../../domain/alert.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../alerts/alerts_screen.dart';
import '../assistant/assistant_screen.dart';
import '../home/home_screen.dart';
import '../journey/my_journey_screen.dart';
import '../settings/settings_screen.dart';
import 'tabs.dart';

/// The main screen: five destinations in a Material 3 navigation bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _tab = AppTab.home;
  AppController? _controller;
  final Set<String> _announced = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.read(context);
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_onChanged);
      _controller = controller..addListener(_onChanged);
      // Alerts that already exist are not announced again.
      _announced.addAll(controller.alerts.map((a) => a.id));
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    super.dispose();
  }

  /// Tells the passenger about a new urgent alert, once, even when the
  /// passenger is on another screen.
  void _onChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final fresh = [
      for (final alert in controller.alerts)
        if (!alert.read &&
            alert.priority == AlertPriority.critical &&
            _announced.add(alert.id))
          alert,
    ];
    _announced.addAll(controller.alerts.map((a) => a.id));
    if (fresh.isEmpty || _tab == AppTab.alerts) return;
    final l10n = controller.l10n;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // A snack bar with an action stays on screen unless told otherwise.
          // This one goes away on its own and can be closed. The alert stays
          // in the Alerts tab.
          persist: false,
          showCloseIcon: true,
          duration: const Duration(seconds: 8),
          content: Text(l10n.alertTitle(fresh.first)),
          action: SnackBarAction(
            label: l10n.navAlerts,
            onPressed: () => setState(() => _tab = AppTab.alerts),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final l10n = controller.l10n;
    final unread = controller.unreadAlertCount;

    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          HomeScreen(onOpenTab: (tab) => setState(() => _tab = tab)),
          const MyJourneyScreen(),
          const AlertsScreen(),
          const AssistantScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => setState(() => _tab = AppTab.values[i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route),
            label: l10n.navJourney,
          ),
          NavigationDestination(
            icon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications),
            ),
            label: l10n.navAlerts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: l10n.navAssistant,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
