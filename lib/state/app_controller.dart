import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/l10n.dart';
import '../data/local_store.dart';
import '../data/mock_railway_data_service.dart';
import '../data/railway_data_service.dart';
import '../domain/alert.dart';
import '../domain/alternative.dart';
import '../domain/journey.dart';
import '../domain/journey_view.dart';
import '../domain/train.dart';
import '../domain/train_status.dart';
import '../logic/alert_engine.dart';
import '../logic/assistant/assistant_models.dart';
import '../logic/assistant/assistant_orchestrator.dart';
import '../logic/assistant/fact_sheet.dart';

enum RefreshState { idle, loading, succeeded, failed }

enum AddJourneyProblem { invalidNumber, notFound, doNotMeet, unavailable }

class AddJourneyException implements Exception {
  const AddJourneyException(this.problem, {this.train});

  final AddJourneyProblem problem;

  /// The train number the problem is about, when there is one.
  final String? train;

  @override
  String toString() => 'AddJourneyException(${problem.name}, train: $train)';
}

/// A journey that was checked but not saved yet.
class AddJourneyPreview {
  const AddJourneyPreview({required this.journey, required this.schedules});

  final Journey journey;
  final Map<String, TrainSchedule> schedules;
}

class AlternativesResult {
  const AlternativesResult({required this.options, required this.failed});

  final List<AlternativeOption> options;

  /// `true` when the provider could not be reached.
  final bool failed;
}

/// Holds the state of the app and runs its use cases.
///
/// Screens read from here and call its methods. They do not talk to data
/// services directly.
class AppController extends ChangeNotifier {
  AppController({
    required this.data,
    required this.store,
    required this.assistant,
    this.clock = systemClock,
    this.engine = const AlertEngine(),
    this.retryDelay = const Duration(milliseconds: 400),
  });

  final RailwayDataService data;
  final LocalStore store;
  final AssistantOrchestrator assistant;
  final Clock clock;
  final AlertEngine engine;

  /// Wait before the one retry of a failed status request.
  final Duration retryDelay;

  List<Journey> _journeys = [];
  Map<String, TrainSchedule> _schedules = {};
  Map<String, TrainStatus> _statuses = {};
  List<RailAlert> _alerts = [];
  AlertPreferences _preferences = const AlertPreferences();
  AppLanguage _language = AppLanguage.en;

  RefreshState _refreshState = RefreshState.idle;
  bool _lastRefreshFailed = false;
  bool _refreshQueued = false;
  bool _loaded = false;
  Timer? _timer;

  final List<ChatMessage> _chat = [];
  bool _assistantBusy = false;

  // --- Read access -------------------------------------------------------

  bool get loaded => _loaded;
  DateTime get now => clock();
  L10n get l10n => L10n(_language);
  AppLanguage get language => _language;
  AlertPreferences get preferences => _preferences;
  RefreshState get refreshState => _refreshState;
  bool get lastRefreshFailed => _lastRefreshFailed;
  List<Journey> get journeys => List.unmodifiable(_journeys);
  List<ChatMessage> get chat => List.unmodifiable(_chat);
  bool get assistantBusy => _assistantBusy;
  bool get aiConnected => assistant.aiConnected;

  /// The demo service, or `null` when real data is used.
  MockRailwayDataService? get demoService =>
      data is MockRailwayDataService ? data as MockRailwayDataService : null;

  List<RailAlert> get alerts => AlertPrioritizer.sort(_alerts);
  int get unreadAlertCount => _alerts.where((a) => !a.read).length;

  JourneyView viewOf(Journey journey) => JourneyView.build(
    journey: journey,
    schedules: _schedules,
    statuses: _statuses,
    now: clock(),
  );

  JourneyView? get activeView =>
      _journeys.isEmpty ? null : viewOf(_journeys.first);

  // --- Start up ----------------------------------------------------------

  /// Loads saved data. Saved data shows at once, so the app works offline.
  Future<void> init() async {
    final saved = await store.load();
    if (saved != null) {
      _journeys = [...saved.journeys];
      _schedules = {...saved.schedules};
      _statuses = {...saved.statuses};
      _alerts = [...saved.alerts];
      _preferences = saved.preferences;
      _language = AppLanguage.values.firstWhere(
        (l) => l.name == saved.languageCode,
        orElse: () => AppLanguage.en,
      );
    }
    _loaded = true;
    notifyListeners();
    if (_journeys.isNotEmpty) await refresh();
  }

  void startPolling([Duration interval = const Duration(seconds: 60)]) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  // --- Refresh -----------------------------------------------------------

