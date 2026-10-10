import 'dart:math' as math;

import '../domain/alert.dart';
import '../domain/connection.dart';
import '../domain/journey_view.dart';
import '../domain/train_status.dart';

/// Decides which new alerts a passenger should get.
///
/// The engine compares the journey now with the journey at the last refresh.
/// It creates an alert only when something changed in a way that matters, and
/// it never repeats an alert that the passenger already has.
class AlertEngine {
  const AlertEngine();

  /// A delay must grow by at least this much to create another delay alert.
  static const meaningfulDelayChangeMinutes = 10;

  /// Delay alerts are grouped in steps of this size.
  static const delayBucketMinutes = 15;

  /// A delay of this size or more is "high" priority on its own.
  static const highPriorityDelayMinutes = 60;

  /// A platform change this close to the event is "high" priority.
  static const imminentMinutes = 90;

  /// A boarding reminder starts this long before departure.
  static const reminderLeadMinutes = 60;

  /// An existing alert blocks an identical new alert for this long.
  static const dedupeWindow = Duration(hours: 12);

  List<RailAlert> generate({
    required JourneyView current,
    required JourneyView? previous,
    required AlertPreferences preferences,
    required List<RailAlert> existing,
    required DateTime now,
  }) {
    final journeyId = current.journey.id;
    final knownKeys = <String>{
      for (final alert in existing)
        if (now.difference(alert.createdAt) < dedupeWindow) alert.key,
    };
    final created = <RailAlert>[];

    String nextId() => '${now.microsecondsSinceEpoch}-${created.length}';

    void add(RailAlert Function(String id) build, String key) {
      if (!knownKeys.add(key)) return;
      created.add(build(nextId()));
    }

    final legs = current.journey.legs;
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final schedule = current.schedules[i];
      final status = current.statuses[i];
      if (schedule == null || status == null) continue;
      final before = previous?.statuses[i];
      final related = _relatedConnection(current, leg.trainNumber);

      // 1. Cancellation. Always on.
      if (status.cancelled && !(before?.cancelled ?? false)) {
        final key = '$journeyId|${leg.trainNumber}|cancelled';
        add(
          (id) => RailAlert(
            id: id,
            key: key,
            type: AlertType.cancellation,
            priority: AlertPriority.critical,
            origin: AlertOrigin.railwayData,
            journeyId: journeyId,
            trainNumber: leg.trainNumber,
            trainName: schedule.name,
            createdAt: now,
            dataUpdatedAt: status.updatedAt,
            source: status.source,
          ),
          key,
        );
        continue;
      }
      if (status.cancelled) continue;

      // 2. Delay.
      if (preferences.delays) {
        final delayBefore = before == null || before.cancelled
            ? 0
            : before.delayMinutes;
        final change = status.delayMinutes - delayBefore;
        final isBigEnough = status.delayMinutes >= preferences.minDelayMinutes;
        if (isBigEnough && change >= meaningfulDelayChangeMinutes) {
          final bucket =
              (status.delayMinutes ~/ delayBucketMinutes) * delayBucketMinutes;
          final key = '$journeyId|${leg.trainNumber}|delay|$bucket';
          final verdict = related?.verdict;
          final atRisk =
              verdict == ConnectionVerdict.atRisk ||
              verdict == ConnectionVerdict.likelyMissed;
          add(
            (id) => RailAlert(
              id: id,
              key: key,
              type: AlertType.delay,
              priority:
                  atRisk || status.delayMinutes >= highPriorityDelayMinutes
                  ? AlertPriority.high
                  : AlertPriority.medium,
              origin: AlertOrigin.railwayData,
              journeyId: journeyId,
              trainNumber: leg.trainNumber,
              trainName: schedule.name,
              createdAt: now,
              dataUpdatedAt: status.updatedAt,
              source: status.source,
              delayMinutes: status.delayMinutes,
              verdict: verdict,
              relatedTrainName: related == null
                  ? null
                  : _otherTrainName(current, related, leg.trainNumber),
            ),
            key,
          );
        }
      }

      // 3. Platform change. Only when we knew an earlier platform.
      if (preferences.platformChanges && before != null) {
        for (final code in {leg.boardCode, leg.alightCode}) {
          final platform = status.platforms[code];
          final previousPlatform = before.platforms[code];
          if (platform == null ||
              previousPlatform == null ||
              platform == previousPlatform) {
            continue;
          }
          final stop = schedule.stopAt(code);
          final base = code == leg.boardCode
              ? stop?.scheduledDeparture
              : stop?.scheduledArrival;
          final eventTime = base?.add(
            Duration(minutes: math.max(0, status.delayMinutes)),
          );
          final imminent =
              eventTime != null &&
              eventTime.difference(now).inMinutes <= imminentMinutes;
          final key = '$journeyId|${leg.trainNumber}|$code|platform|$platform';
          add(
            (id) => RailAlert(
              id: id,
              key: key,
              type: AlertType.platformChange,
              priority: imminent ? AlertPriority.high : AlertPriority.medium,
              origin: AlertOrigin.railwayData,
              journeyId: journeyId,
              trainNumber: leg.trainNumber,
              trainName: schedule.name,
              createdAt: now,
              dataUpdatedAt: status.updatedAt,
              source: status.source,
              stationName: current.stationName(code),
              platform: platform,
              previousPlatform: previousPlatform,
              eventTime: eventTime,
            ),
            key,
          );
        }
      }

      // 4. Boarding reminder.
      if (preferences.reminders) {
        final departure = schedule.stopAt(leg.boardCode)?.scheduledDeparture;
        if (departure != null) {
          final expected = departure.add(
            Duration(minutes: math.max(0, status.delayMinutes)),
          );
          final minutes = expected.difference(now).inMinutes;
          if (minutes >= 0 && minutes <= reminderLeadMinutes) {
            final key =
                '$journeyId|${leg.trainNumber}|${leg.boardCode}|reminder';
            add(
              (id) => RailAlert(
                id: id,
                key: key,
                type: AlertType.boardingReminder,
                priority: AlertPriority.low,
                origin: AlertOrigin.calculated,
                journeyId: journeyId,
                trainNumber: leg.trainNumber,
                trainName: schedule.name,
                createdAt: now,
                dataUpdatedAt: status.updatedAt,
                source: status.source,
                stationName: current.stationName(leg.boardCode),
                platform: status.platforms[leg.boardCode],
                eventTime: expected,
              ),
              key,
            );
          }
        }
      }
    }

