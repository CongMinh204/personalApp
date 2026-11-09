import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/ids.dart';
import '../../data/models/habit.dart';
import '../../data/repositories/habit_repository.dart';
import '../../utils/dates.dart';
import '../../utils/vi_date.dart';
import 'habit_logic.dart';
import 'widgets/habit_pickers.dart';

/// Kết quả trả về khi đóng màn Thêm/sửa thói quen.
enum HabitEditResult { saved, archived, deleted }

/// Thêm thói quen mới (không có [habitId]) hoặc sửa thói quen có sẵn.
class HabitEditScreen extends StatefulWidget {
  const HabitEditScreen({super.key, this.habitId, this.clock = DateTime.now});

  /// Id thói quen cần sửa; `null` = thêm mới.
  final String? habitId;

  /// Nguồn thời gian hiện tại; thay bằng giờ cố định khi test.
  final DateTime Function() clock;

  @override
  State<HabitEditScreen> createState() => _HabitEditScreenState();
}

class _HabitEditScreenState extends State<HabitEditScreen> {
  late final HabitRepository _repo = context.read<HabitRepository>();

  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _unit = TextEditingController();

  Habit? _original;
  bool _loading = false;
  bool _notFound = false;
  bool _saving = false;

  String _icon = habitIcons.first.key;
  Color _color = habitColors.first.color;
  Set<int> _days = {1, 2, 3, 4, 5, 6, 7};
  int _goal = 1;
  TimeOfDay? _reminder;
  late DateTime _startDate;
  HabitFormErrors _errors = const HabitFormErrors();

  bool get _editing => widget.habitId != null;
  bool get _everyDay => _days.length == 7;

  @override
  void initState() {
    super.initState();
    _startDate = startOfDay(widget.clock());
    if (_editing) {
      _loading = true;
      _load();
    } else {
      // Đặt con trỏ vào ô tên đúng một lần khi mở (không dùng autofocus vì ô
      // nằm trong danh sách cuộn, sẽ đòi lại con trỏ mỗi lần cuộn ngược lên).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final habit = await _repo.getById(widget.habitId!);
    if (!mounted) return;
    if (habit == null) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }
    setState(() {
      _original = habit;
      _name.text = habit.name;
      _unit.text = habit.unit;
      _icon = habit.icon;
      _color = habit.color;
      _days = Set.of(habit.repeatDays);
      _goal = habit.goalPerDay;
      _reminder = habit.reminderTime;
      _startDate = startOfDay(habit.startDate);
      _loading = false;
    });
  }

  void _setEveryDay(bool every) => setState(() {
    if (every) {
      _days = {1, 2, 3, 4, 5, 6, 7};
    } else if (_everyDay) {
      // Chuyển sang chọn thứ: bắt đầu bằng thứ của hôm nay.
      _days = {widget.clock().weekday};
    }
    _errors = const HabitFormErrors();
  });

  void _toggleDay(int weekday, bool on) => setState(() {
    on ? _days.add(weekday) : _days.remove(weekday);
    _errors = const HabitFormErrors();
  });

  void _setGoal(int goal) {
    final (min, max) = habitGoalRange;
    setState(() {
      _goal = goal.clamp(min, max);
      _errors = const HabitFormErrors();
    });
  }

