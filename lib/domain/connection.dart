import 'dart:math' as math;

import 'train.dart';
import 'train_status.dart';

/// Whether the passenger can change trains.
enum ConnectionVerdict {
  /// Enough time, with a safe margin.
  feasible,

  /// Possible, but the margin is small.
  atRisk,

  /// The passenger would arrive too late to board.
  likelyMissed,

  /// One of the two trains is cancelled.
  cancelled,

  /// We do not have the data to decide.
  unknown,
}

extension ConnectionVerdictSeverity on ConnectionVerdict {
  /// Higher means the passenger needs to look at it sooner.
  int get severity => switch (this) {
    ConnectionVerdict.cancelled => 4,
    ConnectionVerdict.likelyMissed => 3,
    ConnectionVerdict.atRisk => 2,
    ConnectionVerdict.unknown => 1,
    ConnectionVerdict.feasible => 0,
  };
}

/// How current the status data is.
enum DataFreshness { fresh, stale, unavailable }

/// The result of one connection check. All values come from deterministic code.
class ConnectionAssessment {
  const ConnectionAssessment({
    required this.verdict,
    required this.freshness,
    required this.stationCode,
    required this.arrivingTrain,
    required this.departingTrain,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.expectedArrival,
    this.expectedDeparture,
    this.windowMinutes,
    this.transferMinutes,
    this.slackMinutes,
    this.cancelledTrain,
    this.dataUpdatedAt,
  });

  final ConnectionVerdict verdict;
  final DataFreshness freshness;
  final String stationCode;
  final String arrivingTrain;
  final String departingTrain;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;

  /// Timetable time plus the reported delay. This is an estimate.
  final DateTime? expectedArrival;
  final DateTime? expectedDeparture;

  /// Minutes between expected arrival and expected departure.
  final int? windowMinutes;

  /// Minutes needed to change trains. `null` when the station data is missing.
  final int? transferMinutes;

  /// Window minus transfer time. `null` when [transferMinutes] is `null`.
  final int? slackMinutes;
  final String? cancelledTrain;

  /// The oldest update time of the two trains used in this check.
  final DateTime? dataUpdatedAt;

  bool get transferTimeKnown => transferMinutes != null;
  bool get needsAttention =>
      verdict == ConnectionVerdict.atRisk ||
      verdict == ConnectionVerdict.likelyMissed ||
      verdict == ConnectionVerdict.cancelled;
}

/// Rules for connection checks. They are plain numbers so tests can name them.
abstract final class ConnectionPolicy {
  /// Status older than this is stale.
  static const staleAfter = Duration(minutes: 10);

  /// With a known transfer time, this much spare time counts as safe.
  static const comfortableSlackMinutes = 10;

  /// With no transfer time, a window of at least this many minutes counts as
  /// safe, because we cannot prove a shorter window is enough.
  static const unknownTransferSafeWindow = 45;

  /// With no transfer time, a window below this is treated as a likely miss.
  static const unknownTransferTightWindow = 15;
}

/// Deterministic connection checks. No AI is used here.
abstract final class ConnectionCalculator {
  static DataFreshness freshnessOf(TrainStatus? status, DateTime now) {
    if (status == null) return DataFreshness.unavailable;
    final age = now.difference(status.updatedAt);
    return age > ConnectionPolicy.staleAfter
        ? DataFreshness.stale
        : DataFreshness.fresh;
  }

  static ConnectionAssessment assess({
    required TrainSchedule arriving,
    required TrainSchedule departing,
    required String stationCode,
    required TrainStatus? arrivingStatus,
    required TrainStatus? departingStatus,
    required DateTime now,
  }) {
    final arrivalStop = arriving.stopAt(stationCode);
    final departureStop = departing.stopAt(stationCode);
    final scheduledArrival = arrivalStop?.scheduledArrival;
    final scheduledDeparture = departureStop?.scheduledDeparture;
    final transfer =
        (arrivalStop?.station ?? departureStop?.station)?.minTransferMinutes;

    final freshness = _worse(
      freshnessOf(arrivingStatus, now),
      freshnessOf(departingStatus, now),
    );
    final updates = [
      if (arrivingStatus != null) arrivingStatus.updatedAt,
      if (departingStatus != null) departingStatus.updatedAt,
    ]..sort();
    final oldestUpdate = updates.isEmpty ? null : updates.first;

    ConnectionAssessment build(
      ConnectionVerdict verdict, {
      DateTime? expectedArrival,
      DateTime? expectedDeparture,
      int? window,
      int? slack,
      String? cancelledTrain,
    }) => ConnectionAssessment(
      verdict: verdict,
      freshness: freshness,
      stationCode: stationCode,
      arrivingTrain: arriving.number,
      departingTrain: departing.number,
      scheduledArrival: scheduledArrival,
      scheduledDeparture: scheduledDeparture,
      expectedArrival: expectedArrival,
      expectedDeparture: expectedDeparture,
      windowMinutes: window,
      transferMinutes: transfer,
      slackMinutes: slack,
      cancelledTrain: cancelledTrain,
      dataUpdatedAt: oldestUpdate,
    );

    if (arrivingStatus != null && arrivingStatus.cancelled) {
      return build(
        ConnectionVerdict.cancelled,
        cancelledTrain: arriving.number,
      );
    }
    if (departingStatus != null && departingStatus.cancelled) {
      return build(
        ConnectionVerdict.cancelled,
        cancelledTrain: departing.number,
      );
    }
    if (scheduledArrival == null ||
        scheduledDeparture == null ||
        arrivingStatus == null ||
        departingStatus == null) {
      return build(ConnectionVerdict.unknown);
    }

    final expectedArrival = scheduledArrival.add(
      Duration(minutes: arrivingStatus.delayMinutes),
    );
    // A train does not leave early, so an early running time is ignored.
    final expectedDeparture = scheduledDeparture.add(
      Duration(minutes: math.max(0, departingStatus.delayMinutes)),
    );
    final window = expectedDeparture.difference(expectedArrival).inMinutes;

    final int? slack = transfer == null ? null : window - transfer;
    final ConnectionVerdict verdict;
    if (slack != null) {
      if (slack >= ConnectionPolicy.comfortableSlackMinutes) {
        verdict = ConnectionVerdict.feasible;
      } else if (slack >= 0) {
        verdict = ConnectionVerdict.atRisk;
      } else {
        verdict = ConnectionVerdict.likelyMissed;
      }
    } else if (window >= ConnectionPolicy.unknownTransferSafeWindow) {
      verdict = ConnectionVerdict.feasible;
    } else if (window >= ConnectionPolicy.unknownTransferTightWindow) {
      verdict = ConnectionVerdict.atRisk;
    } else {
      verdict = ConnectionVerdict.likelyMissed;
    }

    return build(
      verdict,
      expectedArrival: expectedArrival,
      expectedDeparture: expectedDeparture,
      window: window,
      slack: slack,
    );
  }

  static DataFreshness _worse(DataFreshness a, DataFreshness b) =>
      a.index >= b.index ? a : b;
}