    // 5. Connection risk. Always on. Only when the data supports it.
    for (var k = 0; k < current.connections.length; k++) {
      final connection = current.connections[k];
      final verdict = connection.verdict;
      if (verdict != ConnectionVerdict.atRisk &&
          verdict != ConnectionVerdict.likelyMissed) {
        continue;
      }
      if (connection.freshness == DataFreshness.unavailable) continue;
      final verdictBefore = previous != null && previous.connections.length > k
          ? previous.connections[k].verdict
          : null;
      if (verdictBefore == verdict) continue;

      final key =
          '$journeyId|connection|$k|${verdict.name}|${connection.departingTrain}';
      final departingIndex = current.journey.legs.indexWhere(
        (l) => l.trainNumber == connection.departingTrain,
      );
      final departing = departingIndex < 0
          ? null
          : current.schedules[departingIndex];
      final updatedAt = connection.dataUpdatedAt;
      if (departing == null || updatedAt == null) continue;
      add(
        (id) => RailAlert(
          id: id,
          key: key,
          type: AlertType.connectionRisk,
          priority: verdict == ConnectionVerdict.likelyMissed
              ? AlertPriority.critical
              : AlertPriority.high,
          origin: AlertOrigin.calculated,
          journeyId: journeyId,
          trainNumber: connection.departingTrain,
          trainName: departing.name,
          createdAt: now,
          dataUpdatedAt: updatedAt,
          source: _sourceOf(current, connection),
          stationName: current.stationName(connection.stationCode),
          relatedTrainName: departing.name,
          verdict: verdict,
          eventTime: connection.expectedDeparture,
        ),
        key,
      );
    }

    return created;
  }

  ConnectionAssessment? _relatedConnection(JourneyView view, String train) {
    ConnectionAssessment? best;
    for (final c in view.connections) {
      if (c.arrivingTrain != train && c.departingTrain != train) continue;
      if (best == null || c.verdict.severity > best.verdict.severity) {
        best = c;
      }
    }
    return best;
  }

  String? _otherTrainName(
    JourneyView view,
    ConnectionAssessment connection,
    String train,
  ) {
    final other = connection.arrivingTrain == train
        ? connection.departingTrain
        : connection.arrivingTrain;
    final index = view.journey.legs.indexWhere(
      (leg) => leg.trainNumber == other,
    );
    return index < 0 ? null : view.schedules[index]?.name;
  }

  DataSource _sourceOf(JourneyView view, ConnectionAssessment connection) {
    for (final status in view.statuses) {
      if (status != null &&
          (status.trainNumber == connection.arrivingTrain ||
              status.trainNumber == connection.departingTrain)) {
        return status.source;
      }
    }
    return DataSource.demo;
  }
}
