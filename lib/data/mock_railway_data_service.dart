import '../core/clock.dart';
import '../domain/train.dart';
import '../domain/train_status.dart';
import 'railway_data_service.dart';

/// Simulated railway data for the prototype.
///
/// Every train here is made up. The numbers and names are fictional on purpose.
/// The app labels this data as a demo wherever it shows a time.
///
/// The scenario is built from "now", so the demo always has a connection that
/// is about 35 minutes wide:
///
///  * 90101 Demo Express: Meridian Central -> Crossroads Junction
///  * 90202 Demo Superfast: Crossroads Junction -> Lakeview (the connection)
///  * 90203, 90406, 90305: later trains from Crossroads Junction to Lakeview
class MockRailwayDataService implements RailwayDataService {
  MockRailwayDataService({
    this.clock = systemClock,
    this.latency = const Duration(milliseconds: 350),
  }) {
    _schedules = _buildSchedules(_anchor());
  }

  final Clock clock;

  /// Simulated network time.
  final Duration latency;

  late final Map<String, TrainSchedule> _schedules;

  // Scenario controls. The settings screen changes these.
  final Map<String, int> _delays = {};
  final Set<String> _cancelled = {};

  /// When `true`, connecting train 90202 uses platform 8 at Crossroads
  /// Junction instead of platform 5.
  bool platformChanged = false;

  /// When `true`, every request fails, to test the error states.
  bool failing = false;

  /// When `true`, statuses are 25 minutes old, to test the stale state.
  bool stale = false;

  static const _demoPlatforms = <String, Map<String, String>>{
    '90101': {'CRJ': '3'},
    '90202': {'CRJ': '5'},
    '90203': {'CRJ': '6'},
    '90406': {'CRJ': '7'},
    '90305': {'CRJ': '2'},
  };

  @override
  String get sourceLabel => 'Demo data (simulated)';

  @override
  bool get isSimulated => true;

  @override
  DataSource get dataSource => DataSource.demo;

  // --- Scenario controls --------------------------------------------------

  int delayOf(String train) => _delays[train] ?? 0;
  bool isCancelled(String train) => _cancelled.contains(train);

  void setDelay(String train, int minutes) {
    if (minutes <= 0) {
      _delays.remove(train);
    } else {
      _delays[train] = minutes;
    }
  }

  void setCancelled(String train, {required bool cancelled}) {
    if (cancelled) {
      _cancelled.add(train);
    } else {
      _cancelled.remove(train);
    }
  }

  void resetScenario() {
    _delays.clear();
    _cancelled.clear();
    platformChanged = false;
    failing = false;
    stale = false;
  }

  // --- RailwayDataService -------------------------------------------------

  @override
  Future<TrainSchedule> lookupTrain(String number) async {
    await _wait();
    _throwIfFailing();
    final schedule = _schedules[number];
    if (schedule == null) {
      throw RailwayDataException(
        RailwayDataFailure.notFound,
        'Train $number is not in the demo data.',
      );
    }
    return schedule;
  }

  @override
  Future<TrainStatus> fetchStatus(String number) async {
    await _wait();
    _throwIfFailing();
    if (!_schedules.containsKey(number)) {
      throw RailwayDataException(
        RailwayDataFailure.notFound,
        'Train $number is not in the demo data.',
      );
    }
    final platforms = Map<String, String>.of(_demoPlatforms[number] ?? {});
    if (platformChanged && number == '90202') {
      platforms['CRJ'] = '8';
    }
    final now = clock();
    return TrainStatus(
      trainNumber: number,
      delayMinutes: delayOf(number),
      cancelled: isCancelled(number),
      platforms: platforms,
      updatedAt: stale ? now.subtract(const Duration(minutes: 25)) : now,
      source: DataSource.demo,
    );
  }

  @override
  Future<List<TrainSchedule>> trainsBetween({
    required String fromCode,
    required String toCode,
    required DateTime departAfter,
  }) async {
    await _wait();
    _throwIfFailing();
    final result = <TrainSchedule>[];
    for (final train in _schedules.values) {
      final from = train.indexOfStation(fromCode);
      final to = train.indexOfStation(toCode);
      if (from < 0 || to < 0 || from >= to) continue;
      final departure = train.stops[from].scheduledDeparture;
      if (departure == null || departure.isBefore(departAfter)) continue;
      result.add(train);
    }
    return result;
  }

  // --- Helpers ------------------------------------------------------------

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  void _throwIfFailing() {
    if (failing) {
      throw const RailwayDataException(
        RailwayDataFailure.unavailable,
        'Simulated outage.',
      );
    }
  }

  DateTime _anchor() {
    final now = clock();
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute - now.minute % 5,
    );
  }

  static Map<String, TrainSchedule> _buildSchedules(DateTime t0) {
    DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

    const meridian = Station(code: 'MRC', name: 'Meridian Central');
    const crossroads = Station(
      code: 'CRJ',
      name: 'Crossroads Junction',
      minTransferMinutes: 15,
    );
    const lakeview = Station(code: 'LKV', name: 'Lakeview');

    TrainSchedule train(String number, String name, List<StopTime> stops) =>
        TrainSchedule(number: number, name: name, stops: stops);

    return {
      '90101': train('90101', 'Demo Express', [
        StopTime(station: meridian, scheduledDeparture: at(-180)),
        StopTime(
          station: crossroads,
          scheduledArrival: at(80),
          scheduledDeparture: at(85),
        ),
      ]),
      '90202': train('90202', 'Demo Superfast', [
        StopTime(station: crossroads, scheduledDeparture: at(115)),
        StopTime(station: lakeview, scheduledArrival: at(475)),
      ]),
      '90203': train('90203', 'Demo Intercity', [
        StopTime(station: crossroads, scheduledDeparture: at(175)),
        StopTime(station: lakeview, scheduledArrival: at(575)),
      ]),
      '90406': train('90406', 'Demo Passenger', [
        StopTime(station: crossroads, scheduledDeparture: at(150)),
        StopTime(station: lakeview, scheduledArrival: at(710)),
      ]),
      '90305': train('90305', 'Demo Mail', [
        StopTime(station: crossroads, scheduledDeparture: at(330)),
        StopTime(station: lakeview, scheduledArrival: at(840)),
      ]),
    };
  }
}
