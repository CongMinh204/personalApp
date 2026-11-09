import 'package:flutter/material.dart';

import '../models/habit.dart';
import 'habit_form_screen.dart';
import 'habit_detail_screen.dart';
import 'habit_timer_screen.dart';
import 'habit_archive_screen.dart';

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  final List<Habit> _habits = [
    const Habit(
      id: 'h1',
      title: 'Đọc sách 20 trang',
      iconCode: 0xe11e,
      streak: 5,
      durationMinutes: 20,
    ),
    const Habit(
      id: 'h2',
      title: 'Uống 2 lít nước',
      iconCode: 0xe6df,
      streak: 12,
      durationMinutes: 5,
    ),
    const Habit(
      id: 'h3',
      title: 'Tập thể dục 30 phút',
      iconCode: 0xe28d,
      streak: 2,
      durationMinutes: 30,
    ),
  ];

  void _toggle(Habit habit) {
    final index = _habits.indexWhere((h) => h.id == habit.id);
    if (index < 0) return;
    setState(() {
      _habits[index] = _habits[index].toggleToday(DateTime.now());
    });
  }

  void _updateHabit(Habit updated) {
    final index = _habits.indexWhere((h) => h.id == updated.id);
    if (index < 0) return;
    setState(() => _habits[index] = updated);
  }

  void _deleteHabit(Habit habit) {
    setState(() => _habits.removeWhere((h) => h.id == habit.id));
  }

  // Tạo mới bằng dấu "+"
  Future<void> _addNewHabit() async {
    final newHabit = await Navigator.push<Habit>(
      context,
      MaterialPageRoute(builder: (_) => const HabitFormScreen()),
    );
    if (newHabit != null) {
      setState(() => _habits.add(newHabit));
    }
  }

  // Mở màn hình Chi tiết
  void _openDetail(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HabitDetailScreen(
          habit: habit,
          onHabitUpdated: _updateHabit,
          onHabitDeleted: () => _deleteHabit(habit),
        ),
      ),
    );
  }

  // Mở Kho lưu trữ
  void _openArchive() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HabitArchiveScreen(
          archivedHabits: _habits.where((h) => h.isArchived).toList(),
          onUnarchive: (habit) {
            _updateHabit(habit.copyWith(isArchived: false));
          },
          onDeletePermanent: _deleteHabit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final activeHabits = _habits.where((h) => !h.isArchived).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thói quen mỗi ngày'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Kho lưu trữ',
            onPressed: _openArchive,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tạo thói quen mới',
        onPressed: _addNewHabit,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: activeHabits.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Chưa có thói quen nào đang hoạt động'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _addNewHabit,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm thói quen đầu tiên'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
              itemCount: activeHabits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final habit = activeHabits[index];
                final doneToday = habit.isCompletedToday(now);

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    onTap: () => _openDetail(habit),
                    leading: CircleAvatar(
                      backgroundColor: doneToday
                          ? Colors.green.withValues(alpha: 0.2)
                          : theme.colorScheme.primaryContainer,
                      child: Icon(
                        IconData(habit.iconCode, fontFamily: 'MaterialIcons'),
                        color: doneToday
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      habit.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Đang giữ chuỗi ${habit.streak} ngày liên tiếp 🔥 · ${habit.durationMinutes} phút',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bấm giờ nhanh
                        IconButton(
                          icon: const Icon(Icons.timer_outlined),
                          tooltip: 'Bấm giờ',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HabitTimerScreen(
                                  habit: habit,
                                  onFinished: () => _toggle(habit),
                                ),
                              ),
                            );
                          },
                        ),
                        // Đánh dấu hoàn thành
                        IconButton(
                          icon: Icon(
                            doneToday
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: doneToday ? Colors.green : null,
                            size: 28,
                          ),
                          onPressed: () => _toggle(habit),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