  /// Loads the latest status of every train and creates new alerts.
  ///
  /// When a train cannot be loaded, its last known status stays. The screens
  /// then show that this data is old.
  Future<void> refresh() async {
    if (_journeys.isEmpty) return;
    if (_refreshState == RefreshState.loading) {
      // Run once more when the current refresh ends, so no change is missed.
      _refreshQueued = true;
      return;
    }
    _refreshState = RefreshState.loading;
    notifyListeners();

    final before = {for (final j in _journeys) j.id: viewOf(j)};
    final trains = {for (final j in _journeys) ...j.trainNumbers};
    final updated = Map<String, TrainStatus>.of(_statuses);
    var failures = 0;

    await Future.wait([
      for (final number in trains)
        () async {
          final status = await _fetchWithOneRetry(number);
          if (status == null) {
            failures++;
          } else {
            updated[number] = status;
          }
        }(),
    ]);

    _statuses = updated;
    final time = clock();
    final created = <RailAlert>[];
    for (final journey in _journeys) {
      created.addAll(
        engine.generate(
          current: viewOf(journey),
          previous: before[journey.id],
          preferences: _preferences,
          existing: [..._alerts, ...created],
          now: time,
        ),
      );
    }
    _alerts = [...created, ..._alerts];

    _lastRefreshFailed = failures > 0;
    _refreshState = failures == 0
        ? RefreshState.succeeded
        : RefreshState.failed;
    await _persist();
    notifyListeners();

    if (_refreshQueued) {
      _refreshQueued = false;
      await refresh();
    }
  }

