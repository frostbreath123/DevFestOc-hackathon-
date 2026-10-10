import 'package:flutter_test/flutter_test.dart';
import 'package:railocity/domain/connection.dart';
import 'package:railocity/domain/train_status.dart';

import 'support/fixtures.dart';

void main() {
  final now = at(10);

  ConnectionAssessment assess({
    int firstDelay = 0,
    int secondDelay = 0,
    bool firstCancelled = false,
    bool secondCancelled = false,
    bool firstKnown = true,
    bool secondKnown = true,
    bool transferKnown = true,
    int secondDeparts = 115,
    Duration age = Duration.zero,
  }) {
    final junction = transferKnown ? crossroads : crossroadsNoTransfer;
    final updated = now.subtract(age);
    TrainStatus? status(String n, int d, bool c) =>
        statusOf(n, delay: d, cancelled: c, updatedAt: updated);
    return ConnectionCalculator.assess(
      arriving: firstTrain(junction: junction),
      departing: secondTrain(junction: junction, departsAt: secondDeparts),
      stationCode: 'CRJ',
      arrivingStatus: firstKnown
          ? status('90101', firstDelay, firstCancelled)
          : null,
      departingStatus: secondKnown
          ? status('90202', secondDelay, secondCancelled)
          : null,
      now: now,
    );
  }

  group('verdict with a known transfer time (15 min)', () {
    test('on time: 35 min window leaves 20 min spare', () {
      final a = assess();
      expect(a.windowMinutes, 35);
      expect(a.transferMinutes, 15);
      expect(a.slackMinutes, 20);
      expect(a.verdict, ConnectionVerdict.feasible);
      expect(a.transferTimeKnown, isTrue);
    });

    test('expected times are timetable plus delay', () {
      final a = assess(firstDelay: 10);
      expect(a.expectedArrival, at(90));
      expect(a.expectedDeparture, at(115));
      expect(a.scheduledArrival, at(80));
      expect(a.scheduledDeparture, at(115));
    });

    // Slack is 20 minus the delay. The safe margin is 10 minutes.
    for (final c in [
      (delay: 10, slack: 10, verdict: ConnectionVerdict.feasible),
      (delay: 11, slack: 9, verdict: ConnectionVerdict.atRisk),
      (delay: 20, slack: 0, verdict: ConnectionVerdict.atRisk),
      (delay: 21, slack: -1, verdict: ConnectionVerdict.likelyMissed),
      (delay: 90, slack: -70, verdict: ConnectionVerdict.likelyMissed),
    ]) {
      test('delay ${c.delay} min -> slack ${c.slack} -> ${c.verdict.name}', () {
        final a = assess(firstDelay: c.delay);
        expect(a.slackMinutes, c.slack);
        expect(a.verdict, c.verdict);
      });
    }

    test('first train arrives after second train leaves: negative window', () {
      final a = assess(firstDelay: 60);
      expect(a.windowMinutes, -25);
      expect(a.verdict, ConnectionVerdict.likelyMissed);
    });

    test('a delayed second train gives more time', () {
      final a = assess(firstDelay: 30, secondDelay: 30);
      expect(a.windowMinutes, 35);
      expect(a.verdict, ConnectionVerdict.feasible);
    });

    test('a second train that runs early does not leave early', () {
      final a = assess(secondDelay: -10);
      expect(a.expectedDeparture, at(115));
      expect(a.windowMinutes, 35);
    });
  });

  group('verdict with no transfer time', () {
    test('a long window is feasible and says the slack is unknown', () {
      final a = assess(transferKnown: false, secondDeparts: 135); // window 55
      expect(a.verdict, ConnectionVerdict.feasible);
      expect(a.transferMinutes, isNull);
      expect(a.slackMinutes, isNull);
      expect(a.transferTimeKnown, isFalse);
    });

    test('a 35 min window is only "at risk"', () {
      final a = assess(transferKnown: false); // window 35
      expect(a.verdict, ConnectionVerdict.atRisk);
    });

    test('a window under 15 min is "likely missed"', () {
      final a = assess(transferKnown: false, firstDelay: 25); // window 10
      expect(a.verdict, ConnectionVerdict.likelyMissed);
    });
  });

  group('cancellations and missing data', () {
    test('first train cancelled', () {
      final a = assess(firstCancelled: true);
      expect(a.verdict, ConnectionVerdict.cancelled);
      expect(a.cancelledTrain, '90101');
    });

    test('second train cancelled', () {
      final a = assess(secondCancelled: true);
      expect(a.verdict, ConnectionVerdict.cancelled);
      expect(a.cancelledTrain, '90202');
    });

    test('missing status gives "unknown" and "unavailable"', () {
      final a = assess(secondKnown: false);
      expect(a.verdict, ConnectionVerdict.unknown);
      expect(a.freshness, DataFreshness.unavailable);
      expect(a.windowMinutes, isNull);
    });

    test('a station that train 2 does not serve gives "unknown"', () {
      final a = ConnectionCalculator.assess(
        arriving: firstTrain(),
        departing: secondTrain(),
        stationCode: 'XXX',
        arrivingStatus: statusOf('90101', updatedAt: now),
        departingStatus: statusOf('90202', updatedAt: now),
        now: now,
      );
      expect(a.verdict, ConnectionVerdict.unknown);
    });
  });

  group('freshness', () {
    test('status from this minute is fresh', () {
      expect(assess().freshness, DataFreshness.fresh);
    });

    test('status exactly 10 min old is still fresh', () {
      expect(
        assess(age: const Duration(minutes: 10)).freshness,
        DataFreshness.fresh,
      );
    });

    test('status 11 min old is stale, and the verdict is still given', () {
      final a = assess(age: const Duration(minutes: 11), firstDelay: 30);
      expect(a.freshness, DataFreshness.stale);
      expect(a.verdict, ConnectionVerdict.likelyMissed);
    });

    test('the oldest update time is reported', () {
      final a = ConnectionCalculator.assess(
        arriving: firstTrain(),
        departing: secondTrain(),
        stationCode: 'CRJ',
        arrivingStatus: statusOf(
          '90101',
          updatedAt: now.subtract(const Duration(minutes: 3)),
        ),
        departingStatus: statusOf('90202', updatedAt: now),
        now: now,
      );
      expect(a.dataUpdatedAt, now.subtract(const Duration(minutes: 3)));
    });
  });
}
