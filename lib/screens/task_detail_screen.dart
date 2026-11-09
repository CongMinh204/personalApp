import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/vi_date.dart';
import 'task_edit_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
  });

  final Task task;
  final ValueChanged<Task> onTaskUpdated;
  final VoidCallback onTaskDeleted;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  void _editTask() async {
    final updated = await Navigator.push<Task>(
      context,
      MaterialPageRoute(builder: (_) => TaskEditScreen(task: _task)),
    );
    if (updated != null) {
      setState(() => _task = updated);
      widget.onTaskUpdated(updated);
    }
  }

  void _toggleArchive() {
    final updated = _task.copyWith(isArchived: !_task.isArchived);
    setState(() => _task = updated);
    widget.onTaskUpdated(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        actions: [
          IconButton(
            icon: Icon(
              _task.isArchived
                  ? Icons.unarchive_rounded
                  : Icons.archive_outlined,
            ),
            tooltip: _task.isArchived ? 'Bỏ lưu trữ' : 'Lưu trữ',
            onPressed: _toggleArchive,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Sửa',
            onPressed: _editTask,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Xóa',
            onPressed: () {
              widget.onTaskDeleted();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _task.done,
                onChanged: (val) {
                  final updated = _task.copyWith(done: val ?? false);
                  setState(() => _task = updated);
                  widget.onTaskUpdated(updated);
                },
              ),
              Expanded(
                child: Text(
                  _task.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    decoration: _task.done ? TextDecoration.lineThrough : null,
                    color: _task.done ? scheme.outline : scheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Nhãn: ${_task.tag.label}')),
              Chip(label: Text('Ưu tiên: ${_task.priority.label}')),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded),
                      const SizedBox(width: 12),
                      Text(taskTimeLabel(_task, DateTime.now())),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Ghi chú',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _task.note.isNotEmpty
                  ? _task.note
                  : 'Chưa có ghi chú nào cho việc này.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
