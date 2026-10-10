/// Where a piece of railway information came from.
enum DataSource {
  /// Simulated data made by Railocity for the prototype. It is never live.
  demo,

  /// Data from an authorised railway data provider.
  official,
}

/// The running status of one train at one moment.
class TrainStatus {
  const TrainStatus({
    required this.trainNumber,
    required this.delayMinutes,
    required this.cancelled,
    required this.platforms,
    required this.updatedAt,
    required this.source,
  });

  factory TrainStatus.fromJson(Map<String, Object?> json) => TrainStatus(
    trainNumber: json['train']! as String,
    delayMinutes: json['delay']! as int,
    cancelled: json['cancelled']! as bool,
    platforms: (json['platforms']! as Map).map(
      (key, value) => MapEntry(key as String, value as String),
    ),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    source: DataSource.values.byName(json['source']! as String),
  );

  final String trainNumber;

  /// Minutes behind the timetable. Zero means on time.
  final int delayMinutes;
  final bool cancelled;

  /// Platform by station code. A station is missing when no platform is known.
  final Map<String, String> platforms;

  /// When the source last confirmed this status.
  final DateTime updatedAt;
  final DataSource source;

  Map<String, Object?> toJson() => {
    'train': trainNumber,
    'delay': delayMinutes,
    'cancelled': cancelled,
    'platforms': platforms,
    'updatedAt': updatedAt.toIso8601String(),
    'source': source.name,
  };
}
