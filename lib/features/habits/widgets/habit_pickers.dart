import 'package:flutter/material.dart';

import '../habit_logic.dart';

/// Hàng 5 biểu tượng để chọn. Ô đang chọn có viền và nền theo màu của thói quen.
class HabitIconPicker extends StatelessWidget {
  const HabitIconPicker({
    super.key,
    required this.selectedKey,
    required this.color,
    required this.onChanged,
  });

  final String selectedKey;
  final Color color;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = habitInkColor(color, Theme.of(context).brightness);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final option in habitIcons)
          Semantics(
            button: true,
            selected: option.key == selectedKey,
            label: option.label,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChanged(option.key),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: option.key == selectedKey
                      ? ink.withValues(alpha: 0.16)
                      : scheme.surfaceContainerHighest,
                  border: Border.all(
                    width: 2,
                    color: option.key == selectedKey ? ink : Colors.transparent,
                  ),
                ),
                child: Icon(
                  option.icon,
                  color: option.key == selectedKey ? ink : scheme.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Hàng 5 ô màu. Ô đang chọn có viền và dấu tích.
class HabitColorPicker extends StatelessWidget {
  const HabitColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final option in habitColors)
          Semantics(
            button: true,
            selected: option.color.toARGB32() == selected.toARGB32(),
            label: option.label,
            child: InkResponse(
              onTap: () => onChanged(option.color),
              radius: 28,
              child: Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 3,
                    color: option.color.toARGB32() == selected.toARGB32()
                        ? option.color
                        : Colors.transparent,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: option.color,
                  ),
                  child: option.color.toARGB32() == selected.toARGB32()
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
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
