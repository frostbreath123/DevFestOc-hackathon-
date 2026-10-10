import '../../core/clock.dart';
import '../../core/l10n.dart';
import '../../domain/journey_view.dart';
import '../../domain/train_status.dart';
import 'assistant_models.dart';
import 'fact_sheet.dart';

enum AssistantIntent { connection, options, refund, platform, status }

/// Answers passenger questions from the fact sheet. It uses no AI.
///
/// This is the safe path. It always works, even with no network and no AI
/// service. It also gives the AI service the same structure to explain.
class DeterministicAssistant {
  const DeterministicAssistant();

  static AssistantIntent detectIntent(String question) {
    final q = question.toLowerCase();
    bool has(List<String> words) => words.any(q.contains);

    if (has([
      'refund',
      'money',
      'tdr',
      'cancel my ticket',
      'cancel ticket',
      'रिफंड',
      'पैसे',
    ])) {
      return AssistantIntent.refund;
    }
    if (has(['platform', 'प्लेटफॉर्म', 'प्लेटफार्म'])) {
      return AssistantIntent.platform;
    }
    if (has([
      'option',
      'alternative',
      'other train',
      'another train',
      'next train',
      'instead',
      'विकल्प',
      'दूसरी ट्रेन',
      'अगली ट्रेन',
    ])) {
      return AssistantIntent.options;
    }
    if (has([
      'connect',
      'miss',
      'make it',
      'catch',
      'in time',
      'कनेक्शन',
      'छूट',
    ])) {
      return AssistantIntent.connection;
    }
    return AssistantIntent.status;
  }

  /// [facts] is `null` when the passenger has no journey yet.
  AssistantReply reply({
    required String question,
    required FactSheet? facts,
    required L10n l10n,
  }) {
    if (facts == null) {
      return AssistantReply(
        sections: [
          ReplySection(
            provenance: Provenance.railocitySummary,
            title: l10n.sectionSummary,
            lines: [l10n.noJourneyReply],
          ),
        ],
      );
    }

    final intent = detectIntent(question);
    final view = facts.view;
    final names = facts.names;
    final health = view.health;

    final verified = switch (intent) {
      AssistantIntent.platform => _platformLines(view, names, l10n),
      AssistantIntent.options => _statusLines(view, names, l10n),
      _ => [
        ..._statusLines(view, names, l10n),
        ..._timetableLines(view, names, l10n),
      ],
    };
    final calculated = switch (intent) {
      AssistantIntent.options => _alternativeLines(facts, l10n),
      AssistantIntent.refund => [l10n.refundHint(facts.refundHint)],
      AssistantIntent.platform => <String>[],
      _ => _connectionLines(view, names, l10n),
    };

    final summary = switch (intent) {
      AssistantIntent.platform => [l10n.platformAdvice],
      AssistantIntent.options => [l10n.alternativesNote],
      AssistantIntent.refund => [l10n.supportLimits, l10n.supportVerify],
      AssistantIntent.connection || AssistantIntent.status => [
        if (view.connections.isEmpty && intent == AssistantIntent.connection)
          l10n.singleTrainNoConnection,
        l10n.healthDetail(view, names: names),
      ],
    };

    final next = switch (intent) {
      AssistantIntent.platform => <String>[],
      AssistantIntent.refund => <String>[],
      _ => [l10n.nextStep(health)],
    };

    final needsAttention =
        health == JourneyHealth.atRisk ||
        health == JourneyHealth.likelyMissed ||
        health == JourneyHealth.cancelled;
    final asOf = view.oldestUpdate;

    return AssistantReply(
      sections: [
        if (verified.isNotEmpty)
          ReplySection(
            provenance: Provenance.verified,
            title: l10n.sectionVerified,
            lines: verified,
            asOf: asOf,
            source: facts.sourceLabel,
            simulated: facts.simulated,
          ),
        if (calculated.isNotEmpty)
          ReplySection(
            provenance: Provenance.calculated,
            title: l10n.sectionCalculated,
            lines: calculated,
            asOf: asOf,
            source: facts.sourceLabel,
            simulated: facts.simulated,
          ),
        ReplySection(
          provenance: Provenance.railocitySummary,
          title: l10n.sectionSummary,
          lines: summary,
        ),
        if (next.isNotEmpty)
          ReplySection(
            provenance: Provenance.nextSteps,
            title: l10n.sectionNext,
            lines: next,
          ),
      ],
      notices: [if (facts.refreshFailed) AssistantNotice.dataProblem],
      suggestAlternatives:
          intent == AssistantIntent.options ||
          (needsAttention && intent != AssistantIntent.refund),
      suggestSupport:
          intent == AssistantIntent.refund ||
          health == JourneyHealth.likelyMissed ||
          health == JourneyHealth.cancelled,
    );
  }

