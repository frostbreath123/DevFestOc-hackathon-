/// Source of "now". It is injected so tests and demos can control time.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();

String _two(int value) => value.toString().padLeft(2, '0');

/// 24-hour clock text, for example `15:40`.
String formatClock(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

/// Clock text with a day marker when [time] falls on a later day than
/// [reference]. Example: `00:15 (+1)`.
String formatClockWithDay(DateTime time, DateTime reference) {
  final days = DateTime(
    time.year,
    time.month,
    time.day,
  ).difference(DateTime(reference.year, reference.month, reference.day)).inDays;
  if (days <= 0) return formatClock(time);
  return '${formatClock(time)} (+$days)';
}
