import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../countdown_controller.dart';

/// Hộp thoại chọn số phút cho chế độ Tùy chỉnh: vài mức có sẵn hoặc tự nhập.
/// Trả về số phút (1–180), hoặc `null` nếu hủy.
Future<int?> showCustomMinutesDialog(
  BuildContext context, {
  required int initial,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _CustomMinutesDialog(initial: initial),
  );
}

class _CustomMinutesDialog extends StatefulWidget {
  const _CustomMinutesDialog({required this.initial});

  final int initial;

  @override
  State<_CustomMinutesDialog> createState() => _CustomMinutesDialogState();
}

class _CustomMinutesDialogState extends State<_CustomMinutesDialog> {
  static const _presets = [1, 5, 10, 15, 25, 30, 45, 60];

  late final _controller = TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_controller.text.trim());

  void _save() {
    final value = _value;
    final (min, max) = CountdownController.customMinutesRange;
    if (value == null || value < min || value > max) {
      setState(() => _error = 'Nhập số phút từ $min đến $max');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hẹn giờ tùy chỉnh'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in _presets)
                ChoiceChip(
                  label: Text('$minutes phút'),
                  selected: _value == minutes,
                  onSelected: (_) => setState(() {
                    _controller.text = '$minutes';
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            decoration: InputDecoration(
              labelText: 'Số phút',
              counterText: '',
              errorText: _error,
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }
}
