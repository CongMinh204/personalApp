import 'package:flutter/material.dart';

import '../models/task.dart';

/// Mở sheet thêm nhanh; trả về [Task] mới (hạn hôm nay) hoặc `null` nếu hủy.
Future<Task?> showQuickAddSheet(BuildContext context, {required DateTime now}) {
  return showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => QuickAddSheet(now: now),
  );
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key, required this.now});

  final DateTime now;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  TaskTag _tag = TaskTag.personal;
  Priority _priority = Priority.medium;
  TimeOfDay? _time;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _time ??
          TimeOfDay.fromDateTime(widget.now.add(const Duration(hours: 1))),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = widget.now;
    final time = _time;
    final task = Task(
      id: 'task-${DateTime.now().microsecondsSinceEpoch}',
      title: _titleController.text.trim(),
      tag: _tag,
      due: DateTime(
        now.year,
        now.month,
        now.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      ),
      hasTime: time != null,
      priority: _priority,
    );
    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = _time;
    final sectionStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thêm việc nhanh',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Bạn cần làm gì?'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Vui lòng nhập tên việc'
                  : null,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Text('Nhãn', style: sectionStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in TaskTag.values)
                  ChoiceChip(
                    label: Text(tag.label),
                    selected: _tag == tag,
                    onSelected: (_) => setState(() => _tag = tag),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Ưu tiên', style: sectionStyle),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<Priority>(
                showSelectedIcon: false,
                segments: [
                  for (final p in Priority.values)
                    ButtonSegment(value: p, label: Text(p.label)),
                ],
                selected: {_priority},
                onSelectionChanged: (selection) =>
                    setState(() => _priority = selection.first),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(
                    time == null
                        ? 'Chọn giờ'
                        : MaterialLocalizations.of(
                            context,
                          ).formatTimeOfDay(time, alwaysUse24HourFormat: true),
                  ),
                ),
                if (time != null)
                  IconButton(
                    tooltip: 'Bỏ giờ',
                    onPressed: () => setState(() => _time = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                const Spacer(),
                FilledButton(onPressed: _save, child: const Text('Lưu')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