  // --- Lines -------------------------------------------------------------

  List<String> _statusLines(JourneyView view, JourneyNames names, L10n l10n) {
    final lines = <String>[];
    for (var i = 0; i < view.journey.legs.length; i++) {
      final number = view.journey.legs[i].trainNumber;
      final status = view.statuses[i];
      lines.add(
        l10n.factTrainStatus(
          names.train(number),
          delay: status?.delayMinutes,
          cancelled: status?.cancelled ?? false,
          known: status != null,
        ),
      );
    }
    return lines;
  }

  List<String> _timetableLines(
    JourneyView view,
    JourneyNames names,
    L10n l10n,
  ) {
    final lines = <String>[];
    for (final connection in view.connections) {
      final station = names.station(connection.stationCode);
      final arrival = connection.scheduledArrival;
      final departure = connection.scheduledDeparture;
      if (arrival != null) {
        lines.add(
          l10n.factScheduled(station, formatClock(arrival), arrival: true),
        );
      }
      if (departure != null) {
        lines.add(
          l10n.factScheduled(station, formatClock(departure), arrival: false),
        );
      }
    }
    return lines;
  }

  List<String> _platformLines(JourneyView view, JourneyNames names, L10n l10n) {
    final lines = <String>[];
    final seen = <String>{};
    for (var i = 0; i < view.journey.legs.length; i++) {
      final leg = view.journey.legs[i];
      final status = view.statuses[i];
      for (final code in [leg.boardCode, leg.alightCode]) {
        if (!seen.add('${leg.trainNumber}|$code')) continue;
        lines.add(
          l10n.factPlatform(
            names.train(leg.trainNumber),
            names.station(code),
            status?.platforms[code],
          ),
        );
      }
    }
    return lines;
  }

  List<String> _connectionLines(
    JourneyView view,
    JourneyNames names,
    L10n l10n,
  ) {
    final connection = view.worstConnection;
    if (connection == null) return const [];
    final lines = <String>[];
    final station = names.station(connection.stationCode);
    final arrivingStatus = _statusFor(view, connection.arrivingTrain);
    final departingStatus = _statusFor(view, connection.departingTrain);

    final expectedArrival = connection.expectedArrival;
    final scheduledArrival = connection.scheduledArrival;
    if (expectedArrival != null &&
        scheduledArrival != null &&
        arrivingStatus != null) {
      lines.add(
        l10n.calcExpected(
          station,
          formatClock(expectedArrival),
          arrivingStatus.delayMinutes,
          formatClock(scheduledArrival),
          arrival: true,
        ),
      );
    }
    final expectedDeparture = connection.expectedDeparture;
    final scheduledDeparture = connection.scheduledDeparture;
    if (expectedDeparture != null &&
        scheduledDeparture != null &&
        departingStatus != null) {
      lines.add(
        l10n.calcExpected(
          station,
          formatClock(expectedDeparture),
          departingStatus.delayMinutes < 0 ? 0 : departingStatus.delayMinutes,
          formatClock(scheduledDeparture),
          arrival: false,
        ),
      );
    }
    final window = connection.windowMinutes;
    if (window != null) {
      lines.add(l10n.calcWindow(window));
      lines.add(l10n.calcTransfer(connection.transferMinutes));
      final slack = connection.slackMinutes;
      if (slack != null) lines.add(l10n.calcSlack(slack));
    }
    return lines;
  }

  List<String> _alternativeLines(FactSheet facts, L10n l10n) {
    if (facts.alternatives.isEmpty) return [l10n.noAlternatives];
    return [
      for (final option in facts.alternatives)
        l10n.alternativeLine(
          train: option.train.displayName,
          departs: formatClock(option.departure),
          arrives: formatClockWithDay(option.arrival, option.departure),
          minutes: option.durationMinutes,
          verdict: option.verdict,
        ),
    ];
  }

  TrainStatus? _statusFor(JourneyView view, String number) {
    for (var i = 0; i < view.journey.legs.length; i++) {
      if (view.journey.legs[i].trainNumber == number) return view.statuses[i];
    }
    return null;
  }
}
