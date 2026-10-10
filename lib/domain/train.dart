/// A railway station.
class Station {
  const Station({
    required this.code,
    required this.name,
    this.minTransferMinutes,
  });

  factory Station.fromJson(Map<String, Object?> json) => Station(
    code: json['code']! as String,
    name: json['name']! as String,
    minTransferMinutes: json['transfer'] as int?,
  );

  final String code;
  final String name;

  /// Time a passenger needs to change trains here. `null` means we do not have
  /// reliable information, and the app must say so instead of guessing.
  final int? minTransferMinutes;

  Map<String, Object?> toJson() => {
    'code': code,
    'name': name,
    'transfer': minTransferMinutes,
  };
}

/// One stop of a train, with the timetable times (not live times).
class StopTime {
  const StopTime({
    required this.station,
    this.scheduledArrival,
    this.scheduledDeparture,
  });

  factory StopTime.fromJson(Map<String, Object?> json) => StopTime(
    station: Station.fromJson((json['station']! as Map).cast()),
    scheduledArrival: _parse(json['arr']),
    scheduledDeparture: _parse(json['dep']),
  );

  final Station station;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;

  Map<String, Object?> toJson() => {
    'station': station.toJson(),
    'arr': scheduledArrival?.toIso8601String(),
    'dep': scheduledDeparture?.toIso8601String(),
  };

  static DateTime? _parse(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}

/// The timetable of one train.
class TrainSchedule {
  const TrainSchedule({
    required this.number,
    required this.name,
    required this.stops,
  });

  factory TrainSchedule.fromJson(Map<String, Object?> json) => TrainSchedule(
    number: json['number']! as String,
    name: json['name']! as String,
    stops: [
      for (final stop in json['stops']! as List)
        StopTime.fromJson((stop as Map).cast()),
    ],
  );

  final String number;
  final String name;
  final List<StopTime> stops;

  Station get origin => stops.first.station;
  Station get destination => stops.last.station;
  String get displayName => '$name ($number)';

  int indexOfStation(String code) =>
      stops.indexWhere((stop) => stop.station.code == code);

  StopTime? stopAt(String code) {
    final index = indexOfStation(code);
    return index < 0 ? null : stops[index];
  }

  Map<String, Object?> toJson() => {
    'number': number,
    'name': name,
    'stops': [for (final stop in stops) stop.toJson()],
  };
}
