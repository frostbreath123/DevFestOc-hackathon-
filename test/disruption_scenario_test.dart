// End-to-end check of the "definition of done" scenario, without the UI:
// a passenger saves a connecting journey, a delay arrives, the connection is
// recalculated, the assistant explains it, and failures fall back safely.
import 'package:flutter_test/flutter_test.dart';
import 'package:railocity/core/l10n.dart';
import 'package:railocity/data/local_store.dart';
import 'package:railocity/data/mock_railway_data_service.dart';
import 'package:railocity/domain/alert.dart';
import 'package:railocity/domain/connection.dart';
import 'package:railocity/domain/journey_view.dart';
import 'package:railocity/logic/assistant/assistant_models.dart';
import 'package:railocity/logic/assistant/assistant_orchestrator.dart';
import 'package:railocity/state/app_controller.dart';

import 'support/fixtures.dart';

void main() {
  late DateTime now;
  late MockRailwayDataService data;
  late MemoryLocalStore store;
  late AppController controller;

  AppController build() => AppController(
    data: data,
    store: store,
    assistant: const AssistantOrchestrator(),
    clock: () => now,
    retryDelay: Duration.zero,
  );

  setUp(() {
    now = t0;
    data = MockRailwayDataService(clock: () => now, latency: Duration.zero);
    store = MemoryLocalStore();
    controller = build();
  });

  Future<void> saveDemoJourney() async {
    final preview = await controller.previewJourney(
      firstTrain: '90101',
      secondTrain: '90202',
    );
    await controller.addJourney(preview);
  }

  test(
    '1-2. a passenger saves a connecting journey and sees its status',
    () async {
      final preview = await controller.previewJourney(
        firstTrain: '90101',
        secondTrain: '90202',
      );
      expect(preview.journey.legs, hasLength(2));
      expect(preview.journey.legs.first.alightCode, 'CRJ');
      expect(preview.journey.legs.last.boardCode, 'CRJ');
      expect(preview.journey.destinationCode, 'LKV');

      await controller.addJourney(preview);
      final view = controller.activeView!;
      expect(view.health, JourneyHealth.onTrack);
      expect(view.connections.single.verdict, ConnectionVerdict.feasible);
      expect(view.connections.single.windowMinutes, 35);
      expect(view.oldestUpdate, now);
      expect(view.freshness, DataFreshness.fresh);
      expect(controller.alerts, isEmpty);
      expect(controller.refreshState, RefreshState.succeeded);
    },
  );

  test(
    '3-6. a delay triggers alerts, a recalculation, options and help',
    () async {
      await saveDemoJourney();

      // 3. A delay arrives.
      now = now.add(const Duration(minutes: 5));
      await controller.applyDemo((d) => d.setDelay('90101', 90));

      // 4. The connection window is recalculated.
      final view = controller.activeView!;
      expect(view.health, JourneyHealth.likelyMissed);
      final connection = view.connections.single;
      expect(connection.verdict, ConnectionVerdict.likelyMissed);
      expect(connection.expectedArrival, at(170)); // 80 + 90
      expect(connection.windowMinutes, -55);

      // 3. ...and creates relevant alerts, most urgent first.
      final alerts = controller.alerts;
      expect(alerts.first.type, AlertType.connectionRisk);
      expect(alerts.first.priority, AlertPriority.critical);
      expect(
        alerts.map((a) => a.type),
        containsAll([AlertType.connectionRisk, AlertType.delay]),
      );
      expect(controller.unreadAlertCount, alerts.length);

      // 5. The passenger can look at realistic alternatives.
      final result = await controller.loadAlternatives(view.journey);
      expect(result.failed, isFalse);
      // The passenger is ready at 14:50 + 15 min = 15:05 (at(185)). Only train
      // 90305 (at(330)) can still be caught. 90203 (at(175)) and 90406
      // (at(150)) leave too early. 90202 is the missed train.
      final numbers = result.options.map((o) => o.train.number).toList();
      expect(numbers, ['90305']);
      expect(result.options.single.verdict, ConnectionVerdict.feasible);
      expect(result.options.single.statusKnown, isTrue);

      // 5. The assistant explains the impact in simple language.
      await controller.askAssistant('Will I make my connection?');
      final reply = controller.chat.last.reply!;
      final text = reply.sections.expand((s) => s.lines).join('\n');
      expect(text, contains('about 1 h 30 min late'));
      expect(text, contains('Do not count on the train waiting.'));
      expect(reply.suggestAlternatives, isTrue);
      expect(reply.suggestSupport, isTrue);
      // Labelled as demo data, so it can not pass as live information.
      final verified = reply.sections.firstWhere(
        (s) => s.provenance == Provenance.verified,
      );
      expect(verified.simulated, isTrue);
      expect(verified.source, contains('simulated'));
      // No AI is connected, and the reply says so.
      expect(reply.notices, contains(AssistantNotice.aiOff));
    },
  );

  test(
    'a smaller delay leaves a tight option and a safe one, best first',
    () async {
      await saveDemoJourney();
      await controller.applyDemo((d) => d.setDelay('90101', 55));

      // Ready at 13:20 + 55 min + 15 min = 14:30 (at(150)).
      final result = await controller.loadAlternatives(
        controller.journeys.first,
      );
      final options = result.options;
      expect(options.map((o) => o.train.number), ['90203', '90305', '90406']);
      expect(options.map((o) => o.verdict), [
        ConnectionVerdict.feasible,
        ConnectionVerdict.feasible,
        ConnectionVerdict.atRisk, // leaves exactly when the passenger is ready
      ]);
    },
  );

  test(
    'a cancellation creates one critical alert and keeps options open',
    () async {
      await saveDemoJourney();
      await controller.applyDemo(
        (d) => d.setCancelled('90101', cancelled: true),
      );

      expect(controller.activeView!.health, JourneyHealth.cancelled);
      final cancellations = controller.alerts.where(
        (a) => a.type == AlertType.cancellation,
      );
      expect(cancellations, hasLength(1));
      expect(cancellations.single.priority, AlertPriority.critical);

      // A second refresh must not repeat the alert.
      await controller.refresh();
      expect(
        controller.alerts.where((a) => a.type == AlertType.cancellation),
        hasLength(1),
      );

      // The passenger starts again from the origin: trains from MRC to LKV do
      // not exist in the demo data, so the result is empty, not made up.
      final result = await controller.loadAlternatives(
        controller.journeys.first,
      );
      expect(result.failed, isFalse);
      expect(result.options, isEmpty);
    },
  );

  test('a platform change creates a high priority alert', () async {
    await saveDemoJourney();
    now = at(60);
    await controller.applyDemo((d) => d.platformChanged = true);
    final change = controller.alerts.firstWhere(
      (a) => a.type == AlertType.platformChange,
    );
    expect(change.platform, '8');
    expect(change.previousPlatform, '5');
    expect(change.priority, AlertPriority.high);
  });

  test(
    '7. when the data service fails, old data stays and is marked old',
    () async {
      await saveDemoJourney();
      expect(controller.lastRefreshFailed, isFalse);

      now = now.add(const Duration(minutes: 30));
      await controller.applyDemo((d) => d.failing = true);

      expect(controller.lastRefreshFailed, isTrue);
      expect(controller.refreshState, RefreshState.failed);
      final view = controller.activeView!;
      // The last known status is kept, not replaced by made-up data.
      expect(view.statuses.every((s) => s != null), isTrue);
      expect(view.oldestUpdate, t0);
      expect(view.freshness, DataFreshness.stale);

      // The assistant still answers from saved data, and says it may be old.
      await controller.askAssistant('How is my train?');
      final reply = controller.chat.last.reply!;
      expect(reply.notices, contains(AssistantNotice.dataProblem));

      // Recovery.
      await controller.applyDemo((d) => d.failing = false);
      expect(controller.lastRefreshFailed, isFalse);
      expect(controller.activeView!.freshness, DataFreshness.fresh);
    },
  );

  test('old data from the source is shown as stale', () async {
    await saveDemoJourney();
    await controller.applyDemo((d) => d.stale = true);
    final view = controller.activeView!;
    expect(view.freshness, DataFreshness.stale);
    expect(now.difference(view.oldestUpdate!).inMinutes, 25);
  });

  test('journey and last status are saved for offline use', () async {
    await saveDemoJourney();
    await controller.applyDemo((d) => d.setDelay('90101', 30));
    await controller.setLanguage(AppLanguage.hi);

    final restored = build();
    // Offline: no data service answers.
    data.failing = true;
    await restored.init();

    expect(restored.language, AppLanguage.hi);
    expect(restored.journeys, hasLength(1));
    expect(restored.alerts, isNotEmpty);
    final view = restored.activeView!;
    expect(view.statuses.first!.delayMinutes, 30);
    expect(view.originName, 'Meridian Central');
    expect(restored.lastRefreshFailed, isTrue);
  });

  group('adding a journey', () {
    Future<AddJourneyProblem> problemOf(String first, [String? second]) async {
      try {
        await controller.previewJourney(firstTrain: first, secondTrain: second);
      } on AddJourneyException catch (e) {
        return e.problem;
      }
      fail('Expected an AddJourneyException');
    }

    test('rejects a number that is not 5 digits', () async {
      expect(await problemOf('123'), AddJourneyProblem.invalidNumber);
      expect(await problemOf('90101', 'abc'), AddJourneyProblem.invalidNumber);
    });

    test('does not invent a train that the provider does not know', () async {
      expect(await problemOf('99999'), AddJourneyProblem.notFound);
    });

    test('rejects two trains that do not meet in the right order', () async {
      expect(await problemOf('90202', '90101'), AddJourneyProblem.doNotMeet);
    });

    test('reports an unreachable service', () async {
      data.failing = true;
      expect(await problemOf('90101'), AddJourneyProblem.unavailable);
    });

    test('accepts a single train', () async {
      final preview = await controller.previewJourney(firstTrain: '90202');
      expect(preview.journey.legs, hasLength(1));
      await controller.addJourney(preview);
      expect(controller.activeView!.connections, isEmpty);
      expect(controller.activeView!.health, JourneyHealth.onTrack);
    });
  });

  test('removing a journey removes its alerts', () async {
    await saveDemoJourney();
    await controller.applyDemo((d) => d.setCancelled('90101', cancelled: true));
    expect(controller.alerts, isNotEmpty);

    await controller.removeJourney(controller.journeys.first.id);
    expect(controller.journeys, isEmpty);
    expect(controller.alerts, isEmpty);
    expect(controller.activeView, isNull);
  });

  test('changing language clears old answers', () async {
    await saveDemoJourney();
    await controller.askAssistant('hello');
    expect(controller.chat, isNotEmpty);
    await controller.setLanguage(AppLanguage.hi);
    expect(controller.chat, isEmpty);
  });
}
