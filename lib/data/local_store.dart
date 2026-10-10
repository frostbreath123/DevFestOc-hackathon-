import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/alert.dart';
import '../domain/journey.dart';
import '../domain/train.dart';
import '../domain/train_status.dart';

/// Everything the app keeps on the phone so it can work offline.
///
/// It holds no personal data: no name, PNR, phone number or location.
class StoredState {
  const StoredState({
    this.journeys = const [],
    this.schedules = const {},
    this.statuses = const {},
    this.alerts = const [],
    this.preferences = const AlertPreferences(),
    this.languageCode,
  });

  factory StoredState.fromJson(Map<String, Object?> json) {
    final schedules = [
      for (final item in (json['schedules'] as List? ?? const []))
        TrainSchedule.fromJson((item as Map).cast()),
    ];
    final statuses = [
      for (final item in (json['statuses'] as List? ?? const []))
        TrainStatus.fromJson((item as Map).cast()),
    ];
    return StoredState(
      journeys: [
        for (final item in (json['journeys'] as List? ?? const []))
          Journey.fromJson((item as Map).cast()),
      ],
      schedules: {for (final s in schedules) s.number: s},
      statuses: {for (final s in statuses) s.trainNumber: s},
      alerts: [
        for (final item in (json['alerts'] as List? ?? const []))
          RailAlert.fromJson((item as Map).cast()),
      ],
      preferences: AlertPreferences.fromJson(
        ((json['preferences'] as Map?) ?? const {}).cast(),
      ),
      languageCode: json['language'] as String?,
    );
  }

  final List<Journey> journeys;
  final Map<String, TrainSchedule> schedules;
  final Map<String, TrainStatus> statuses;
  final List<RailAlert> alerts;
  final AlertPreferences preferences;
  final String? languageCode;

  Map<String, Object?> toJson() => {
    'journeys': [for (final j in journeys) j.toJson()],
    'schedules': [for (final s in schedules.values) s.toJson()],
    'statuses': [for (final s in statuses.values) s.toJson()],
    'alerts': [for (final a in alerts) a.toJson()],
    'preferences': preferences.toJson(),
    'language': languageCode,
  };
}

abstract interface class LocalStore {
  /// Returns `null` when nothing is saved or the saved data cannot be read.
  Future<StoredState?> load();
  Future<void> save(StoredState state);
}

class MemoryLocalStore implements LocalStore {
  StoredState? _state;

  @override
  Future<StoredState?> load() async => _state;

  @override
  Future<void> save(StoredState state) async => _state = state;
}

class PreferencesLocalStore implements LocalStore {
  static const _key = 'railocity.state.v1';

  @override
  Future<StoredState?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return StoredState.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object catch (error) {
      // Saved data may be damaged. Start fresh instead of crashing.
      debugPrint(
        '[PreferencesLocalStore.load] could not read saved state: $error',
      );
      return null;
    }
  }

  @override
  Future<void> save(StoredState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } on Object catch (error) {
      debugPrint('[PreferencesLocalStore.save] could not save state: $error');
    }
  }
}
