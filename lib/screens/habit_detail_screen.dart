import 'package:flutter/material.dart';

import '../models/habit.dart';
import 'habit_form_screen.dart';
import 'habit_timer_screen.dart';

class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({
    super.key,
    required this.habit,
    required this.onHabitUpdated,
    required this.onHabitDeleted,
  });

  final Habit habit;
  final ValueChanged<Habit> onHabitUpdated;
  final VoidCallback onHabitDeleted;

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  late Habit _habit;

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
  }

  void _editHabit() async {
    final updated = await Navigator.push<Habit>(
      context,
      MaterialPageRoute(builder: (_) => HabitFormScreen(habit: _habit)),
    );
    if (updated != null) {
      setState(() => _habit = updated);
      widget.onHabitUpdated(updated);
    }
  }

  void _toggleArchive() {
    final updated = _habit.copyWith(isArchived: !_habit.isArchived);
    setState(() => _habit = updated);
    widget.onHabitUpdated(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final isDone = _habit.isCompletedToday(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết thói quen'),
        actions: [
          IconButton(
            icon: Icon(
              _habit.isArchived
                  ? Icons.unarchive_rounded
                  : Icons.archive_outlined,
            ),
            tooltip: _habit.isArchived ? 'Bỏ lưu trữ' : 'Lưu trữ',
            onPressed: _toggleArchive,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Sửa',
            onPressed: _editHabit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Xóa',
            onPressed: () {
              widget.onHabitDeleted();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                IconData(_habit.iconCode, fontFamily: 'MaterialIcons'),
                size: 40,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _habit.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_habit.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                _habit.description,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Chuỗi hiện tại',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_habit.streak} ngày 🔥',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Thời lượng', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '${_habit.durationMinutes} phút ⏱️',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HabitTimerScreen(
                    habit: _habit,
                    onFinished: () {
                      final updated = _habit.toggleToday(DateTime.now());
                      setState(() => _habit = updated);
                      widget.onHabitUpdated(updated);
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.timer_rounded),
            label: const Text('Bắt đầu bấm giờ thói quen'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              final updated = _habit.toggleToday(now);
              setState(() => _habit = updated);
              widget.onHabitUpdated(updated);
            },
            icon: Icon(
              isDone
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
            ),
            label: Text(
              isDone
                  ? 'Đã hoàn thành hôm nay (Chạm để hủy)'
                  : 'Đánh dấu đã hoàn thành',
            ),
          ),
        ],
      ),
    );
  }
}
