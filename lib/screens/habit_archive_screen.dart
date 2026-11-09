import 'package:flutter/material.dart';

import '../models/habit.dart';

class HabitArchiveScreen extends StatelessWidget {
  const HabitArchiveScreen({
    super.key,
    required this.archivedHabits,
    required this.onUnarchive,
    required this.onDeletePermanent,
  });

  final List<Habit> archivedHabits;
  final ValueChanged<Habit> onUnarchive;
  final ValueChanged<Habit> onDeletePermanent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kho lưu trữ thói quen')),
      body: archivedHabits.isEmpty
          ? const Center(
              child: Text('Không có thói quen nào trong kho lưu trữ'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: archivedHabits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final habit = archivedHabits[index];
                return ListTile(
                  tileColor: Theme.of(context).cardTheme.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: CircleAvatar(
                    child: Icon(
                      IconData(habit.iconCode, fontFamily: 'MaterialIcons'),
                    ),
                  ),
                  title: Text(
                    habit.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Chuỗi: ${habit.streak} ngày'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.unarchive_rounded),
                        tooltip: 'Khôi phục',
                        onPressed: () => onUnarchive(habit),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.red,
                        ),
                        tooltip: 'Xóa vĩnh viễn',
                        onPressed: () => onDeletePermanent(habit),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
