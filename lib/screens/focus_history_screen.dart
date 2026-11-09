import 'package:flutter/material.dart';

import '../data/focus_session_repository.dart';
import '../models/focus_session.dart';
import '../utils/timer_format.dart';
import '../utils/vi_date.dart';

/// Lịch sử tập trung (mockup FocusHistory): thẻ tổng kết hôm nay,
/// bộ lọc Ngày / Tuần / Tháng, danh sách phiên nhóm theo ngày.
class FocusHistoryScreen extends StatefulWidget {
  const FocusHistoryScreen({super.key, required this.repository});

  final FocusSessionRepository repository;

  @override
  State<FocusHistoryScreen> createState() => _FocusHistoryScreenState();
}

class _HistoryData {
  _HistoryData(this.sessions, this.weekSeconds);
  final List<FocusSession> sessions; // trong khoảng đang chọn
  final int weekSeconds; // tổng giây tập trung từ đầu tuần (Thứ Hai)
}

class _FocusHistoryScreenState extends State<FocusHistoryScreen> {
  // Ngày = hôm nay + hôm qua (như mockup), Tuần = 7 ngày, Tháng = 30 ngày.
  static const _labels = ['Ngày', 'Tuần', 'Tháng'];
  static const _daysBack = [1, 6, 29];

  int _range = 0;
  late Future<_HistoryData> _future = _load();

  Future<_HistoryData> _load() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = today.subtract(Duration(days: _daysBack[_range]));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final sessions = await widget.repository.getSince(from);
    final week = await widget.repository.getSince(weekStart);
    return _HistoryData(
      sessions,
      week.fold<int>(0, (sum, s) => sum + s.durationSec),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lịch sử tập trung',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<_HistoryData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Không tải được lịch sử',
                style: TextStyle(color: cs.error),
              ),
            );
          }
          final data = snap.data!;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          final todaySessions = data.sessions
              .where((s) => !s.startedAt.isBefore(today))
              .toList();
          final todaySeconds = todaySessions.fold<int>(
            0,
            (a, s) => a + s.durationSec,
          );
          final todayDone = todaySessions.where((s) => s.completed).length;

          // Nhóm theo ngày (danh sách đã sắp mới nhất trước)
          final groups = <DateTime, List<FocusSession>>{};
          for (final s in data.sessions) {
            final d = DateTime(
              s.startedAt.year,
              s.startedAt.month,
              s.startedAt.day,
            );
            groups.putIfAbsent(d, () => []).add(s);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _SummaryCard(
                todaySeconds: todaySeconds,
                sessions: todaySessions.length,
                done: todayDone,
                weekSeconds: data.weekSeconds,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (var i = 0; i < _labels.length; i++)
                      ButtonSegment(value: i, label: Text(_labels[i])),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() {
                    _range = s.first;
                    _future = _load();
                  }),
                ),
              ),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text(
                      'Chưa có phiên tập trung nào',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              for (final e in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
                  child: Text(
                    fmtDayTitle(e.key, now).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < e.value.length; i++)
                        _SessionRow(session: e.value[i], first: i == 0),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.todaySeconds,
    required this.sessions,
    required this.done,
    required this.weekSeconds,
  });

  final int todaySeconds;
  final int sessions;
  final int done;
  final int weekSeconds;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      ('Phiên', '$sessions'),
      ('Hoàn thành', '$done/$sessions'),
      ('Tuần này', fmtTotal(weekSeconds)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: cs.onPrimary),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hôm nay',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  fmtTotal(todaySeconds),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.onPrimary.withAlpha(77), // ~30%
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].$1,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].$2,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < items.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.first});

  final FocusSession session;
  final bool first;

  static String _kind(SessionType t) => switch (t) {
    SessionType.pomodoro => 'Pomodoro',
    SessionType.shortBreak => 'Nghỉ ngắn',
    SessionType.longBreak => 'Nghỉ dài',
    SessionType.custom => 'Tùy chỉnh',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ok = session.completed;
    final hasTask = session.taskTitle != null;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ok ? context.okBg : context.badBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              ok ? Icons.check_rounded : Icons.close_rounded,
              size: 20,
              color: ok ? context.okFg : context.badFg,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.taskTitle ?? 'Không gắn việc',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: hasTask ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${hourMinute(session.startedAt)} – ${hourMinute(session.endedAt)} · ${_kind(session.type)}',
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtMinutes(session.durationSec),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                ok ? 'Hoàn thành' : 'Bỏ dở',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: ok ? context.okFg : context.badFg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
