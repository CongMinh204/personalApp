import 'package:flutter/material.dart';

import '../data/models/tag.dart';
import '../data/models/task.dart';

class AppTheme {
  AppTheme._();

  static const seed = Color(0xFF5B4FE0);

  static const _lightBackground = Color(0xFFF6F6FB);
  static const _darkBackground = Color(0xFF111117);
  static const _darkCard = Color(0xFF1B1B23);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // fidelity giữ primary sát màu seed (tonalSpot mặc định làm nhạt màu nhấn).
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final background = isDark ? _darkBackground : _lightBackground;
    final card = isDark ? _darkCard : Colors.white;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        showCheckmark: false,
        color: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? scheme.primary : card,
        ),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      extensions: [isDark ? TaskColors.dark : TaskColors.light],
    );
  }
}

/// Màu riêng của app: màu ưu tiên, thẻ "Xong hết" và các tông màu nhãn.
@immutable
class TaskColors extends ThemeExtension<TaskColors> {
  const TaskColors({
    required this.high,
    required this.medium,
    required this.low,
    required this.green,
    required this.onGreen,
    required this.tagTones,
  });

  final Color high;
  final Color medium;
  final Color low;

  /// Xanh lá nhạt (thẻ "Xong hết") và màu chữ đi kèm.
  final Color green;
  final Color onGreen;

  /// (nền, chữ) của từng tông màu nhãn. Tông cố định, không đổi theo màu nhấn.
  final Map<TagColor, (Color, Color)> tagTones;

  static const light = TaskColors(
    high: Color(0xFFC2302B),
    medium: Color(0xFFA35A00),
    low: Color(0xFF5D5D70),
    green: Color(0xFFDDF4E3),
    onGreen: Color(0xFF1C6B36),
    tagTones: {
      TagColor.violet: (Color(0xFFE8E6FF), Color(0xFF2B2199)),
      TagColor.orange: (Color(0xFFFFF1DB), Color(0xFFA35A00)),
      TagColor.green: (Color(0xFFE1F4EA), Color(0xFF23774F)),
      TagColor.red: (Color(0xFFFDE8E7), Color(0xFFC2302B)),
      TagColor.grey: (Color(0xFFEEEDF7), Color(0xFF1A1A24)),
    },
  );

  static const dark = TaskColors(
    high: Color(0xFFFF8F87),
    medium: Color(0xFFF5B544),
    low: Color(0xFFA6A6B8),
    green: Color(0xFF16301F),
    onGreen: Color(0xFF8FDCA6),
    tagTones: {
      TagColor.violet: (Color(0xFF302A70), Color(0xFFDEDBFF)),
      TagColor.orange: (Color(0xFF3A2A10), Color(0xFFF5B544)),
      TagColor.green: (Color(0xFF15301F), Color(0xFF6FD6A1)),
      TagColor.red: (Color(0xFF3D1C1B), Color(0xFFFF8F87)),
      TagColor.grey: (Color(0xFF25252F), Color(0xFFECECF4)),
    },
  );

  static TaskColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<TaskColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  Color priority(Priority p) => switch (p) {
    Priority.high => high,
    Priority.medium => medium,
    Priority.low => low,
  };

  /// (nền, chữ) của badge nhãn có tông [color].
  (Color, Color) tag(TagColor color) => tagTones[color]!;

  @override
  TaskColors copyWith({
    Color? high,
    Color? medium,
    Color? low,
    Color? green,
    Color? onGreen,
    Map<TagColor, (Color, Color)>? tagTones,
  }) {
    return TaskColors(
      high: high ?? this.high,
      medium: medium ?? this.medium,
      low: low ?? this.low,
      green: green ?? this.green,
      onGreen: onGreen ?? this.onGreen,
      tagTones: tagTones ?? this.tagTones,
    );
  }

  @override
  TaskColors lerp(TaskColors? other, double t) {
    if (other == null) return this;
    return TaskColors(
      high: Color.lerp(high, other.high, t)!,
      medium: Color.lerp(medium, other.medium, t)!,
      low: Color.lerp(low, other.low, t)!,
      green: Color.lerp(green, other.green, t)!,
      onGreen: Color.lerp(onGreen, other.onGreen, t)!,
      tagTones: {
        for (final color in TagColor.values)
          color: (
            Color.lerp(tag(color).$1, other.tag(color).$1, t)!,
            Color.lerp(tag(color).$2, other.tag(color).$2, t)!,
          ),
      },
    );
  }
}
