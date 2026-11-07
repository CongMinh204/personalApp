import 'package:flutter/material.dart' show DateTimeRange;

import '../../utils/dates.dart';
import '../models/focus_session.dart';
import '../repositories/focus_repository.dart';
import 'fake_store.dart';

class FakeFocusRepository implements FocusRepository {
  FakeFocusRepository(this._store);

  final FakeStore _store;

  @override
  Future<void> add(FocusSession session) async {
    final taskId = session.taskId;
    if (taskId != null && !_store.tasks.containsKey(taskId)) {
      throw ArgumentError.value(taskId, 'taskId', 'Việc không tồn tại');
    }
    if (_store.sessions.containsKey(session.id)) {
      throw StateError('Phiên ${session.id} đã tồn tại');
    }
    _store.sessions[session.id] = session;
    _store.notifyChanged();
  }

  @override
  Future<List<FocusSession>> sessionsByRange(DateTimeRange range) async =>
      _inRange(range);

  @override
  Stream<List<FocusSession>> watchByRange(DateTimeRange range) =>
      _store.watch(() => List.unmodifiable(_inRange(range)));

  @override
  Future<FocusTotal> totalForTask(String taskId) async {
    var seconds = 0;
    var sessions = 0;
    for (final session in _store.sessions.values) {
      if (session.taskId != taskId || !session.type.isFocus) continue;
      seconds += session.durationSec;
      sessions++;
    }
    return FocusTotal(seconds: seconds, sessions: sessions);
  }

  @override
  Future<void> delete(String id) async {
    if (_store.sessions.remove(id) == null) return;
    _store.notifyChanged();
  }

  List<FocusSession> _inRange(DateTimeRange range) =>
      _store.sessions.values
          .where((s) => rangeContains(range, s.startedAt))
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
}
