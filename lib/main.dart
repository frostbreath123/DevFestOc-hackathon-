import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'data/local_store.dart';
import 'data/mock_railway_data_service.dart';
import 'data/railway_data_service.dart';
import 'logic/assistant/ai_explainer.dart';
import 'logic/assistant/assistant_orchestrator.dart';
import 'state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();

  // Real railway data is not connected yet. Without demo data the app shows
  // clear errors. It never makes up train information.
  final RailwayDataService data = config.useDemoData
      ? MockRailwayDataService()
      : const UnconfiguredRailwayDataService();

  final endpoint = config.aiEndpoint;
  final controller = AppController(
    data: data,
    store: PreferencesLocalStore(),
    assistant: AssistantOrchestrator(
      ai: endpoint == null ? null : HttpAiExplainer(endpoint),
    ),
  );

  runApp(RailocityApp(controller: controller));
}
