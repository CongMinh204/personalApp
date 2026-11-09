import 'dart:async';

import 'package:flutter/material.dart';

import '../data/focus_session_repository.dart';
import '../logic/countdown_controller.dart';
import '../logic/stopwatch_controller.dart';
import '../utils/timer_format.dart';
import 'countdown_view.dart';
import 'focus_history_screen.dart';
import 'stopwatch_view.dart';

/// Màn Hẹn giờ (tab D). Chỉ là phần thân: thanh điều hướng dưới do shell của app lo.
///
/// Controller và repository do [HomeShell] tạo để đồng hồ không bị reset khi
/// đổi tab.
///
/// [loadTasks]: trả về các việc chưa xong để chọn trong thẻ
/// "Đang tập trung cho" (UC12 bước 2).
class TimerScreen extends StatefulWidget {
  const TimerScreen({
    super.key,
    required this.countdown,
    required this.stopwatch,
    required this.repository,
    required this.loadTasks,
  });

  final CountdownController countdown;
  final StopwatchController stopwatch;
  final FocusSessionRepository repository;
  final Future<List<TaskRef>> Function() loadTasks;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int _tab = 0; // 0 = Đếm ngược, 1 = Bấm giờ
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    // Hết phiên khi đang mở app: báo bằng SnackBar (thông báo hệ thống do OS lo).
    _sub = widget.countdown.events.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _pickTask() async {
    final controller = widget.countdown;
    final picked = await showModalBottomSheet<_Pick>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _TaskPickerSheet(
        loadTasks: widget.loadTasks,
        selectedId: controller.task?.id,
      ),
    );
    if (picked != null) controller.selectTask(picked.task);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Hẹn giờ',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Lịch sử tập trung',
                  icon: const Icon(Icons.history_rounded),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(44, 44),
                    backgroundColor: context.cardColor,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FocusHistoryScreen(repository: widget.repository),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.hourglass_bottom_rounded, size: 18),
                    label: Text('Đếm ngược'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.timer_outlined, size: 18),
                    label: Text('Bấm giờ'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ),
          Expanded(
            child: _tab == 0
                ? CountdownView(
                    controller: widget.countdown,
                    onPickTask: _pickTask,
                  )
                : StopwatchView(controller: widget.stopwatch),
          ),
        ],
      ),
    );
  }
}

/// Bọc kết quả để phân biệt "chọn Không gắn việc" (task = null) với "đóng sheet".
class _Pick {
  const _Pick(this.task);
  final TaskRef? task;
}

class _TaskPickerSheet extends StatelessWidget {
  const _TaskPickerSheet({required this.loadTasks, required this.selectedId});

  final Future<List<TaskRef>> Function() loadTasks;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: FutureBuilder<List<TaskRef>>(
          future: loadTasks(),
          builder: (context, snap) {
            final tasks = snap.data ?? const <TaskRef>[];
            return ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Chọn việc để tập trung',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.block_rounded),
                  title: const Text('Không gắn việc'),
                  trailing: selectedId == null
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : null,
                  onTap: () => Navigator.pop(context, const _Pick(null)),
                ),
                if (snap.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Chưa có việc nào để chọn',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                for (final t in tasks)
                  ListTile(
                    leading: const Icon(Icons.radio_button_unchecked_rounded),
                    title: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: t.id == selectedId
                        ? Icon(Icons.check_rounded, color: cs.primary)
                        : null,
                    onTap: () => Navigator.pop(context, _Pick(t)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
