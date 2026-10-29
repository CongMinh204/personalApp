import 'package:flutter/material.dart';

import '../models/task.dart';

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

/// Màu riêng của app: màu ưu tiên và màu nền/chữ của nhãn.
@immutable
class TaskColors extends ThemeExtension<TaskColors> {
  const TaskColors({
    required this.high,
    required this.medium,
    required this.low,
    required this.orange,
    required this.onOrange,
    required this.green,
    required this.onGreen,
  });

  final Color high;
  final Color medium;
  final Color low;

  /// Cam nhạt (nền nhãn) và màu chữ đi kèm.
  final Color orange;
  final Color onOrange;

  /// Xanh lá nhạt (nền nhãn, thẻ "Xong hết") và màu chữ đi kèm.
  final Color green;
  final Color onGreen;

  static const light = TaskColors(
    high: Color(0xFFC2302B),
    medium: Color(0xFFA35A00),
    low: Color(0xFF5D5D70),
    orange: Color(0xFFFFE9D2),
    onOrange: Color(0xFF8A4500),
    green: Color(0xFFDDF4E3),
    onGreen: Color(0xFF1C6B36),
  );

  static const dark = TaskColors(
    high: Color(0xFFFF8F87),
    medium: Color(0xFFF5B544),
    low: Color(0xFFA6A6B8),
    orange: Color(0xFF3B2A17),
    onOrange: Color(0xFFFFC78A),
    green: Color(0xFF16301F),
    onGreen: Color(0xFF8FDCA6),
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

  /// (nền, chữ) của badge nhãn.
  (Color, Color) tag(TaskTag tag, ColorScheme scheme) => switch (tag) {
    TaskTag.study => (scheme.primary.withValues(alpha: 0.12), scheme.primary),
    TaskTag.work => (orange, onOrange),
    TaskTag.health => (green, onGreen),
    TaskTag.personal => (
      scheme.surfaceContainerHighest,
      scheme.onSurfaceVariant,
    ),
  };

  @override
  TaskColors copyWith({
    Color? high,
    Color? medium,
    Color? low,
    Color? orange,
    Color? onOrange,
    Color? green,
    Color? onGreen,
  }) {
    return TaskColors(
      high: high ?? this.high,
      medium: medium ?? this.medium,
      low: low ?? this.low,
      orange: orange ?? this.orange,
      onOrange: onOrange ?? this.onOrange,
      green: green ?? this.green,
      onGreen: onGreen ?? this.onGreen,
    );
  }

  @override
  TaskColors lerp(TaskColors? other, double t) {
    if (other == null) return this;
    return TaskColors(
      high: Color.lerp(high, other.high, t)!,
      medium: Color.lerp(medium, other.medium, t)!,
      low: Color.lerp(low, other.low, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      onOrange: Color.lerp(onOrange, other.onOrange, t)!,
      green: Color.lerp(green, other.green, t)!,
      onGreen: Color.lerp(onGreen, other.onGreen, t)!,
    );
  }
}
