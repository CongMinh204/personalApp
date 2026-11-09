import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/ids.dart';
import '../../data/models/tag.dart';
import '../../data/repositories/tag_repository.dart';
import '../../theme/app_theme.dart';
import 'tag_validation.dart';
import 'widgets/tag_color_picker.dart';
import 'widgets/tag_edit_dialog.dart';

/// Quản lý nhãn: thêm, sửa, xóa. Mở từ Cài đặt.
class TagManagerScreen extends StatefulWidget {
  const TagManagerScreen({super.key});

  @override
  State<TagManagerScreen> createState() => _TagManagerScreenState();
}

class _TagManagerScreenState extends State<TagManagerScreen> {
  final _name = TextEditingController();
  TagColor _color = TagColor.violet;
  String? _error;

  late final TagRepository _repo = context.read<TagRepository>();
  late final Stream<List<Tag>> _tags = _repo.watchAll();
  late final Stream<Map<String, int>> _counts = _repo.watchTaskCounts();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final error = validateTagName(_name.text, await _repo.getAll());
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    try {
      await _repo.add(Tag(id: newId(), name: _name.text.trim(), color: _color));
    } on DuplicateTagNameException catch (e) {
      if (mounted) setState(() => _error = e.toString());
      return;
    }
    if (!mounted) return;
    _name.clear();
    setState(() {
      _error = null;
      _color = TagColor.violet;
    });
  }

  Future<String?> _update(Tag tag, String name, TagColor color) async {
    try {
      await _repo.update(tag.copyWith(name: name, color: color));
      return null;
    } on DuplicateTagNameException catch (e) {
      return e.toString();
    }
  }

  Future<void> _confirmDelete(Tag tag, int taskCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa nhãn "${tag.name}"?'),
        content: Text(
          taskCount == 0
              ? 'Chưa có việc nào dùng nhãn này.'
              : '$taskCount việc đang dùng nhãn này sẽ chuyển thành '
                    '"Không nhãn". Các việc không bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.delete(tag.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Đã xóa nhãn "${tag.name}"')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý nhãn')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhãn mới',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _name,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(tagNameMaxLength),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Ví dụ: Gia đình',
                            errorText: _error,
                          ),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: FilledButton(
                          onPressed: _add,
                          child: const Text('Thêm'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TagColorPicker(
                    selected: _color,
                    onChanged: (color) => setState(() => _color = color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Tag>>(
            stream: _tags,
            builder: (context, tagsSnapshot) {
              final tags = tagsSnapshot.data ?? const <Tag>[];
              return StreamBuilder<Map<String, int>>(
                stream: _counts,
                builder: (context, countsSnapshot) {
                  final counts = countsSnapshot.data ?? const <String, int>{};
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: Text(
                          '${tags.length} nhãn',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < tags.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                _TagRow(
                                  tag: tags[i],
                                  taskCount: counts[tags[i].id] ?? 0,
                                  onEdit: () => showTagEditDialog(
                                    context,
                                    tag: tags[i],
                                    existing: tags,
                                    onSave: (name, color) =>
                                        _update(tags[i], name, color),
                                  ),
                                  onDelete: () => _confirmDelete(
                                    tags[i],
                                    counts[tags[i].id] ?? 0,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Xóa nhãn không xóa việc. Các việc đang dùng nhãn đó sẽ chuyển '
              'thành “Không nhãn”.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.taskCount,
    required this.onEdit,
    required this.onDelete,
  });

  final Tag tag;
  final int taskCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground) = TaskColors.of(context).tag(tag.color);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tag.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$taskCount việc',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sửa nhãn ${tag.name}',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Xóa nhãn ${tag.name}',
            onPressed: onDelete,
            color: scheme.error,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
