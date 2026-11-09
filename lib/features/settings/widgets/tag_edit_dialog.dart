import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/tag.dart';
import '../tag_validation.dart';
import 'tag_color_picker.dart';

/// Hộp thoại nhập tên và màu của một nhãn (sửa nhãn có sẵn hoặc tạo nhãn mới
/// với [title] khác).
///
/// [onSave] lưu nhãn và trả về thông báo lỗi (ví dụ tên trùng) hoặc `null` nếu
/// thành công. Có lỗi thì hộp thoại giữ nguyên để người dùng sửa, không đóng.
Future<void> showTagEditDialog(
  BuildContext context, {
  required Tag tag,
  required Iterable<Tag> existing,
  required Future<String?> Function(String name, TagColor color) onSave,
  String title = 'Sửa nhãn',
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TagEditDialog(
      title: title,
      tag: tag,
      existing: existing,
      onSave: onSave,
    ),
  );
}

class _TagEditDialog extends StatefulWidget {
  const _TagEditDialog({
    required this.title,
    required this.tag,
    required this.existing,
    required this.onSave,
  });

  final String title;
  final Tag tag;
  final Iterable<Tag> existing;
  final Future<String?> Function(String name, TagColor color) onSave;

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  late final _name = TextEditingController(text: widget.tag.name);
  late TagColor _color = widget.tag.color;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = validateTagName(
      _name.text,
      widget.existing,
      editingId: widget.tag.id,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _saving = true);
    final saveError = await widget.onSave(_name.text.trim(), _color);
    if (!mounted) return;
    if (saveError != null) {
      setState(() {
        _error = saveError;
        _saving = false;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              LengthLimitingTextInputFormatter(tagNameMaxLength),
            ],
            decoration: InputDecoration(
              labelText: 'Tên nhãn',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          TagColorPicker(
            selected: _color,
            onChanged: (color) => setState(() => _color = color),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
