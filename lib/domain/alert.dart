import 'connection.dart';
import 'train_status.dart';

enum AlertType {
  cancellation,
  connectionRisk,
  platformChange,
  delay,
  boardingReminder,
}

/// How urgent an alert is. Lower index means more urgent.
enum AlertPriority { critical, high, medium, low }

/// How we know the alert is true.
enum AlertOrigin {
  /// Taken directly from railway data.
  railwayData,

  /// Worked out by Railocity from railway data.
  calculated,
}

/// An alert about a journey.
///
/// The alert stores facts, not sentences. The screen writes the sentence in the
/// language the passenger chose, and can also show the English original.
class RailAlert {
  const RailAlert({
    required this.id,
    required this.key,
    required this.type,
    required this.priority,
    required this.origin,
    required this.journeyId,
    required this.trainNumber,
    required this.trainName,
    required this.createdAt,
    required this.dataUpdatedAt,
    required this.source,
    this.stationName,
    this.delayMinutes,
    this.platform,
    this.previousPlatform,
    this.relatedTrainName,
    this.verdict,
    this.eventTime,
    this.read = false,
  });

  factory RailAlert.fromJson(Map<String, Object?> json) => RailAlert(
    id: json['id']! as String,
    key: json['key']! as String,
    type: AlertType.values.byName(json['type']! as String),
    priority: AlertPriority.values.byName(json['priority']! as String),
    origin: AlertOrigin.values.byName(json['origin']! as String),
    journeyId: json['journeyId']! as String,
    trainNumber: json['trainNumber']! as String,
    trainName: json['trainName']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    dataUpdatedAt: DateTime.parse(json['dataUpdatedAt']! as String),
    source: DataSource.values.byName(json['source']! as String),
    stationName: json['stationName'] as String?,
    delayMinutes: json['delayMinutes'] as int?,
    platform: json['platform'] as String?,
    previousPlatform: json['previousPlatform'] as String?,
    relatedTrainName: json['relatedTrainName'] as String?,
    verdict: json['verdict'] == null
        ? null
        : ConnectionVerdict.values.byName(json['verdict']! as String),
    eventTime: json['eventTime'] == null
        ? null
        : DateTime.parse(json['eventTime']! as String),
    read: json['read'] as bool? ?? false,
  );

  final String id;

  /// Identity used to avoid duplicate alerts.
  final String key;
  final AlertType type;
  final AlertPriority priority;
  final AlertOrigin origin;
  final String journeyId;
  final String trainNumber;
  final String trainName;
  final DateTime createdAt;

  /// When the railway data behind this alert was last confirmed.
  final DateTime dataUpdatedAt;
  final DataSource source;
  final String? stationName;
  final int? delayMinutes;
  final String? platform;
  final String? previousPlatform;

  /// The other train in a connection, when the alert is about a connection.
  final String? relatedTrainName;
  final ConnectionVerdict? verdict;

  /// A time the alert is about, for example the departure time in a reminder.
  final DateTime? eventTime;
  final bool read;

  /// Whether the passenger must act, not only read.
  bool get needsAction =>
      priority == AlertPriority.critical || priority == AlertPriority.high;

  RailAlert copyWith({bool? read}) => RailAlert(
    id: id,
    key: key,
    type: type,
    priority: priority,
    origin: origin,
    journeyId: journeyId,
    trainNumber: trainNumber,
    trainName: trainName,
    createdAt: createdAt,
    dataUpdatedAt: dataUpdatedAt,
    source: source,
    stationName: stationName,
    delayMinutes: delayMinutes,
    platform: platform,
    previousPlatform: previousPlatform,
    relatedTrainName: relatedTrainName,
    verdict: verdict,
    eventTime: eventTime,
    read: read ?? this.read,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'key': key,
    'type': type.name,
    'priority': priority.name,
    'origin': origin.name,
    'journeyId': journeyId,
    'trainNumber': trainNumber,
    'trainName': trainName,
    'createdAt': createdAt.toIso8601String(),
    'dataUpdatedAt': dataUpdatedAt.toIso8601String(),
    'source': source.name,
    'stationName': stationName,
    'delayMinutes': delayMinutes,
    'platform': platform,
    'previousPlatform': previousPlatform,
    'relatedTrainName': relatedTrainName,
    'verdict': verdict?.name,
    'eventTime': eventTime?.toIso8601String(),
    'read': read,
  };
}

/// Passenger choices for which alerts to receive.
///
/// Cancellation and missed-connection alerts are always on. A passenger must
/// not miss a cancelled train because of a settings switch.
class AlertPreferences {
  const AlertPreferences({
    this.delays = true,
    this.platformChanges = true,
    this.reminders = true,
    this.minDelayMinutes = 15,
  });

  factory AlertPreferences.fromJson(Map<String, Object?> json) =>
      AlertPreferences(
        delays: json['delays'] as bool? ?? true,
        platformChanges: json['platformChanges'] as bool? ?? true,
        reminders: json['reminders'] as bool? ?? true,
        minDelayMinutes: json['minDelayMinutes'] as int? ?? 15,
      );

  final bool delays;
  final bool platformChanges;
  final bool reminders;

  /// Smaller delays do not create an alert.
  final int minDelayMinutes;

  static const delayThresholdChoices = [10, 15, 30, 60];

  AlertPreferences copyWith({
    bool? delays,
    bool? platformChanges,
    bool? reminders,
    int? minDelayMinutes,
  }) => AlertPreferences(
    delays: delays ?? this.delays,
    platformChanges: platformChanges ?? this.platformChanges,
    reminders: reminders ?? this.reminders,
    minDelayMinutes: minDelayMinutes ?? this.minDelayMinutes,
  );

  Map<String, Object?> toJson() => {
    'delays': delays,
    'platformChanges': platformChanges,
    'reminders': reminders,
    'minDelayMinutes': minDelayMinutes,
  };
}

abstract final class AlertPrioritizer {
  /// Most urgent first. Within one priority, the newest first.
  static List<RailAlert> sort(Iterable<RailAlert> alerts) {
    final list = alerts.toList();
    list.sort((a, b) {
      final byPriority = a.priority.index.compareTo(b.priority.index);
      if (byPriority != 0) return byPriority;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }
}
