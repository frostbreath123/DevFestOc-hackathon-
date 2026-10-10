import '../../core/clock.dart';
import '../../core/l10n.dart';
import '../../domain/alternative.dart';
import '../../domain/journey_view.dart';
import '../../domain/support_rules.dart';

/// Resolves train and station names for sentences about one journey.
class JourneyNames implements L10nNames {
  const JourneyNames(this.view, [this.extraTrains = const {}]);

  final JourneyView view;

  /// Names of trains outside the journey, for example alternatives.
  final Map<String, String> extraTrains;

  @override
  String train(String number) {
    for (final schedule in view.schedules) {
      if (schedule != null && schedule.number == number) {
        return schedule.displayName;
      }
    }
    final extra = extraTrains[number];
    return extra == null ? number : '$extra ($number)';
  }

  @override
  String station(String code) => view.stationName(code);
}

/// Everything the assistant is allowed to know.
///
/// Both the built-in explainer and the AI service get only this data. It holds
/// verified railway data and values calculated by deterministic code. It holds
/// no personal data.
class FactSheet {
  const FactSheet({
    required this.view,
    required this.alternatives,
    required this.sourceLabel,
    required this.simulated,
    required this.now,
    required this.refreshFailed,
  });

  final JourneyView view;
  final List<AlternativeOption> alternatives;
  final String sourceLabel;
  final bool simulated;
  final DateTime now;

  /// `true` when the last refresh failed, so the data may be old.
  final bool refreshFailed;

  JourneyNames get names => JourneyNames(view, {
    for (final option in alternatives) option.train.number: option.train.name,
  });

  RefundHint get refundHint {
    // Use the train that gives the strongest hint.
    var best = RefundHint.unknown;
    for (final status in view.statuses) {
      final hint = SupportRules.refundHint(status);
      if (_refundRank(hint) > _refundRank(best)) best = hint;
    }
    return best;
  }

  static int _refundRank(RefundHint hint) => switch (hint) {
    RefundHint.trainCancelled => 3,
    RefundHint.delayOverThreshold => 2,
    RefundHint.delayBelowThreshold => 1,
    RefundHint.unknown => 0,
  };

  /// Train numbers the AI may mention.
  Set<String> get allowedTrainNumbers => {
    for (final leg in view.journey.legs) leg.trainNumber,
    for (final option in alternatives) option.train.number,
  };

  /// Times (`HH:mm`) the AI may mention.
  Set<String> get allowedTimes {
    final times = <DateTime>[];
    for (final schedule in view.schedules) {
      if (schedule == null) continue;
      for (final stop in schedule.stops) {
        final arrival = stop.scheduledArrival;
        final departure = stop.scheduledDeparture;
        if (arrival != null) times.add(arrival);
        if (departure != null) times.add(departure);
      }
    }
    for (final connection in view.connections) {
      if (connection.expectedArrival != null) {
        times.add(connection.expectedArrival!);
      }
      if (connection.expectedDeparture != null) {
        times.add(connection.expectedDeparture!);
      }
    }
    for (final option in alternatives) {
      times
        ..add(option.departure)
        ..add(option.arrival);
    }
    return {for (final t in times) formatClock(t)};
  }

  /// Platform numbers the AI may mention.
  Set<String> get allowedPlatforms => {
    for (final status in view.statuses)
      if (status != null) ...status.platforms.values,
  };

  /// The data sent to the AI service, as plain JSON values.
  Map<String, Object?> toJson() => {
    'dataSource': sourceLabel,
    'isSimulatedDemoData': simulated,
    'asOf': formatClock(now),
    'lastRefreshFailed': refreshFailed,
    'journey': {'from': view.originName, 'to': view.destinationName},
    'trains': [
      for (var i = 0; i < view.journey.legs.length; i++)
        {
          'number': view.journey.legs[i].trainNumber,
          'name': view.schedules[i]?.name,
          'statusKnown': view.statuses[i] != null,
          'delayMinutes': view.statuses[i]?.delayMinutes,
          'cancelled': view.statuses[i]?.cancelled,
          'platforms': {
            for (final entry
                in (view.statuses[i]?.platforms ?? const <String, String>{})
                    .entries)
              view.stationName(entry.key): entry.value,
          },
          'statusUpdatedAt': view.statuses[i] == null
              ? null
              : formatClock(view.statuses[i]!.updatedAt),
        },
    ],
    'connections': [
      for (final c in view.connections)
        {
          'station': view.stationName(c.stationCode),
          'arrivingTrain': c.arrivingTrain,
          'departingTrain': c.departingTrain,
          'verdict': c.verdict.name,
          'dataFreshness': c.freshness.name,
          'expectedArrival': c.expectedArrival == null
              ? null
              : formatClock(c.expectedArrival!),
          'expectedDeparture': c.expectedDeparture == null
              ? null
              : formatClock(c.expectedDeparture!),
          'minutesBetweenTrains': c.windowMinutes,
          'minutesNeededToChange': c.transferMinutes,
          'spareMinutes': c.slackMinutes,
          'cancelledTrain': c.cancelledTrain,
        },
    ],
    'otherTrains': [
      for (final option in alternatives)
        {
          'number': option.train.number,
          'name': option.train.name,
          'departs': formatClock(option.departure),
          'arrives': formatClock(option.arrival),
          'journeyMinutes': option.durationMinutes,
          'timeToCatchIt': option.verdict.name,
          'liveStatusKnown': option.statusKnown,
        },
    ],
    'refundRuleHint': refundHint.name,
  };
}
