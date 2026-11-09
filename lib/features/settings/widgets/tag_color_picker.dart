import 'package:flutter/material.dart';

import '../../../data/models/tag.dart';
import '../../../theme/app_theme.dart';

/// Hàng 5 ô màu nhãn như mockup. Ô đang chọn có viền và dấu tích.
class TagColorPicker extends StatelessWidget {
  const TagColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TagColor selected;
  final ValueChanged<TagColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = TaskColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final color in TagColor.values)
          Semantics(
            button: true,
            selected: color == selected,
            label: color.label,
            child: InkResponse(
              onTap: () => onChanged(color),
              radius: 24,
              child: Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 3,
                    color: color == selected
                        ? scheme.primary
                        : Colors.transparent,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.tag(color).$1,
                  ),
                  child: color == selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: colors.tag(color).$2,
                        )
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
