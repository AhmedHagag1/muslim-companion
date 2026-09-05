import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memorization.dart';

abstract interface class MemorizationStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesMemorizationStore implements MemorizationStore {
  static const key = 'quran.memorization.v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

class MemorizationData {
  const MemorizationData({
    this.plans = const [],
    this.ayahs = const [],
    this.sessions = const [],
  });
  final List<MemorizationPlan> plans;
  final List<MemorizedAyah> ayahs;
  final List<MemorizationSession> sessions;
}

class MemorizationRepository {
  MemorizationRepository({MemorizationStore? store})
    : _store = store ?? SharedPreferencesMemorizationStore();
  static const schemaVersion = 2;
  final MemorizationStore _store;
  MemorizationData _data = const MemorizationData();
  bool _loaded = false;
  Future<MemorizationData> load() async {
    if (_loaded) return _data;
    _loaded = true;
    final raw = await _store.read();
    if (raw == null) return _data;
    try {
      final doc = jsonDecode(raw);
      if (doc is! Map<String, dynamic> ||
          (doc['version'] != 1 && doc['version'] != schemaVersion)) {
        return _data;
      }
      final plans =
          (doc['plans'] as List?)
              ?.map(MemorizationPlan.fromJson)
              .whereType<MemorizationPlan>()
              .toList() ??
          [];
      final ids = plans.map((e) => e.id).toSet();
      final ayahs =
          (doc['ayahs'] as List?)
              ?.map(MemorizedAyah.fromJson)
              .whereType<MemorizedAyah>()
              .where((e) => ids.contains(e.planId))
              .toList() ??
          [];
      final sessions =
          (doc['sessions'] as List?)
              ?.map(MemorizationSession.fromJson)
              .whereType<MemorizationSession>()
              .where((e) => ids.contains(e.planId))
              .toList() ??
          [];
      _data = MemorizationData(plans: plans, ayahs: ayahs, sessions: sessions);
      if (doc['version'] == 1) await _save();
    } catch (_) {}
    return _data;
  }

  Future<void> createPlan(MemorizationPlan plan) async {
    await load();
    if (_data.plans.any((e) => e.id == plan.id) ||
        !QuranRange.valid(plan.start, plan.end)) {
      throw ArgumentError('Invalid or duplicate plan');
    }
    _data = MemorizationData(
      plans: [..._data.plans, plan],
      ayahs: _data.ayahs,
      sessions: _data.sessions,
    );
    await _save();
  }

  Future<void> updatePlan(MemorizationPlan plan) async {
    await load();
    final index = _data.plans.indexWhere((e) => e.id == plan.id);
    if (index < 0 || !QuranRange.valid(plan.start, plan.end)) {
      throw ArgumentError('Invalid plan');
    }
    final plans = [..._data.plans]..[index] = plan;
    _data = MemorizationData(
      plans: plans,
      ayahs: _data.ayahs,
      sessions: _data.sessions,
    );
    await _save();
  }

  Future<void> archivePlan(String id) =>
      _setStatus(id, MemorizationPlanStatus.archived);
  Future<void> _setStatus(String id, MemorizationPlanStatus status) async {
    final plan = (await load()).plans.where((e) => e.id == id).firstOrNull;
    if (plan != null) await updatePlan(plan.copyWith(status: status));
  }

  Future<void> deletePlan(String id) async {
    await load();
    _data = MemorizationData(
      plans: _data.plans.where((e) => e.id != id).toList(),
      ayahs: _data.ayahs.where((e) => e.planId != id).toList(),
      sessions: _data.sessions.where((e) => e.planId != id).toList(),
    );
    await _save();
  }

  Future<void> saveMemorizedAyah(MemorizedAyah ayah) async {
    await load();
    if (!ayah.coordinate.isValid) throw ArgumentError('Invalid coordinate');
    final values = [..._data.ayahs];
    final i = values.indexWhere(
      (e) => e.planId == ayah.planId && e.coordinate == ayah.coordinate,
    );
    i < 0 ? values.add(ayah) : values[i] = ayah;
    _data = MemorizationData(
      plans: _data.plans,
      ayahs: values,
      sessions: _data.sessions,
    );
    await _save();
  }

  Future<void> saveSession(MemorizationSession session) async {
    await load();
    final values = [..._data.sessions];
    final i = values.indexWhere((e) => e.id == session.id);
    i < 0 ? values.add(session) : values[i] = session;
    _data = MemorizationData(
      plans: _data.plans,
      ayahs: _data.ayahs,
      sessions: values,
    );
    await _save();
  }

  Future<List<MemorizationSession>> loadReviewHistory(String planId) async =>
      (await load()).sessions
          .where((e) => e.planId == planId && e.isCompleted)
          .toList();
  Future<void> deleteSession(String id) async {
    await load();
    _data = MemorizationData(
      plans: _data.plans,
      ayahs: _data.ayahs,
      sessions: _data.sessions.where((e) => e.id != id).toList(),
    );
    await _save();
  }

  Future<void> _save() => _store.write(
    jsonEncode({
      'version': schemaVersion,
      'plans': _data.plans.map((e) => e.toJson()).toList(),
      'ayahs': _data.ayahs.map((e) => e.toJson()).toList(),
      'sessions': _data.sessions.map((e) => e.toJson()).toList(),
    }),
  );
}
