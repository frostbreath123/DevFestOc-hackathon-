import '../domain/train.dart';
import '../domain/train_status.dart';

enum RailwayDataFailure {
  /// The provider has no train with this number.
  notFound,

  /// The provider could not be reached or did not answer in time.
  unavailable,
}

class RailwayDataException implements Exception {
  const RailwayDataException(this.failure, [this.detail]);

  final RailwayDataFailure failure;

  /// Developer detail. Never show this text to a passenger.
  final String? detail;

  @override
  String toString() =>
      'RailwayDataException(${failure.name}'
      '${detail == null ? '' : ': $detail'})';
}

/// The boundary between the app and a railway data provider.
///
/// A real implementation must use an authorised API. No such API is connected
/// yet, so the prototype uses `MockRailwayDataService`.
abstract interface class RailwayDataService {
  /// Name shown next to every time-sensitive value.
  String get sourceLabel;

  /// `true` when the data is simulated and must be labelled as such.
  bool get isSimulated;

  DataSource get dataSource;

  /// Loads the timetable of a train.
  Future<TrainSchedule> lookupTrain(String number);

  /// Loads the running status of a train.
  Future<TrainStatus> fetchStatus(String number);

  /// Trains that go from [fromCode] to [toCode] and leave [fromCode] at or
  /// after [departAfter] (timetable time).
  Future<List<TrainSchedule>> trainsBetween({
    required String fromCode,
    required String toCode,
    required DateTime departAfter,
  });
}

/// Used when real data is requested but no provider is connected.
///
/// It fails in a clear way. It never returns made-up data.
class UnconfiguredRailwayDataService implements RailwayDataService {
  const UnconfiguredRailwayDataService();

  @override
  String get sourceLabel => 'No railway data provider';

  @override
  bool get isSimulated => false;

  @override
  DataSource get dataSource => DataSource.official;

  RailwayDataException get _error => const RailwayDataException(
    RailwayDataFailure.unavailable,
    'No railway data provider is configured.',
  );

  @override
  Future<TrainSchedule> lookupTrain(String number) async => throw _error;

  @override
  Future<TrainStatus> fetchStatus(String number) async => throw _error;

  @override
  Future<List<TrainSchedule>> trainsBetween({
    required String fromCode,
    required String toCode,
    required DateTime departAfter,
  }) async => throw _error;
}
