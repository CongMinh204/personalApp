import 'package:flutter/material.dart';

import '../models/task.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({
    super.key,
    required this.archivedTasks,
    required this.onUnarchive,
    required this.onDeletePermanent,
  });

  final List<Task> archivedTasks;
  final ValueChanged<Task> onUnarchive;
  final ValueChanged<Task> onDeletePermanent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kho lưu trữ')),
      body: archivedTasks.isEmpty
          ? const Center(child: Text('Chưa có công việc nào được lưu trữ'))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: archivedTasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = archivedTasks[index];
                return ListTile(
                  tileColor: Theme.of(context).cardTheme.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(task.title),
                  subtitle: Text(task.tag.label),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.unarchive_rounded),
                        tooltip: 'Khôi phục',
                        onPressed: () => onUnarchive(task),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.red,
                        ),
                        tooltip: 'Xóa vĩnh viễn',
                        onPressed: () => onDeletePermanent(task),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
