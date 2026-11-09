import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/settings_controller.dart';
import '../../data/ids.dart';
import '../../data/models/subtask.dart';
import '../../data/models/tag.dart';
import '../../data/models/task.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../utils/dates.dart';
import '../../utils/vi_date.dart';
import '../settings/settings_labels.dart';
import '../settings/widgets/tag_edit_dialog.dart';
import 'task_form.dart';
import 'widgets/subtask_editor.dart';

/// Kết quả trả về khi đóng màn Thêm/sửa việc.
enum TaskEditResult { saved, deleted }

/// Thêm việc mới (không có [taskId]) hoặc sửa việc có sẵn.
///
/// Mở từ nút "+" ở Hôm nay (thêm), từ Lịch (thêm, kèm [initialDate]) và từ nút
/// sửa ở Chi tiết việc (sửa).
class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({
    super.key,
    this.taskId,
    this.initialDate,
    this.clock = DateTime.now,
  });

  /// Id việc cần sửa; `null` = thêm việc mới.
  final String? taskId;

  /// Ngày điền sẵn khi thêm việc mới (mặc định hôm nay).
  final DateTime? initialDate;

  /// Nguồn thời gian hiện tại; thay bằng giờ cố định khi test.
  final DateTime Function() clock;

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late final TaskRepository _tasks = context.read<TaskRepository>();
  late final TagRepository _tags = context.read<TagRepository>();
  late final Stream<List<Tag>> _tagStream = _tags.watchAll();

  final _title = TextEditingController();
  final _titleFocus = FocusNode();
  final _note = TextEditingController();
  final _newSubtask = TextEditingController();

  Task? _original;
  bool _loading = false;
  bool _notFound = false;
  bool _saving = false;

  DateTime? _date;
  bool _allDay = true;
  TimeOfDay? _start;
  TimeOfDay? _end;
  int? _reminder;
  RepeatRule _repeat = RepeatRule.none;
  Priority _priority = Priority.medium;
  String? _tagId;
  final _subtasks = <SubtaskDraft>[];
  TaskFormErrors _errors = const TaskFormErrors();

  bool get _editing => widget.taskId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _loading = true;
      _load();
    } else {
      _date = startOfDay(widget.initialDate ?? widget.clock());
      _reminder = context.read<SettingsController>().defaultReminderMinutes;
      // Đặt con trỏ vào ô Tiêu đề đúng một lần khi mở. Không dùng `autofocus`
      // của TextField: ô nằm trong danh sách cuộn nên bị tạo lại mỗi khi cuộn
      // ra rồi vào, và `autofocus` sẽ đòi lại con trỏ (bàn phím bật lên) mỗi
      // lần cuộn ngược lên đầu.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    _note.dispose();
    _newSubtask.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final task = await _tasks.getById(widget.taskId!);
    if (!mounted) return;
    if (task == null) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }
    final subtasks = await _tasks.getSubtasks(task.id);
    if (!mounted) return;
    final due = task.due;
    final end = task.end;
    setState(() {
      _original = task;
      _title.text = task.title;
      _note.text = task.note;
      _date = due == null ? null : startOfDay(due);
      _allDay = !task.hasTime;
      _start = task.hasTime && due != null ? TimeOfDay.fromDateTime(due) : null;
      _end = task.hasTime && end != null ? TimeOfDay.fromDateTime(end) : null;
      _reminder = task.reminderMinutes;
      _repeat = task.repeatRule;
      _priority = task.priority;
      _tagId = task.tagId;
      _subtasks.addAll([
        for (final s in subtasks)
          SubtaskDraft(id: s.id, title: s.title, done: s.done),
      ]);
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? startOfDay(widget.clock()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày',
    );
    if (picked != null) setState(() => _date = startOfDay(picked));
  }

  void _clearDate() => setState(() {
    _date = null;
    _repeat = RepeatRule.none;
  });

  void _setAllDay(bool allDay) => setState(() {
    _allDay = allDay;
    if (!allDay && _start == null) {
      _start = TimeOfDay(hour: (widget.clock().hour + 1) % 24, minute: 0);
    }
  });

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? _start ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: start ? 'Giờ bắt đầu' : 'Giờ kết thúc',
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  void _addSubtask() {
    final title = _newSubtask.text.trim();
    if (title.isEmpty) return;
    setState(() => _subtasks.add(SubtaskDraft(id: newId(), title: title)));
    _newSubtask.clear();
  }

  Future<void> _newTag(List<Tag> existing) async {
    final id = newId();
    await showTagEditDialog(
      context,
      title: 'Nhãn mới',
      tag: Tag(id: id, name: ''),
      existing: existing,
      onSave: (name, color) async {
        try {
          await _tags.add(Tag(id: id, name: name, color: color));
          return null;
        } on DuplicateTagNameException catch (e) {
          return e.toString();
        }
      },
    );
    if (!mounted) return;
    // Chọn luôn nhãn vừa tạo (nếu người dùng không hủy).
    if (await _tags.getById(id) != null && mounted) {
      setState(() => _tagId = id);
    }
  }

  Future<void> _save() async {
    // Việc con đang gõ dở trong ô nhập vẫn được lưu.
    _addSubtask();

    final errors = validateTaskForm(
      title: _title.text,
      date: _date,
      allDay: _allDay,
      start: _start,
      end: _end,
      repeat: _repeat,
    );
    setState(() => _errors = errors);
    if (errors.hasError) return;

    final original = _original;
    final id = original?.id ?? newId();
    final task = buildTask(
      id: id,
      createdAt: original?.createdAt ?? widget.clock(),
      title: _title.text,
      note: _note.text,
      date: _date,
      allDay: _allDay,
      start: _start,
      end: _end,
      reminderMinutes: _reminder,
      repeat: _repeat,
      priority: _priority,
      tagId: _tagId,
      done: original?.done ?? false,
      completedAt: original?.completedAt,
    );
    final subtasks = [
      for (final s in _subtasks)
        Subtask(id: s.id, taskId: id, title: s.title.trim(), done: s.done),
    ];

    setState(() => _saving = true);
    try {
      if (original == null) {
        await _tasks.add(task, subtasks: subtasks);
      } else {
        await _tasks.update(task, subtasks: subtasks);
      }
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        // Nhãn có thể đã bị xóa ở nơi khác trong lúc đang soạn.
        if (e.name == 'tagId') _tagId = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.name == 'tagId'
                  ? 'Nhãn đã bị xóa, hãy chọn nhãn khác'
                  : 'Không lưu được: ${e.message}',
            ),
          ),
        );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(TaskEditResult.saved);
  }

  Future<void> _delete() async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa việc này?'),
        content: Text(
          '"${_original!.title}" và các việc con của nó sẽ bị xóa vĩnh viễn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _tasks.delete(_original!.id);
    if (!mounted) return;
    Navigator.of(context).pop(TaskEditResult.deleted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Sửa việc' : 'Thêm việc'),
        actions: [
          TextButton(
            onPressed: _loading || _notFound || _saving ? null : _save,
            child: const Text('Lưu'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notFound
          ? const Center(child: Text('Không tìm thấy việc này'))
          : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = _date;
    final subtaskDone = _subtasks.where((s) => s.done).length;

    return ListView(
      // Kéo danh sách thì tự ẩn bàn phím.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _Field(
          label: 'Tiêu đề',
          child: TextField(
            controller: _title,
            focusNode: _titleFocus,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Bạn cần làm gì?',
              errorText: _errors.title,
            ),
            onChanged: (_) {
              if (_errors.title != null) {
                setState(() => _errors = const TaskFormErrors());
              }
            },
          ),
        ),
        _Field(
          label: 'Ghi chú',
          child: TextField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Thêm ghi chú'),
          ),
        ),
        _Field(
          label: 'Ngày',
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      date == null ? 'Không có ngày' : fullDate(date),
                    ),
                  ),
                ),
              ),
              if (date != null)
                IconButton(
                  tooltip: 'Bỏ ngày',
                  onPressed: _clearDate,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
        if (date != null)
          _Field(
            label: 'Giờ',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cả ngày'),
                  value: _allDay,
                  onChanged: _setAllDay,
                ),
                if (!_allDay)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => _pickTime(start: true),
                        child: Text(
                          _start == null ? 'Giờ bắt đầu' : _fmt(_start!),
                        ),
                      ),
                      const Text('→'),
                      OutlinedButton(
                        onPressed: () => _pickTime(start: false),
                        child: Text(
                          _end == null ? 'Giờ kết thúc' : _fmt(_end!),
                        ),
                      ),
                      if (_end != null)
                        IconButton(
                          tooltip: 'Bỏ giờ kết thúc',
                          onPressed: () => setState(() => _end = null),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                    ],
                  ),
                if (_errors.time != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _errors.time!,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
              ],
            ),
          ),
        _Field(
          label: 'Nhắc trước',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in reminderChoices)
                ChoiceChip(
                  label: Text(reminderLabel(minutes)),
                  selected: _reminder == minutes,
                  // Bấm lại mức đang chọn để bỏ nhắc.
                  onSelected: (selected) =>
                      setState(() => _reminder = selected ? minutes : null),
                ),
            ],
          ),
        ),
        _Field(
          label: 'Lặp lại',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<RepeatRule>(
                  showSelectedIcon: false,
                  segments: [
                    for (final rule in RepeatRule.values)
                      ButtonSegment(value: rule, label: Text(rule.label)),
                  ],
                  selected: {_repeat},
                  onSelectionChanged: date == null
                      ? null
                      : (set) => setState(() => _repeat = set.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _errors.repeat ??
                      repeatDescription(
                        date,
                        _allDay ? null : _start,
                        _repeat,
                      ) ??
                      (date == null ? 'Chọn ngày để đặt lặp lại' : ''),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _errors.repeat != null
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        _Field(
          label: 'Mức ưu tiên',
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<Priority>(
              showSelectedIcon: false,
              segments: [
                for (final p in Priority.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_priority},
              onSelectionChanged: (set) =>
                  setState(() => _priority = set.first),
            ),
          ),
        ),
        _Field(
          label: 'Nhãn',
          child: StreamBuilder<List<Tag>>(
            stream: _tagStream,
            builder: (context, snapshot) {
              final tags = snapshot.data ?? const <Tag>[];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags)
                    ChoiceChip(
                      label: Text(tag.name),
                      selected: _tagId == tag.id,
                      // Mỗi việc chỉ có một nhãn; bấm lại để bỏ nhãn.
                      onSelected: (selected) =>
                          setState(() => _tagId = selected ? tag.id : null),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nhãn mới'),
                    onPressed: () => _newTag(tags),
                  ),
                ],
              );
            },
          ),
        ),
        _Field(
          label: 'Việc con · $subtaskDone/${_subtasks.length}',
          child: SubtaskEditor(
            drafts: _subtasks,
            controller: _newSubtask,
            onToggle: (d) => setState(() => d.done = !d.done),
            onRemove: (d) => setState(() => _subtasks.remove(d)),
            onAdd: _addSubtask,
          ),
        ),
        if (_editing) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Xóa việc'),
          ),
        ],
      ],
    );
  }

  String _fmt(TimeOfDay t) =>
      hourMinute(DateTime(2000, 1, 1, t.hour, t.minute));
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
