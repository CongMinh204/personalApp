import 'package:flutter/material.dart';

import '../models/habit.dart';

class HabitFormScreen extends StatefulWidget {
  const HabitFormScreen({super.key, this.habit});

  final Habit? habit; // null là tạo mới, khác null là sửa

  @override
  State<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends State<HabitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _durationController;
  late int _iconCode;

  final List<int> _availableIcons = [
    0xe28d, // Thể thao
    0xe11e, // Đọc sách
    0xe6df, // Uống nước
    0xe539, // Ngủ sớm
    0xe3e8, // Học tập
    0xeb3f, // Thiền
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _titleController = TextEditingController(text: h?.title ?? '');
    _descController = TextEditingController(text: h?.description ?? '');
    _durationController = TextEditingController(
      text: (h?.durationMinutes ?? 15).toString(),
    );
    _iconCode = h?.iconCode ?? _availableIcons.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final duration = int.tryParse(_durationController.text.trim()) ?? 15;
    final result = Habit(
      id: widget.habit?.id ?? 'habit_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      durationMinutes: duration,
      iconCode: _iconCode,
      streak: widget.habit?.streak ?? 0,
      completedDates: widget.habit?.completedDates ?? [],
      isArchived: widget.habit?.isArchived ?? false,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.habit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Sửa thói quen' : 'Tạo thói quen mới'),
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
                labelText: 'Tên thói quen',
                hintText: 'VD: Chạy bộ, Đọc sách...',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập tên thói quen'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Mô tả / Động lực',
                hintText: 'VD: Mục tiêu 20 trang sách mỗi ngày',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Thời gian bấm giờ (phút)',
                hintText: 'VD: 15, 20, 30...',
                suffixText: 'phút',
              ),
              validator: (v) {
                if (v == null || int.tryParse(v) == null || int.parse(v) <= 0) {
                  return 'Vui lòng nhập số phút hợp lệ (> 0)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Chọn biểu tượng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: _availableIcons.map((code) {
                final isSelected = _iconCode == code;
                return ChoiceChip(
                  avatar: Icon(IconData(code, fontFamily: 'MaterialIcons')),
                  label: const SizedBox.shrink(),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _iconCode = code),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
