import 'connection.dart';
import 'train.dart';
import 'train_status.dart';

/// A later train the passenger could use. It is not a booking.
class AlternativeOption {
  const AlternativeOption({
    required this.train,
    required this.fromCode,
    required this.departure,
    required this.arrival,
    required this.verdict,
    required this.statusKnown,
    required this.delayMinutes,
    required this.freshness,
    this.dataUpdatedAt,
  });

  final TrainSchedule train;
  final String fromCode;

  /// Expected departure: timetable plus the reported delay.
  final DateTime departure;

  /// Expected arrival at the destination.
  final DateTime arrival;

  /// [ConnectionVerdict.feasible] or [ConnectionVerdict.atRisk] only.
  final ConnectionVerdict verdict;

  /// `false` when no live status exists, so the times are timetable times.
  final bool statusKnown;
  final int delayMinutes;
  final DataFreshness freshness;
  final DateTime? dataUpdatedAt;

  int get durationMinutes => arrival.difference(departure).inMinutes;
}

/// Finds later trains that the passenger can realistically use.
abstract final class AlternativeFinder {
  /// [readyAt] is when the passenger can be at [fromCode] and ready to board.
  /// Seat availability is not checked, because no data for it exists here.
  static List<AlternativeOption> find({
    required Iterable<TrainSchedule> candidates,
    required Map<String, TrainStatus> statuses,
    required Set<String> excludeTrains,
    required String fromCode,
    required String destinationCode,
    required DateTime readyAt,
    required DateTime now,
    int limit = 3,
  }) {
    final options = <AlternativeOption>[];
    for (final train in candidates) {
      if (excludeTrains.contains(train.number)) continue;
      final fromIndex = train.indexOfStation(fromCode);
      final toIndex = train.indexOfStation(destinationCode);
      if (fromIndex < 0 || toIndex < 0 || fromIndex >= toIndex) continue;
      final scheduledDeparture = train.stops[fromIndex].scheduledDeparture;
      final scheduledArrival = train.stops[toIndex].scheduledArrival;
      if (scheduledDeparture == null || scheduledArrival == null) continue;

      final status = statuses[train.number];
      if (status != null && status.cancelled) continue;
      final delay = status == null || status.delayMinutes < 0
          ? 0
          : status.delayMinutes;
      final departure = scheduledDeparture.add(Duration(minutes: delay));
      final arrival = scheduledArrival.add(Duration(minutes: delay));

      final spare = departure.difference(readyAt).inMinutes;
      final ConnectionVerdict verdict;
      if (spare >= ConnectionPolicy.comfortableSlackMinutes) {
        verdict = ConnectionVerdict.feasible;
      } else if (spare >= 0) {
        verdict = ConnectionVerdict.atRisk;
      } else {
        continue; // The passenger cannot reach this train in time.
      }

      options.add(
        AlternativeOption(
          train: train,
          fromCode: fromCode,
          departure: departure,
          arrival: arrival,
          verdict: verdict,
          statusKnown: status != null,
          delayMinutes: delay,
          freshness: ConnectionCalculator.freshnessOf(status, now),
          dataUpdatedAt: status?.updatedAt,
        ),
      );
    }
    options.sort((a, b) {
      final byVerdict = a.verdict.index.compareTo(b.verdict.index);
      if (byVerdict != 0) return byVerdict;
      return a.arrival.compareTo(b.arrival);
    });
    return options.take(limit).toList();
  }
}
