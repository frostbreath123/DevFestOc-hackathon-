import 'connection.dart';
import 'journey.dart';
import 'train.dart';
import 'train_status.dart';

/// A one-word summary of how a journey is doing.
enum JourneyHealth {
  onTrack,
  delayed,
  atRisk,
  likelyMissed,
  cancelled,
  unknown,
}

/// A journey joined with its timetables, live statuses and connection checks.
///
/// This is a read-only snapshot. It is built by deterministic code.
class JourneyView {
  const JourneyView({
    required this.journey,
    required this.schedules,
    required this.statuses,
    required this.connections,
    required this.now,
  });

  /// Builds the snapshot. [connections] has one entry per change of train.
  factory JourneyView.build({
    required Journey journey,
    required Map<String, TrainSchedule> schedules,
    required Map<String, TrainStatus> statuses,
    required DateTime now,
  }) {
    final legSchedules = [
      for (final leg in journey.legs) schedules[leg.trainNumber],
    ];
    final legStatuses = [
      for (final leg in journey.legs) statuses[leg.trainNumber],
    ];
    final connections = <ConnectionAssessment>[];
    for (var i = 0; i < journey.legs.length - 1; i++) {
      final arriving = legSchedules[i];
      final departing = legSchedules[i + 1];
      final stationCode = journey.legs[i].alightCode;
      if (arriving == null || departing == null) {
        connections.add(
          ConnectionAssessment(
            verdict: ConnectionVerdict.unknown,
            freshness: DataFreshness.unavailable,
            stationCode: stationCode,
            arrivingTrain: journey.legs[i].trainNumber,
            departingTrain: journey.legs[i + 1].trainNumber,
          ),
        );
      } else {
        connections.add(
          ConnectionCalculator.assess(
            arriving: arriving,
            departing: departing,
            stationCode: stationCode,
            arrivingStatus: legStatuses[i],
            departingStatus: legStatuses[i + 1],
            now: now,
          ),
        );
      }
    }
    return JourneyView(
      journey: journey,
      schedules: legSchedules,
      statuses: legStatuses,
      connections: connections,
      now: now,
    );
  }

  final Journey journey;

  /// One entry per leg. `null` when the timetable is not known.
  final List<TrainSchedule?> schedules;

  /// One entry per leg. `null` when no status was ever loaded.
  final List<TrainStatus?> statuses;
  final List<ConnectionAssessment> connections;
  final DateTime now;

  int get maxDelayMinutes {
    var delay = 0;
    for (final status in statuses) {
      if (status != null && !status.cancelled && status.delayMinutes > delay) {
        delay = status.delayMinutes;
      }
    }
    return delay;
  }

  JourneyHealth get health {
    if (statuses.any((status) => status?.cancelled ?? false)) {
      return JourneyHealth.cancelled;
    }
    if (connections.any((c) => c.verdict == ConnectionVerdict.likelyMissed)) {
      return JourneyHealth.likelyMissed;
    }
    if (connections.any((c) => c.verdict == ConnectionVerdict.atRisk)) {
      return JourneyHealth.atRisk;
    }
    if (statuses.any((status) => status == null) ||
        schedules.any((schedule) => schedule == null) ||
        connections.any((c) => c.verdict == ConnectionVerdict.unknown)) {
      return JourneyHealth.unknown;
    }
    return maxDelayMinutes >= 5 ? JourneyHealth.delayed : JourneyHealth.onTrack;
  }

  /// The connection that needs the most attention, or `null` for one train.
  ConnectionAssessment? get worstConnection {
    ConnectionAssessment? worst;
    for (final connection in connections) {
      if (worst == null ||
          connection.verdict.severity > worst.verdict.severity) {
        worst = connection;
      }
    }
    return worst;
  }

  /// The oldest update time over all legs, or `null` when nothing is loaded.
  DateTime? get oldestUpdate {
    DateTime? oldest;
    for (final status in statuses) {
      if (status == null) continue;
      if (oldest == null || status.updatedAt.isBefore(oldest)) {
        oldest = status.updatedAt;
      }
    }
    return oldest;
  }

  DataFreshness get freshness {
    var result = DataFreshness.fresh;
    for (final status in statuses) {
      final f = ConnectionCalculator.freshnessOf(status, now);
      if (f.index > result.index) result = f;
    }
    return result;
  }

  Station? stationByCode(String code) {
    for (final schedule in schedules) {
      final stop = schedule?.stopAt(code);
      if (stop != null) return stop.station;
    }
    return null;
  }

  String stationName(String code) => stationByCode(code)?.name ?? code;

  String get originName => stationName(journey.originCode);
  String get destinationName => stationName(journey.destinationCode);
}
