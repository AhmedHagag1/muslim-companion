import 'package:flutter/foundation.dart';

import '../../data/models/religious_content.dart';
import '../../data/models/tasbeeh.dart';
import '../../data/repositories/tasbeeh_repository.dart';

class TasbeehController extends ChangeNotifier {
  TasbeehController({TasbeehRepository? repository, DateTime Function()? clock})
    : _repository = repository ?? TasbeehRepository(),
      _clock = clock ?? DateTime.now;

  final TasbeehRepository _repository;
  final DateTime Function() _clock;
  List<TasbeehPhrase> phrases = const [];
  TasbeehState? state;
  ReligiousContentManifest? manifest;
  bool loading = false;
  String? error;

  TasbeehPhrase? get selectedPhrase {
    final current = state;
    if (current == null) return null;
    return phrases.where((item) => item.id == current.phraseId).firstOrNull;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final pack = await _repository.loadContent();
      phrases = pack.tasbeehPhrases;
      manifest = pack.manifest;
      final saved = await _repository.loadState();
      state = saved != null && phrases.any((item) => item.id == saved.phraseId)
          ? saved.copyWith(
              history: saved.history
                  .where((entry) => phrases.any((p) => p.id == entry.phraseId))
                  .take(10)
                  .toList(),
            )
          : _initialState();
      await _persist();
    } catch (_) {
      error = 'تعذر تحميل السبحة المحفوظة على الجهاز.';
      phrases = const [];
      state = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  TasbeehState _initialState() {
    final phrase = phrases.first;
    return TasbeehState(
      phraseId: phrase.id,
      count: 0,
      target: phrase.suggestedTarget,
      updatedAt: _clock().toUtc(),
      history: const [],
    );
  }

  Future<void> increment() async {
    final current = state;
    if (current == null) return;
    state = current.copyWith(
      count: current.count + 1,
      updatedAt: _clock().toUtc(),
    );
    await _persist();
  }

  Future<void> decrement() async {
    final current = state;
    if (current == null || current.count == 0) return;
    state = current.copyWith(
      count: current.count - 1,
      updatedAt: _clock().toUtc(),
    );
    await _persist();
  }

  Future<void> selectPhrase(String id) async {
    final phrase = phrases.where((item) => item.id == id).firstOrNull;
    final current = state;
    if (phrase == null || current == null || current.phraseId == id) return;
    final history = _withCurrentInHistory(current);
    state = TasbeehState(
      phraseId: phrase.id,
      count: 0,
      target: phrase.suggestedTarget,
      updatedAt: _clock().toUtc(),
      history: history,
    );
    await _persist();
  }

  Future<void> setTarget(int? target) async {
    if (target != null && target < 1) throw ArgumentError('Invalid target');
    final current = state;
    if (current == null) return;
    state = current.copyWith(target: target, updatedAt: _clock().toUtc());
    await _persist();
  }

  Future<void> reset() async {
    final current = state;
    if (current == null) return;
    state = current.copyWith(
      count: 0,
      updatedAt: _clock().toUtc(),
      history: _withCurrentInHistory(current),
    );
    await _persist();
  }

  List<TasbeehHistoryEntry> _withCurrentInHistory(TasbeehState current) {
    if (current.count == 0) return current.history;
    return [
      TasbeehHistoryEntry(
        phraseId: current.phraseId,
        count: current.count,
        completedAt: _clock().toUtc(),
      ),
      ...current.history,
    ].take(10).toList();
  }

  Future<void> _persist() async {
    final current = state;
    if (current != null) await _repository.saveState(current);
    notifyListeners();
  }
}
