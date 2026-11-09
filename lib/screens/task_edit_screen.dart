import 'package:flutter/material.dart';

import '../models/task.dart';

class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({super.key, this.task});

  final Task? task; // null nếu là tạo mới

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  late TaskTag _selectedTag;
  late Priority _selectedPriority;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? '');
    _noteController = TextEditingController(text: t?.note ?? '');
    _selectedTag = t?.tag ?? TaskTag.personal;
    _selectedPriority = t?.priority ?? Priority.medium;
    _dueDate = t?.due;
    if (t != null && t.hasTime && t.due != null) {
      _dueTime = TimeOfDay.fromDateTime(t.due!);
      if (t.end != null) {
        _endTime = TimeOfDay.fromDateTime(t.end!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _dueTime : _endTime) ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _dueTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    DateTime? finalDue = _dueDate;
    DateTime? finalEnd;
    final hasTime = _dueTime != null;

    if (finalDue != null && hasTime) {
      finalDue = DateTime(
        finalDue.year,
        finalDue.month,
        finalDue.day,
        _dueTime!.hour,
        _dueTime!.minute,
      );

      if (_endTime != null) {
        finalEnd = DateTime(
          finalDue.year,
          finalDue.month,
          finalDue.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      }
    }

    final taskResult = Task(
      id: widget.task?.id ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      tag: _selectedTag,
      priority: _selectedPriority,
      due: finalDue,
      end: finalEnd,
      hasTime: hasTime,
      done: widget.task?.done ?? false,
      isArchived: widget.task?.isArchived ?? false,
      note: _noteController.text.trim(),
    );

    Navigator.pop(context, taskResult);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.task != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Sửa công việc' : 'Thêm công việc'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Lưu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tên công việc',
                hintText: 'Nhập tên công việc...',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập tên việc'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú / Chi tiết',
                hintText: 'Thêm ghi chú, link tài liệu...',
              ),
            ),
            const SizedBox(height: 24),
            Text('Nhãn phân loại', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TaskTag.values.map((tag) {
                final isSelected = _selectedTag == tag;
                return ChoiceChip(
                  label: Text(tag.label),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedTag = tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Độ ưu tiên', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<Priority>(
              segments: Priority.values.map((p) {
                return ButtonSegment(value: p, label: Text(p.label));
              }).toList(),
              selected: {_selectedPriority},
              onSelectionChanged: (val) =>
                  setState(() => _selectedPriority = val.first),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_rounded),
              title: Text(
                _dueDate == null
                    ? 'Chưa đặt ngày'
                    : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
              ),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Chọn ngày'),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time_rounded),
              title: Text(
                _dueTime == null
                    ? 'Không đặt giờ'
                    : '${_dueTime!.format(context)}' +
                          (_endTime != null
                              ? ' - ${_endTime!.format(context)}'
                              : ''),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _pickTime(isStart: true),
                    child: const Text('Bắt đầu'),
                  ),
                  TextButton(
                    onPressed: () => _pickTime(isStart: false),
                    child: const Text('Kết thúc'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
