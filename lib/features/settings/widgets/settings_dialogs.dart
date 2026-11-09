import 'package:flutter/material.dart';

import '../settings_labels.dart';

/// Chọn một giá trị trong danh sách ([values]) bằng hộp thoại nút chọn.
/// Trả về giá trị được chọn, hoặc `null` nếu hủy.
Future<int?> showChoiceDialog(
  BuildContext context, {
  required String title,
  required List<int> values,
  required int selected,
  required String Function(int value) labelOf,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        RadioGroup<int>(
          groupValue: selected,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final value in values)
                RadioListTile<int>(value: value, title: Text(labelOf(value))),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Một thời lượng phút có nút − và +, giới hạn trong [min]–[max].
class MinutesStepper extends StatelessWidget {
  const MinutesStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        IconButton(
          tooltip: 'Giảm $label',
          onPressed: value - step >= min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        SizedBox(
          width: 72,
          child: Text(
            minutesLabel(value),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
        ),
        IconButton(
          tooltip: 'Tăng $label',
          onPressed: value + step <= max ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

/// Hộp thoại chỉnh một hay nhiều thời lượng cùng lúc. [specs] mô tả từng dòng;
/// trả về danh sách giá trị mới theo đúng thứ tự, hoặc `null` nếu hủy.
Future<List<int>?> showMinutesDialog(
  BuildContext context, {
  required String title,
  required List<MinutesSpec> specs,
}) {
  return showDialog<List<int>>(
    context: context,
    builder: (_) => _MinutesDialog(title: title, specs: specs),
  );
}

class MinutesSpec {
  const MinutesSpec({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
}

class _MinutesDialog extends StatefulWidget {
  const _MinutesDialog({required this.title, required this.specs});

  final String title;
  final List<MinutesSpec> specs;

  @override
  State<_MinutesDialog> createState() => _MinutesDialogState();
}

class _MinutesDialogState extends State<_MinutesDialog> {
  late final List<int> _values = [for (final s in widget.specs) s.value];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.specs.length; i++)
            MinutesStepper(
              label: widget.specs[i].label,
              value: _values[i],
              min: widget.specs[i].min,
              max: widget.specs[i].max,
              step: widget.specs[i].step,
              onChanged: (v) => setState(() => _values[i] = v),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(List<int>.of(_values)),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
