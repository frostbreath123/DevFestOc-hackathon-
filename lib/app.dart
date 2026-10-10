import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';
import 'ui/shell/home_shell.dart';

/// The root widget. It gives every screen the controller and the theme.
class RailocityApp extends StatefulWidget {
  const RailocityApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<RailocityApp> createState() => _RailocityAppState();
}

class _RailocityAppState extends State<RailocityApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller
      ..init()
      ..startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.stopPolling();
    super.dispose();
  }

  /// Refresh when the passenger comes back to the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: widget.controller,
      child: MaterialApp(
        title: 'Railocity',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const HomeShell(),
      ),
    );
  }
}