  Future<void> _pickReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminder ?? defaultHabitReminder,
      helpText: 'Giờ nhắc',
    );
    if (picked != null) setState(() => _reminder = picked);
  }

  Future<void> _pickStartDate() async {
    final today = startOfDay(widget.clock());
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isAfter(today) ? today : _startDate,
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: 'Ngày bắt đầu',
    );
    if (picked != null) setState(() => _startDate = startOfDay(picked));
  }

  Future<void> _save() async {
    final errors = validateHabitForm(
      name: _name.text,
      days: _days,
      goal: _goal,
    );
    setState(() => _errors = errors);
    if (errors.hasError) return;

    final original = _original;
    final habit = buildHabit(
      id: original?.id ?? newId(),
      name: _name.text,
      icon: _icon,
      color: _color,
      repeatDays: _days,
      goalPerDay: _goal,
      unit: _unit.text,
      reminderTime: _reminder,
      startDate: _startDate,
      archivedAt: original?.archivedAt,
    );

    setState(() => _saving = true);
    if (original == null) {
      await _repo.add(habit);
    } else {
      await _repo.update(habit);
    }
    if (!mounted) return;
    Navigator.of(context).pop(HabitEditResult.saved);
  }

  Future<void> _archive() async {
    final habit = _original!;
    final messenger = ScaffoldMessenger.of(context);
    await _repo.setArchived(habit.id, true);
    if (!mounted) return;
    Navigator.of(context).pop(HabitEditResult.archived);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã lưu trữ "${habit.name}"'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => _repo.setArchived(habit.id, false),
          ),
        ),
      );
  }

  Future<void> _delete() async {
    final habit = _original!;
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thói quen này?'),
        content: Text(
          'Toàn bộ nhật ký và chuỗi ngày của "${habit.name}" sẽ bị xóa vĩnh '
          'viễn. Không thể hoàn tác. Nếu chỉ muốn ẩn đi, hãy chọn Lưu trữ.',
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
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await _repo.delete(habit.id);
    if (!mounted) return;
    Navigator.of(context).pop(HabitEditResult.deleted);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Đã xóa "${habit.name}"')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Sửa thói quen' : 'Thêm thói quen'),
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
          ? const Center(child: Text('Không tìm thấy thói quen này'))
          : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      // Kéo danh sách thì tự ẩn bàn phím.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _Field(
          label: 'Tên thói quen',
          child: TextField(
            controller: _name,
            focusNode: _nameFocus,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Ví dụ: Uống 2 lít nước',
              errorText: _errors.name,
            ),
            onChanged: (_) {
              if (_errors.name != null) {
                setState(() => _errors = const HabitFormErrors());
              }
            },
          ),
        ),
        _Field(
          label: 'Biểu tượng',
          child: HabitIconPicker(
            selectedKey: _icon,
            color: _color,
            onChanged: (key) => setState(() => _icon = key),
          ),
        ),
        _Field(
          label: 'Màu',
          child: HabitColorPicker(
            selected: _color,
            onChanged: (color) => setState(() => _color = color),
          ),
        ),
        _Field(
          label: 'Lặp lại',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: true, label: Text('Mỗi ngày')),
                    ButtonSegment(value: false, label: Text('Theo thứ')),
                  ],
                  selected: {_everyDay},
                  onSelectionChanged: (set) => _setEveryDay(set.first),
                ),
              ),
              if (!_everyDay) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var weekday = 1; weekday <= 7; weekday++)
                      FilterChip(
                        label: Text(weekdayShort(weekday)),
                        selected: _days.contains(weekday),
                        onSelected: (on) => _toggleDay(weekday, on),
                      ),
                  ],
                ),
              ],
              if (_errors.days != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _errors.days!,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
            ],
          ),
        ),
        _Field(
          label: 'Mục tiêu mỗi ngày',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Số lần cần làm để tính là xong',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Giảm mục tiêu',
                    onPressed: _goal > habitGoalRange.$1
                        ? () => _setGoal(_goal - 1)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '$_goal',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Tăng mục tiêu',
                    onPressed: _goal < habitGoalRange.$2
                        ? () => _setGoal(_goal + 1)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              if (_errors.goal != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _errors.goal!,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              if (_goal > 1) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _unit,
                  maxLength: 12,
                  inputFormatters: [LengthLimitingTextInputFormatter(12)],
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị (không bắt buộc)',
                    hintText: 'ly, trang, phút…',
                    counterText: '',
                  ),
                ),
              ],
            ],
          ),
        ),
        _Field(
          label: 'Nhắc mỗi ngày',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nhắc mỗi ngày'),
                value: _reminder != null,
                onChanged: (on) => setState(
                  () => _reminder = on ? defaultHabitReminder : null,
                ),
              ),
              if (_reminder != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Giờ nhắc'),
                  trailing: Text(
                    hourMinute(
                      DateTime(2000, 1, 1, _reminder!.hour, _reminder!.minute),
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: _pickReminder,
                ),
            ],
          ),
        ),
        _Field(
          label: 'Ngày bắt đầu',
          child: OutlinedButton.icon(
            onPressed: _pickStartDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_two(_startDate.day)}/${_two(_startDate.month)}/'
                '${_startDate.year}',
              ),
            ),
          ),
        ),
        if (_editing) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _archive,
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Lưu trữ thói quen'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Xóa thói quen'),
          ),
        ],
      ],
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');
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
