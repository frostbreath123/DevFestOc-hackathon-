import 'fact_sheet.dart';

class GuardResult {
  const GuardResult(this.problems);

  final List<String> problems;

  bool get ok => problems.isEmpty;
}

/// Checks AI text before the passenger sees it.
///
/// The AI is not trusted with facts. This guard rejects text that:
///  * names a time, train number or platform that is not in the fact sheet;
///  * makes a guarantee, or claims an action was done;
///  * is empty or too long.
///
/// A rejected text is replaced by the built-in explanation. The guard is a
/// safety net, not proof that the text is right. The deterministic sections of
/// the reply stay on screen next to any AI text.
class AiResponseGuard {
  const AiResponseGuard();

  static const maxLength = 1200;

  static final _time = RegExp(r'(?<![\d:])([01]?\d|2[0-3]):([0-5]\d)(?![\d:])');
  static final _train = RegExp(r'(?<!\d)\d{5}(?!\d)');
  static final _platform = RegExp(
    r'(?:platform|प्लेटफॉर्म|प्लेटफार्म)\s*(?:no\.?|number|नंबर|संख्या)?\s*#?\s*(\d{1,2}[A-Za-z]?)',
    caseSensitive: false,
  );

  /// Phrases that promise something we cannot promise, or claim an action.
  static const forbiddenPhrases = <String>[
    'guarantee',
    'guaranteed',
    'will definitely',
    'train will wait',
    'will wait for you',
    'is entitled',
    'you will get a refund',
    'you will receive a refund',
    'your booking is confirmed',
    'seat is confirmed',
    'i have booked',
    'i have cancelled',
    'i have canceled',
    'i have filed',
    'refund has been',
    'गारंटी',
  ];

  GuardResult validate(String text, FactSheet facts) {
    final problems = <String>[];
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const GuardResult(['empty text']);
    if (trimmed.length > maxLength) {
      problems.add('text is longer than $maxLength characters');
    }

    final normalised = _asciiDigits(trimmed);
    final lower = normalised.toLowerCase();
    for (final phrase in forbiddenPhrases) {
      if (lower.contains(phrase)) problems.add('forbidden phrase: "$phrase"');
    }

    final allowedTimes = facts.allowedTimes;
    for (final match in _time.allMatches(normalised)) {
      final hour = match.group(1)!.padLeft(2, '0');
      final time = '$hour:${match.group(2)}';
      if (!allowedTimes.contains(time)) problems.add('unknown time: $time');
    }

    final allowedTrains = facts.allowedTrainNumbers;
    for (final match in _train.allMatches(normalised)) {
      final number = match.group(0)!;
      if (!allowedTrains.contains(number)) {
        problems.add('unknown train number: $number');
      }
    }

    final allowedPlatforms = facts.allowedPlatforms;
    for (final match in _platform.allMatches(normalised)) {
      final platform = match.group(1)!;
      if (!allowedPlatforms.contains(platform)) {
        problems.add('unknown platform: $platform');
      }
    }
    return GuardResult(problems);
  }

  static String _asciiDigits(String text) {
    const devanagari = '०१२३४५६७८९';
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final index = devanagari.indexOf(char);
      buffer.write(index >= 0 ? '$index' : char);
    }
    return buffer.toString();
  }
}
