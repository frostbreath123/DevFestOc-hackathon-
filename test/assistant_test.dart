import 'package:flutter_test/flutter_test.dart';
import 'package:railocity/core/l10n.dart';
import 'package:railocity/domain/alternative.dart';
import 'package:railocity/domain/connection.dart';
import 'package:railocity/domain/train.dart';
import 'package:railocity/logic/assistant/ai_explainer.dart';
import 'package:railocity/logic/assistant/ai_guard.dart';
import 'package:railocity/logic/assistant/assistant_models.dart';
import 'package:railocity/logic/assistant/assistant_orchestrator.dart';
import 'package:railocity/logic/assistant/deterministic_assistant.dart';
import 'package:railocity/logic/assistant/fact_sheet.dart';

import 'support/fixtures.dart';

class _FakeAi implements AiExplainer {
  _FakeAi({this.text, this.error});

  final String? text;
  final Object? error;
  int calls = 0;
  FactSheet? lastFacts;

  @override
  Future<String> explain({
    required String question,
    required FactSheet facts,
    required AppLanguage language,
  }) async {
    calls++;
    lastFacts = facts;
    if (error != null) throw error!;
    return text!;
  }
}

void main() {
  const l10n = L10n(AppLanguage.en);
  final now = at(20);

  // Train 1 is 90 min late: it reaches the junction at 14:50 (timetable 13:20)
  // but train 2 leaves at 13:55. The connection is missed.
  FactSheet facts({
    int delay = 90,
    bool refreshFailed = false,
    List<AlternativeOption> alternatives = const [],
  }) => FactSheet(
    view: viewWith(
      now: now,
      first: statusOf(
        '90101',
        delay: delay,
        platforms: {'CRJ': '3'},
        updatedAt: now,
      ),
      second: statusOf('90202', platforms: {'CRJ': '5'}, updatedAt: now),
    ),
    alternatives: alternatives,
    sourceLabel: 'Demo data (simulated)',
    simulated: true,
    now: now,
    refreshFailed: refreshFailed,
  );

  group('intent detection', () {
    for (final c in {
      'Will I make my connection?': AssistantIntent.connection,
      'Can I catch the next one in time': AssistantIntent.connection,
      'क्या मेरा कनेक्शन मिलेगा?': AssistantIntent.connection,
      'What are my options?': AssistantIntent.options,
      'Is there another train?': AssistantIntent.options,
      'Can I get a refund?': AssistantIntent.refund,
      'I want my money back': AssistantIntent.refund,
      'Which platform?': AssistantIntent.platform,
      'How is my train?': AssistantIntent.status,
      'hello': AssistantIntent.status,
    }.entries) {
      test('"${c.key}" -> ${c.value.name}', () {
        expect(DeterministicAssistant.detectIntent(c.key), c.value);
      });
    }
  });

  group('deterministic answer', () {
    const assistant = DeterministicAssistant();

    test('connection answer separates verified, calculated and summary', () {
      final reply = assistant.reply(
        question: 'Will I make my connection?',
        facts: facts(),
        l10n: l10n,
      );
      final byKind = {for (final s in reply.sections) s.provenance: s};
      expect(
        byKind.keys,
        containsAll([
          Provenance.verified,
          Provenance.calculated,
          Provenance.railocitySummary,
          Provenance.nextSteps,
        ]),
      );
      expect(byKind.containsKey(Provenance.aiExplanation), isFalse);

      final verified = byKind[Provenance.verified]!;
      expect(verified.simulated, isTrue);
      expect(verified.source, 'Demo data (simulated)');
      expect(verified.asOf, now);
      expect(verified.lines.join('\n'), contains('about 1 h 30 min late'));

      final calculated = byKind[Provenance.calculated]!.lines.join('\n');
      expect(calculated, contains('14:50')); // expected arrival
      expect(calculated, contains('Short by'));

      final summary = byKind[Provenance.railocitySummary]!.lines.join('\n');
      expect(summary, contains('Do not count on the train waiting.'));
      expect(reply.suggestAlternatives, isTrue);
      expect(reply.suggestSupport, isTrue);
    });

    test('never promises a refund', () {
      final reply = assistant.reply(
        question: 'Can I get a refund?',
        facts: facts(delay: 200),
        l10n: l10n,
      );
      final text = reply.sections
          .expand((s) => s.lines)
          .join('\n')
          .toLowerCase();
      expect(text, contains('may be able to'));
      expect(text, contains('official'));
      expect(text, isNot(contains('you will get a refund')));
      expect(text, isNot(contains('guarantee')));
      expect(reply.suggestSupport, isTrue);
    });

    test('says plainly when there is no journey', () {
      final reply = assistant.reply(question: 'hello', facts: null, l10n: l10n);
      expect(reply.sections.single.lines.single, l10n.noJourneyReply);
    });

    test('a missing platform is not invented', () {
      final noPlatform = FactSheet(
        view: viewWith(
          now: now,
          first: statusOf('90101', updatedAt: now),
          second: statusOf('90202', updatedAt: now),
        ),
        alternatives: const [],
        sourceLabel: 'Demo data (simulated)',
        simulated: true,
        now: now,
        refreshFailed: false,
      );
      final reply = assistant.reply(
        question: 'Which platform?',
        facts: noPlatform,
        l10n: l10n,
      );
      final text = reply.sections.expand((s) => s.lines).join('\n');
      expect(text, contains('not known yet'));
      expect(text, isNot(RegExp(r'Platform for train .*: \d')));
    });

    test('a failed refresh adds a data notice', () {
      final reply = assistant.reply(
        question: 'hello',
        facts: facts(refreshFailed: true),
        l10n: l10n,
      );
      expect(reply.notices, contains(AssistantNotice.dataProblem));
    });

    test('Hindi keeps train numbers and times unchanged', () {
      final reply = assistant.reply(
        question: 'Will I make my connection?',
        facts: facts(),
        l10n: const L10n(AppLanguage.hi),
      );
      final text = reply.sections.expand((s) => s.lines).join('\n');
      expect(text, contains('90101'));
      expect(text, contains('14:50'));
    });
  });

  group('AI response guard', () {
    const guard = AiResponseGuard();
    final sheet = facts();

    test('accepts text that uses only known facts', () {
      final result = guard.validate(
        'Train 90101 is late and should reach the junction at 14:50. '
        'Train 90202 leaves at 13:55 from platform 5.',
        sheet,
      );
      expect(result.problems, isEmpty);
      expect(result.ok, isTrue);
    });

    test('rejects a time that is not in the facts', () {
      final result = guard.validate('Your train leaves at 14:10.', sheet);
      expect(result.ok, isFalse);
      expect(result.problems.single, contains('14:10'));
    });

    test('rejects a train number that is not in the facts', () {
      final result = guard.validate('Take train 12345 instead.', sheet);
      expect(result.ok, isFalse);
      expect(result.problems.single, contains('12345'));
    });

    test('rejects a platform that is not in the facts', () {
      final result = guard.validate('Go to platform 9.', sheet);
      expect(result.ok, isFalse);
      expect(result.problems.single, contains('9'));
    });

    test('checks Hindi text and Devanagari digits too', () {
      final result = guard.validate('ट्रेन ९०२०२ प्लेटफॉर्म ७ पर आएगी।', sheet);
      expect(result.ok, isFalse);
      expect(result.problems, contains('unknown platform: 7'));
      expect(result.problems.any((p) => p.contains('90202')), isFalse);
    });

    for (final phrase in [
      'The train will wait for you.',
      'A refund is guaranteed.',
      'You will get a refund.',
      'I have booked your ticket.',
    ]) {
      test('rejects "$phrase"', () {
        expect(guard.validate(phrase, sheet).ok, isFalse);
      });
    }

    test('rejects empty and very long text', () {
      expect(guard.validate('   ', sheet).ok, isFalse);
      expect(guard.validate('a' * 1300, sheet).ok, isFalse);
    });
  });

  group('orchestrator', () {
    const goodText =
        'Train 90101 is late. It should reach the junction at '
        '14:50, after train 90202 leaves at 13:55. Look at the other trains.';

    test('with no AI, uses the built-in summary and says AI is off', () async {
      const orchestrator = AssistantOrchestrator();
      final reply = await orchestrator.ask(
        question: 'Will I make my connection?',
        facts: facts(),
        l10n: l10n,
      );
      expect(reply.usedAi, isFalse);
      expect(reply.notices, contains(AssistantNotice.aiOff));
      expect(
        reply.sections.map((s) => s.provenance),
        contains(Provenance.railocitySummary),
      );
    });

    test('AI text replaces only the summary, and is labelled', () async {
      final ai = _FakeAi(text: goodText);
      final orchestrator = AssistantOrchestrator(ai: ai);
      final reply = await orchestrator.ask(
        question: 'Will I make my connection?',
        facts: facts(),
        l10n: l10n,
      );
      expect(ai.calls, 1);
      expect(reply.usedAi, isTrue);
      final kinds = reply.sections.map((s) => s.provenance).toList();
      expect(kinds, contains(Provenance.aiExplanation));
      expect(kinds, isNot(contains(Provenance.railocitySummary)));
      expect(kinds, containsAll([Provenance.verified, Provenance.calculated]));
    });

    test('rejected AI text falls back to the built-in summary', () async {
      final ai = _FakeAi(text: 'Your train leaves at 21:07 and will wait.');
      final orchestrator = AssistantOrchestrator(ai: ai);
      final reply = await orchestrator.ask(
        question: 'Will I make my connection?',
        facts: facts(),
        l10n: l10n,
      );
      expect(reply.usedAi, isFalse);
      expect(reply.notices, contains(AssistantNotice.aiRejected));
      final text = reply.sections.expand((s) => s.lines).join('\n');
      expect(text, isNot(contains('21:07')));
      expect(
        reply.sections.map((s) => s.provenance),
        contains(Provenance.railocitySummary),
      );
    });

    test('an AI outage falls back and says so', () async {
      final ai = _FakeAi(error: const AssistantUnavailable('timeout'));
      final orchestrator = AssistantOrchestrator(ai: ai);
      final reply = await orchestrator.ask(
        question: 'Will I make my connection?',
        facts: facts(),
        l10n: l10n,
      );
      expect(reply.usedAi, isFalse);
      expect(reply.notices, contains(AssistantNotice.aiUnavailable));
      expect(reply.sections, isNotEmpty);
    });

    test('the AI receives facts only, with no personal data', () async {
      final ai = _FakeAi(text: goodText);
      await AssistantOrchestrator(
        ai: ai,
      ).ask(question: 'Will I make my connection?', facts: facts(), l10n: l10n);
      final json = ai.lastFacts!.toJson();
      expect(json['isSimulatedDemoData'], isTrue);
      expect(
        json.keys,
        containsAll([
          'dataSource',
          'trains',
          'connections',
          'otherTrains',
          'refundRuleHint',
        ]),
      );
      final connection = (json['connections']! as List).single as Map;
      expect(connection['verdict'], ConnectionVerdict.likelyMissed.name);
      expect(connection['minutesNeededToChange'], 15);
    });

    test('with no journey, the AI is not called', () async {
      final ai = _FakeAi(text: goodText);
      await AssistantOrchestrator(ai: ai)
          .ask(question: 'hello', facts: null, l10n: l10n);
      expect(ai.calls, 0);
    });
  });

  group('alternatives', () {
    TrainSchedule train(String number, int departs, int arrives) =>
        TrainSchedule(
          number: number,
          name: 'Train $number',
          stops: [
            StopTime(station: crossroads, scheduledDeparture: at(departs)),
            StopTime(station: lakeview, scheduledArrival: at(arrives)),
          ],
        );

    test('keeps trains the passenger can reach, best first, max 3', () {
      // Ready at the junction at 13:50 + 15 min transfer = 14:05 (at(125)).
      final options = AlternativeFinder.find(
        candidates: [
          train('1', 100, 400), // leaves before ready: dropped
          train('2', 130, 600), // 5 min spare: at risk
          train('3', 140, 500), // 15 min spare: feasible, arrives 500
          train('4', 200, 480), // feasible, arrives 480 -> first
          train('5', 300, 700), // feasible
        ],
        statuses: {'5': statusOf('5', delay: 30, updatedAt: now)},
        excludeTrains: const {},
        fromCode: 'CRJ',
        destinationCode: 'LKV',
        readyAt: at(125),
        now: now,
      );
      expect(options.map((o) => o.train.number), ['4', '3', '5']);
      expect(options.first.verdict, ConnectionVerdict.feasible);
      expect(options.last.departure, at(330)); // 300 + 30 delay
      expect(options.last.statusKnown, isTrue);
      expect(options.first.statusKnown, isFalse);
    });

    test('drops cancelled and excluded trains', () {
      final options = AlternativeFinder.find(
        candidates: [
          train('1', 200, 500),
          train('2', 210, 520),
          train('3', 220, 540),
        ],
        statuses: {'1': statusOf('1', cancelled: true, updatedAt: now)},
        excludeTrains: const {'2'},
        fromCode: 'CRJ',
        destinationCode: 'LKV',
        readyAt: at(125),
        now: now,
      );
      expect(options.map((o) => o.train.number), ['3']);
    });
  });
}
