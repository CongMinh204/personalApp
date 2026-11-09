import 'package:flutter/material.dart';

import '../../../app/settings_controller.dart';

/// Một nhóm cài đặt: tiêu đề màu nhấn phía trên và thẻ chứa các dòng.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dòng cài đặt: tên bên trái, giá trị bên phải. Không có [onTap] thì chỉ để
/// xem (ví dụ "Âm báo").
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.value,
    this.onTap,
    this.destructive = false,
    this.showChevron = false,
  });

  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: destructive ? scheme.error : null,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (showChevron)
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Dòng có công tắc và dòng phụ. Bấm vào chữ gọi [onTap] (nếu có), bấm công
/// tắc gọi [onChanged].
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap ?? () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// 3 nút Sáng / Tối / Hệ thống nối liền nhau như mockup.
class ThemeModePicker extends StatelessWidget {
  const ThemeModePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  static const _labels = {
    ThemeMode.light: 'Sáng',
    ThemeMode.dark: 'Tối',
    ThemeMode.system: 'Hệ thống',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: [
          for (final entry in _labels.entries)
            ButtonSegment(value: entry.key, label: Text(entry.value)),
        ],
        selected: {selected},
        onSelectionChanged: (set) => onChanged(set.first),
      ),
    );
  }
}

/// Hàng 5 ô màu nhấn. Ô đang chọn có viền và dấu tích.
class AccentPicker extends StatelessWidget {
  const AccentPicker({
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
        for (final option in accentOptions)
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
