import 'package:railocity/domain/journey.dart';
import 'package:railocity/domain/journey_view.dart';
import 'package:railocity/domain/train.dart';
import 'package:railocity/domain/train_status.dart';

/// 12:00 on a fixed day. All fixture times are offsets from this.
final t0 = DateTime(2026, 10, 10, 12, 0);

DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

const meridian = Station(code: 'MRC', name: 'Meridian Central');
const lakeview = Station(code: 'LKV', name: 'Lakeview');

/// Crossroads Junction with a known transfer time of 15 minutes.
const crossroads = Station(
  code: 'CRJ',
  name: 'Crossroads Junction',
  minTransferMinutes: 15,
);

/// The same station, without transfer information.
const crossroadsNoTransfer = Station(code: 'CRJ', name: 'Crossroads Junction');

/// Train 1 reaches the junction at +80 min. Train 2 leaves at +115 min.
/// With no delay the window is 35 minutes.
TrainSchedule firstTrain({Station junction = crossroads, int arrivesAt = 80}) =>
    TrainSchedule(
      number: '90101',
      name: 'Demo Express',
      stops: [
        StopTime(station: meridian, scheduledDeparture: at(-180)),
        StopTime(
          station: junction,
          scheduledArrival: at(arrivesAt),
          scheduledDeparture: at(arrivesAt + 5),
        ),
      ],
    );

TrainSchedule secondTrain({
  Station junction = crossroads,
  int departsAt = 115,
}) => TrainSchedule(
  number: '90202',
  name: 'Demo Superfast',
  stops: [
    StopTime(station: junction, scheduledDeparture: at(departsAt)),
    StopTime(station: lakeview, scheduledArrival: at(departsAt + 360)),
  ],
);

TrainStatus statusOf(
  String train, {
  int delay = 0,
  bool cancelled = false,
  Map<String, String> platforms = const {},
  required DateTime updatedAt,
}) => TrainStatus(
  trainNumber: train,
  delayMinutes: delay,
  cancelled: cancelled,
  platforms: platforms,
  updatedAt: updatedAt,
  source: DataSource.demo,
);

const journey = Journey(
  id: 'j1',
  legs: [
    JourneyLeg(trainNumber: '90101', boardCode: 'MRC', alightCode: 'CRJ'),
    JourneyLeg(trainNumber: '90202', boardCode: 'CRJ', alightCode: 'LKV'),
  ],
);

/// A view of [journey] with the given statuses, as seen at [now].
JourneyView viewWith({
  required DateTime now,
  TrainStatus? first,
  TrainStatus? second,
  Station junction = crossroads,
}) => JourneyView.build(
  journey: journey,
  schedules: {
    '90101': firstTrain(junction: junction),
    '90202': secondTrain(junction: junction),
  },
  statuses: {'90101': ?first, '90202': ?second},
  now: now,
);
