import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railocity/app.dart';
import 'package:railocity/core/l10n.dart';
import 'package:railocity/data/local_store.dart';
import 'package:railocity/data/mock_railway_data_service.dart';
import 'package:railocity/logic/assistant/assistant_orchestrator.dart';
import 'package:railocity/state/app_controller.dart';

void main() {
  late MockRailwayDataService data;
  late AppController controller;

  setUp(() {
    data = MockRailwayDataService(latency: Duration.zero);
    controller = AppController(
      data: data,
      store: MemoryLocalStore(),
      assistant: const AssistantOrchestrator(),
      retryDelay: Duration.zero,
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(RailocityApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('first launch asks the passenger to add a journey', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Add your journey'), findsOneWidget);
    expect(find.text('Add a journey'), findsOneWidget);
    // The demo data is labelled on the first screen.
    expect(find.text('Demo data'), findsOneWidget);
    expect(find.textContaining('not live railway information'), findsOneWidget);
    // Five primary destinations.
    for (final label in [
      'Home',
      'My Journey',
      'Alerts',
      'Assistant',
      'Settings',
    ]) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('the demo journey flows from entry to a clear recommendation', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Add a journey'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use the demo journey'));
    await tester.pump();
    await tester.tap(find.text('Check journey'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Express (90101)'), findsOneWidget);
    expect(find.text('Demo Superfast (90202)'), findsOneWidget);

    await tester.tap(find.text('Save journey'));
    await tester.pumpAndSettle();

    // Home answers: what is happening, does it affect me, what next.
    expect(find.text('Your journey is on time'), findsOneWidget);
    expect(find.textContaining('No action is needed now'), findsOneWidget);
    expect(find.textContaining('Source: Demo data (simulated)'), findsWidgets);

    // A big delay turns the same screen into a recovery screen.
    await controller.applyDemo((d) => d.setDelay('90101', 90));
    await tester.pumpAndSettle();
    expect(find.text('You may miss your connection'), findsOneWidget);
    expect(find.text('See other trains'), findsOneWidget);
    expect(find.text('Official help'), findsOneWidget);
    expect(
      find.textContaining('Do not count on the train waiting'),
      findsOneWidget,
    );
    // Urgent alerts follow the recommendation. Scroll down to see them.
    await tester.scrollUntilVisible(find.text('Needs your action'), 200);
    expect(find.text('Needs your action'), findsOneWidget);
  });

  testWidgets('large text on a small phone does not overflow on any screen', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360 * 3, 640 * 3)
      ..devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await pumpApp(tester);
    await controller.addJourney(
      await controller.previewJourney(
        firstTrain: '90101',
        secondTrain: '90202',
      ),
    );
    await controller.applyDemo((d) => d.setDelay('90101', 90));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Home');
    // A new urgent alert shows a snack bar for a few seconds. Let it go, so
    // it does not cover the screens below.
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    Finder navItem(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

    for (final label in ['My Journey', 'Alerts', 'Assistant', 'Settings']) {
      await tester.tap(navItem(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }

    // Ask the assistant a question, so a full reply is on screen.
    await tester.tap(navItem('Assistant'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Will I make my connection?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Will I make my connection?'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Assistant reply');
    expect(controller.chat.last.reply, isNotNull);

    // Screens that are pushed on top. The buttons are at the end of the
    // reply, so scroll to them first, as a passenger would.
    await tester.ensureVisible(find.text('See other trains'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See other trains'));
    await tester.pumpAndSettle();
    expect(find.text('Other trains'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Other trains');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Official help'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Official help'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Official help'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Official help');
  });

  testWidgets('Hindi can be chosen, and numbers stay the same', (tester) async {
    await pumpApp(tester);
    await controller.addJourney(
      await controller.previewJourney(
        firstTrain: '90101',
        secondTrain: '90202',
      ),
    );
    await controller.applyDemo((d) => d.setDelay('90101', 90));
    await tester.pumpAndSettle();

    await controller.setLanguage(AppLanguage.hi);
    await tester.pumpAndSettle();

    expect(find.text('आपका कनेक्शन छूट सकता है'), findsOneWidget);
    expect(find.textContaining('90101'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a service failure shows a clear message and a way to retry', (
    tester,
  ) async {
    await pumpApp(tester);
    await controller.addJourney(
      await controller.previewJourney(
        firstTrain: '90101',
        secondTrain: '90202',
      ),
    );
    await tester.pumpAndSettle();

    await controller.applyDemo((d) => d.failing = true);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('We could not load the latest train status'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    // The last known status is still on screen. It is not hidden.
    expect(find.text('Your journey is on time'), findsOneWidget);
  });
}
