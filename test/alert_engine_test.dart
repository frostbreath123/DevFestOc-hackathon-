import 'package:flutter_test/flutter_test.dart';
import 'package:railocity/domain/alert.dart';
import 'package:railocity/domain/connection.dart';
import 'package:railocity/domain/journey_view.dart';
import 'package:railocity/domain/train_status.dart';
import 'package:railocity/logic/alert_engine.dart';

import 'support/fixtures.dart';

void main() {
  const engine = AlertEngine();

  JourneyView view(
    DateTime now, {
    int firstDelay = 0,
    int secondDelay = 0,
    bool firstCancelled = false,
    String secondPlatform = '5',
  }) => viewWith(
    now: now,
    first: statusOf(
      '90101',
      delay: firstDelay,
      cancelled: firstCancelled,
      platforms: {'CRJ': '3'},
      updatedAt: now,
    ),
    second: statusOf(
      '90202',
      delay: secondDelay,
      platforms: {'CRJ': secondPlatform},
      updatedAt: now,
    ),
  );

  List<RailAlert> generate({
    required JourneyView current,
    JourneyView? previous,
    AlertPreferences preferences = const AlertPreferences(),
    List<RailAlert> existing = const [],
    required DateTime now,
  }) => engine.generate(
    current: current,
    previous: previous,
    preferences: preferences,
    existing: existing,
    now: now,
  );

  Iterable<AlertType> types(List<RailAlert> alerts) =>
      alerts.map((a) => a.type);

  test('a journey on time creates no alerts', () {
    final now = at(10);
    expect(generate(current: view(now), now: now), isEmpty);
  });

  group('delays', () {
    test(
      'a 90 min delay creates a delay alert and a missed-connection alert',
      () {
        final before = at(10);
        final now = at(20);
        final alerts = generate(
          current: view(now, firstDelay: 90),
          previous: view(before),
          now: now,
        );
        expect(
          types(alerts),
          containsAll([AlertType.delay, AlertType.connectionRisk]),
        );
        final risk = alerts.firstWhere(
          (a) => a.type == AlertType.connectionRisk,
        );
        expect(risk.verdict, ConnectionVerdict.likelyMissed);
        expect(risk.priority, AlertPriority.critical);
        final delay = alerts.firstWhere((a) => a.type == AlertType.delay);
        expect(delay.delayMinutes, 90);
        expect(delay.priority, AlertPriority.high);
        expect(delay.verdict, ConnectionVerdict.likelyMissed);
      },
    );

    test('the same disruption is not alerted twice', () {
      final now = at(20);
      final first = generate(
        current: view(now, firstDelay: 90),
        previous: view(at(10)),
        now: now,
      );
      final again = generate(
        current: view(at(25), firstDelay: 90),
        previous: view(now, firstDelay: 90),
        existing: first,
        now: at(25),
      );
      expect(again, isEmpty);
    });

    test('a delay below the passenger threshold is ignored', () {
      final now = at(20);
      final alerts = generate(
        current: view(now, firstDelay: 12),
        previous: view(at(10)),
        preferences: const AlertPreferences(minDelayMinutes: 30),
        now: now,
      );
      expect(types(alerts), isNot(contains(AlertType.delay)));
    });

    test('a delay that grows by under 10 min does not repeat the alert', () {
      final now = at(30);
      final alerts = generate(
        current: view(now, firstDelay: 25),
        previous: view(at(20), firstDelay: 20),
        now: now,
      );
      expect(types(alerts), isNot(contains(AlertType.delay)));
    });

    test('delay alerts can be switched off, connection alerts cannot', () {
      final now = at(20);
      final alerts = generate(
        current: view(now, firstDelay: 90),
        previous: view(at(10)),
        preferences: const AlertPreferences(delays: false),
        now: now,
      );
      expect(types(alerts), [AlertType.connectionRisk]);
    });

    test('a delay with a safe connection says so and is medium priority', () {
      final now = at(20);
      // 15 min late: window 20, slack 5 -> at risk. Use a train 2 delay to
      // keep the connection safe: window 35, slack 20.
      final alerts = generate(
        current: view(now, firstDelay: 20, secondDelay: 20),
        previous: view(at(10)),
        now: now,
      );
      final delays = alerts.where((a) => a.type == AlertType.delay).toList();
      expect(delays, isNotEmpty);
      expect(delays.first.verdict, ConnectionVerdict.feasible);
      expect(delays.first.priority, AlertPriority.medium);
      expect(types(alerts), isNot(contains(AlertType.connectionRisk)));
    });
  });

  group('connection risk', () {
    test('"at risk" is high priority', () {
      final now = at(20);
      final alerts = generate(
        current: view(now, firstDelay: 15),
        previous: view(at(10)),
        now: now,
      );
      final risk = alerts.firstWhere((a) => a.type == AlertType.connectionRisk);
      expect(risk.verdict, ConnectionVerdict.atRisk);
      expect(risk.priority, AlertPriority.high);
    });

    test('no alert when the verdict did not change', () {
      final now = at(25);
      final alerts = generate(
        current: view(now, firstDelay: 90),
        previous: view(at(20), firstDelay: 90),
        now: now,
      );
      expect(types(alerts), isNot(contains(AlertType.connectionRisk)));
    });

    test('no connection alert when the data is unavailable', () {
      final now = at(20);
      final current = viewWith(
        now: now,
        first: statusOf('90101', delay: 90, updatedAt: now),
      );
      final alerts = generate(current: current, now: now);
      expect(types(alerts), isNot(contains(AlertType.connectionRisk)));
    });
  });

  group('cancellation', () {
    test('a cancelled train creates one critical alert', () {
      final now = at(20);
      final alerts = generate(
        current: view(now, firstCancelled: true),
        previous: view(at(10)),
        now: now,
      );
      expect(types(alerts), [AlertType.cancellation]);
      expect(alerts.single.priority, AlertPriority.critical);
      expect(alerts.single.trainNumber, '90101');
    });

    test('cancellation alerts stay on when all optional alerts are off', () {
      final now = at(20);
      final alerts = generate(
        current: view(now, firstCancelled: true),
        previous: view(at(10)),
        preferences: const AlertPreferences(
          delays: false,
          platformChanges: false,
          reminders: false,
        ),
        now: now,
      );
      expect(types(alerts), [AlertType.cancellation]);
    });
  });

  group('platform change', () {
    test('a change close to departure is high priority', () {
      final now = at(60); // train 2 leaves at +115: 55 min away
      final alerts = generate(
        current: view(now, secondPlatform: '8'),
        previous: view(at(50)),
        now: now,
      );
      final change = alerts.firstWhere(
        (a) => a.type == AlertType.platformChange,
      );
      expect(change.platform, '8');
      expect(change.previousPlatform, '5');
      expect(change.stationName, 'Crossroads Junction');
      expect(change.trainNumber, '90202');
      expect(change.priority, AlertPriority.high);
    });

    test('a change far from departure is medium priority', () {
      final now = at(10); // 105 min before departure
      final alerts = generate(
        current: view(now, secondPlatform: '8'),
        previous: view(at(5)),
        now: now,
      );
      final change = alerts.firstWhere(
        (a) => a.type == AlertType.platformChange,
      );
      expect(change.priority, AlertPriority.medium);
    });

    test('no alert on the first load, when no earlier platform is known', () {
      final now = at(60);
      final alerts = generate(
        current: view(now, secondPlatform: '8'),
        now: now,
      );
      expect(types(alerts), isNot(contains(AlertType.platformChange)));
    });

    test('can be switched off', () {
      final now = at(60);
      final alerts = generate(
        current: view(now, secondPlatform: '8'),
        previous: view(at(50)),
        preferences: const AlertPreferences(platformChanges: false),
        now: now,
      );
      expect(types(alerts), isNot(contains(AlertType.platformChange)));
    });
  });

  group('boarding reminder', () {
    test('appears within 60 min of departure, once', () {
      final now = at(70); // train 2 leaves in 45 min
      final first = generate(
        current: view(now),
        previous: view(at(60)),
        now: now,
      );
      final reminder = first.firstWhere(
        (a) => a.type == AlertType.boardingReminder,
      );
      expect(reminder.priority, AlertPriority.low);
      expect(reminder.trainNumber, '90202');
      expect(reminder.platform, '5');
      expect(reminder.eventTime, at(115));

      final again = generate(
        current: view(at(75)),
        previous: view(now),
        existing: first,
        now: at(75),
      );
      expect(types(again), isNot(contains(AlertType.boardingReminder)));
    });

    test('does not appear more than 60 min before departure', () {
      final now = at(40); // 75 min before departure
      final alerts = generate(
        current: view(now),
        previous: view(at(30)),
        now: now,
      );
      expect(types(alerts), isNot(contains(AlertType.boardingReminder)));
    });
  });

  group('sorting', () {
    test('critical first, then newest first within a priority', () {
      RailAlert alert(String id, AlertPriority p, int minute) => RailAlert(
        id: id,
        key: id,
        type: AlertType.delay,
        priority: p,
        origin: AlertOrigin.railwayData,
        journeyId: 'j1',
        trainNumber: '90101',
        trainName: 'Demo Express',
        createdAt: at(minute),
        dataUpdatedAt: at(minute),
        source: DataSource.demo,
      );
      final sorted = AlertPrioritizer.sort([
        alert('low-new', AlertPriority.low, 50),
        alert('crit-old', AlertPriority.critical, 10),
        alert('med-old', AlertPriority.medium, 20),
        alert('med-new', AlertPriority.medium, 40),
        alert('crit-new', AlertPriority.critical, 30),
      ]);
      expect(sorted.map((a) => a.id), [
        'crit-new',
        'crit-old',
        'med-new',
        'med-old',
        'low-new',
      ]);
    });
  });
}
