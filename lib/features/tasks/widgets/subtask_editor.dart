import 'package:flutter/material.dart';

/// Việc con đang soạn trong form (chưa lưu).
class SubtaskDraft {
  SubtaskDraft({required this.id, required this.title, this.done = false});

  final String id;
  String title;
  bool done;
}

/// Danh sách việc con trong form Thêm/sửa việc: tick, xóa và thêm mới. Không
/// kéo thả sắp xếp, việc con hiển thị theo thứ tự thêm.
class SubtaskEditor extends StatelessWidget {
  const SubtaskEditor({
    super.key,
    required this.drafts,
    required this.controller,
    required this.onToggle,
    required this.onRemove,
    required this.onAdd,
  });

  final List<SubtaskDraft> drafts;

  /// Ô nhập việc con mới.
  final TextEditingController controller;
  final ValueChanged<SubtaskDraft> onToggle;
  final ValueChanged<SubtaskDraft> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final draft in drafts)
          Row(
            children: [
              Checkbox(
                value: draft.done,
                onChanged: (_) => onToggle(draft),
                shape: const CircleBorder(),
                semanticLabel: draft.title,
              ),
              Expanded(
                child: Text(
                  draft.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: draft.done ? scheme.onSurfaceVariant : null,
                    decoration: draft.done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Xóa việc con ${draft.title}',
                onPressed: () => onRemove(draft),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Thêm việc con'),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Thêm việc con',
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
