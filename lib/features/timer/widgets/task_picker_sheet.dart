import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../utils/vi_date.dart';

/// Việc được chọn trong bảng chọn việc. [id] `null` = Không gắn việc.
class TaskChoice {
  const TaskChoice(this.id, this.title);

  final String? id;
  final String? title;
}

/// Bảng chọn việc cho phiên tập trung: "Không gắn việc" và các việc chưa xong.
/// Trả về `null` nếu người dùng đóng bảng mà không chọn.
Future<TaskChoice?> showTaskPicker(
  BuildContext context, {
  required String? selectedId,
}) {
  return showModalBottomSheet<TaskChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _TaskPickerSheet(selectedId: selectedId),
  );
}

class _TaskPickerSheet extends StatelessWidget {
  const _TaskPickerSheet({required this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Tập trung cho việc nào?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: FutureBuilder<List<Task>>(
                future: context.read<TaskRepository>().getUnfinished(),
                builder: (context, snapshot) {
                  final tasks = snapshot.data ?? const <Task>[];
                  return RadioGroup<String?>(
                    groupValue: selectedId,
                    onChanged: (id) {
                      final title = tasks
                          .where((t) => t.id == id)
                          .map((t) => t.title)
                          .firstOrNull;
                      Navigator.of(context).pop(TaskChoice(id, title));
                    },
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        const RadioListTile<String?>(
                          value: null,
                          title: Text('Không gắn việc'),
                        ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        for (final task in tasks)
                          RadioListTile<String?>(
                            value: task.id,
                            title: Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(taskTimeLabel(task, now)),
                          ),
                        if (snapshot.connectionState == ConnectionState.done &&
                            tasks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                            child: Text(
                              'Chưa có việc nào chưa xong.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