  Future<TrainStatus?> _fetchWithOneRetry(String number) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await data.fetchStatus(number);
      } on RailwayDataException catch (error) {
        debugPrint(
          '[AppController.refresh] status for train $number failed '
          '(attempt ${attempt + 1}): $error',
        );
        if (error.failure == RailwayDataFailure.notFound) return null;
        if (attempt == 0 && retryDelay > Duration.zero) {
          await Future<void>.delayed(retryDelay);
        }
      }
    }
    return null;
  }

  // --- Journeys ----------------------------------------------------------

  /// Checks train numbers and finds where the passenger changes trains.
  Future<AddJourneyPreview> previewJourney({
    required String firstTrain,
    String? secondTrain,
  }) async {
    final first = firstTrain.trim();
    final second = (secondTrain ?? '').trim();
    final pattern = RegExp(r'^\d{5}$');
    if (!pattern.hasMatch(first)) {
      throw AddJourneyException(AddJourneyProblem.invalidNumber, train: first);
    }
    if (second.isNotEmpty && !pattern.hasMatch(second)) {
      throw AddJourneyException(AddJourneyProblem.invalidNumber, train: second);
    }

    Future<TrainSchedule> lookup(String number) async {
      try {
        return await data.lookupTrain(number);
      } on RailwayDataException catch (error) {
        throw AddJourneyException(
          error.failure == RailwayDataFailure.notFound
              ? AddJourneyProblem.notFound
              : AddJourneyProblem.unavailable,
          train: number,
        );
      }
    }

    final firstSchedule = await lookup(first);
    final id = 'journey-${clock().microsecondsSinceEpoch}';
    if (second.isEmpty) {
      return AddJourneyPreview(
        journey: Journey(
          id: id,
          legs: [
            JourneyLeg(
              trainNumber: first,
              boardCode: firstSchedule.origin.code,
              alightCode: firstSchedule.destination.code,
            ),
          ],
        ),
        schedules: {first: firstSchedule},
      );
    }

    final secondSchedule = await lookup(second);
    // The change station is the first stop of train 1 (after its origin) that
    // train 2 also serves, with a later stop to go to, and where train 2 does
    // not leave before train 1 arrives.
    for (final stop in firstSchedule.stops.skip(1)) {
      final index = secondSchedule.indexOfStation(stop.station.code);
      if (index < 0 || index >= secondSchedule.stops.length - 1) continue;
      final arrival = stop.scheduledArrival;
      final departure = secondSchedule.stops[index].scheduledDeparture;
      if (arrival == null || departure == null) continue;
      if (departure.isBefore(arrival)) continue;
      return AddJourneyPreview(
        journey: Journey(
          id: id,
          legs: [
            JourneyLeg(
              trainNumber: first,
              boardCode: firstSchedule.origin.code,
              alightCode: stop.station.code,
            ),
            JourneyLeg(
              trainNumber: second,
              boardCode: stop.station.code,
              alightCode: secondSchedule.destination.code,
            ),
          ],
        ),
        schedules: {first: firstSchedule, second: secondSchedule},
      );
    }
    throw const AddJourneyException(AddJourneyProblem.doNotMeet);
  }

  Future<void> addJourney(AddJourneyPreview preview) async {
    _journeys = [preview.journey, ..._journeys];
    _schedules = {..._schedules, ...preview.schedules};
    await _persist();
    notifyListeners();
    await refresh();
  }

  Future<void> removeJourney(String id) async {
    _journeys = _journeys.where((j) => j.id != id).toList();
    _alerts = _alerts.where((a) => a.journeyId != id).toList();
    final used = {for (final j in _journeys) ...j.trainNumbers};
    _schedules = {
      for (final e in _schedules.entries)
        if (used.contains(e.key)) e.key: e.value,
    };
    _statuses = {
      for (final e in _statuses.entries)
        if (used.contains(e.key)) e.key: e.value,
    };
    await _persist();
    notifyListeners();
  }

  // --- Alternatives ------------------------------------------------------

  /// Finds later trains for the passenger. Nothing here is a booking.
  Future<AlternativesResult> loadAlternatives(Journey journey) async {
    final view = viewOf(journey);
    final time = clock();
    final firstCancelled = view.statuses.first?.cancelled ?? false;
    final connection = view.worstConnection;

    String fromCode;
    DateTime readyAt;
    if (connection == null || firstCancelled) {
      fromCode = journey.originCode;
      readyAt = time;
    } else {
      fromCode = connection.stationCode;
      final arrival =
          connection.expectedArrival ?? connection.scheduledArrival ?? time;
      readyAt = arrival.add(Duration(minutes: connection.transferMinutes ?? 0));
    }

    final List<TrainSchedule> candidates;
    try {
      candidates = await data.trainsBetween(
        fromCode: fromCode,
        toCode: journey.destinationCode,
        departAfter: time.subtract(const Duration(hours: 1)),
      );
    } on RailwayDataException catch (error) {
      debugPrint(
        '[AppController.loadAlternatives] trains lookup failed: $error',
      );
      return const AlternativesResult(options: [], failed: true);
    }

    final statuses = <String, TrainStatus>{};
    for (final train in candidates) {
      try {
        statuses[train.number] = await data.fetchStatus(train.number);
      } on RailwayDataException catch (error) {
        debugPrint(
          '[AppController.loadAlternatives] status for ${train.number} failed: $error',
        );
      }
    }
    return AlternativesResult(
      options: AlternativeFinder.find(
        candidates: candidates,
        statuses: statuses,
        excludeTrains: journey.trainNumbers,
        fromCode: fromCode,
        destinationCode: journey.destinationCode,
        readyAt: readyAt,
        now: time,
      ),
      failed: false,
    );
  }

  // --- Alerts and settings ----------------------------------------------

  Future<void> markAlertRead(String id) async {
    _alerts = [
      for (final a in _alerts) a.id == id ? a.copyWith(read: true) : a,
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> markAllAlertsRead() async {
    _alerts = [for (final a in _alerts) a.copyWith(read: true)];
    await _persist();
    notifyListeners();
  }

  Future<void> setPreferences(AlertPreferences value) async {
    _preferences = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (value == _language) return;
    _language = value;
    // Old answers were written in the old language. Start a clean chat.
    _chat.clear();
    await _persist();
    notifyListeners();
  }

  // --- Assistant ---------------------------------------------------------

  Future<void> askAssistant(String question) async {
    final text = question.trim();
    if (text.isEmpty || _assistantBusy) return;
    _chat.add(ChatMessage.user(text));
    _assistantBusy = true;
    notifyListeners();

    FactSheet? facts;
    final view = activeView;
    if (view != null) {
      final alternatives = await loadAlternatives(view.journey);
      facts = FactSheet(
        view: viewOf(view.journey),
        alternatives: alternatives.options,
        sourceLabel: data.sourceLabel,
        simulated: data.isSimulated,
        now: clock(),
        refreshFailed: _lastRefreshFailed,
      );
    }
    final reply = await assistant.ask(question: text, facts: facts, l10n: l10n);
    _chat.add(ChatMessage.assistant(reply));
    _assistantBusy = false;
    notifyListeners();
  }

  // --- Demo --------------------------------------------------------------

  /// Changes the simulated scenario, then refreshes. Demo data only.
  Future<void> applyDemo(
    void Function(MockRailwayDataService demo) change,
  ) async {
    final demo = demoService;
    if (demo == null) return;
    change(demo);
    notifyListeners();
    await refresh();
  }

  Future<void> _persist() => store.save(
    StoredState(
      journeys: _journeys,
      schedules: _schedules,
      statuses: _statuses,
      alerts: _alerts,
      preferences: _preferences,
      languageCode: _language.name,
    ),
  );
}
