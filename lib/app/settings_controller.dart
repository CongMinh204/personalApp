import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 5 màu nhấn có thể chọn trong Cài đặt (như mockup).
const accentOptions = [
  AccentOption('Xanh tím', Color(0xFF5B4FE0)),
  AccentOption('Xanh dương', Color(0xFF1E6FD9)),
  AccentOption('Xanh lá', Color(0xFF23774F)),
  AccentOption('Cam', Color(0xFFC2410C)),
  AccentOption('Hồng', Color(0xFFBE185D)),
];

class AccentOption {
  const AccentOption(this.label, this.color);

  final String label;
  final Color color;
}

/// Các mức "nhắc trước" (phút) có thể chọn, như màn Sửa việc.
const reminderChoices = [0, 5, 15, 30, 60, 1440];

/// Cài đặt của app, lưu bằng shared_preferences. Key và giá trị mặc định:
/// docs/DATA_CONTRACT.md, mục 8. Mọi setter kiểm tra giá trị, lưu rồi mới báo
/// cho người nghe; đặt lại đúng giá trị cũ thì không làm gì.
class SettingsController extends ChangeNotifier {
  SettingsController._(this._prefs) {
    _themeMode = _readThemeMode();
    _accent = _readAccent();
    _weekStart = _readChoice(_Keys.weekStart, const [1, 7], defaultWeekStart);
    _defaultReminderMinutes = _readChoice(
      _Keys.defaultReminderMinutes,
      reminderChoices,
      defaultReminderMinutesValue,
    );
    _remindersEnabled = _prefs.getBool(_Keys.remindersEnabled) ?? true;
    _morningSummaryEnabled =
        _prefs.getBool(_Keys.morningSummaryEnabled) ?? true;
    _morningSummaryMinutes = _readRange(
      _Keys.morningSummaryTime,
      0,
      24 * 60 - 1,
      defaultMorningSummaryMinutes,
    );
    _pomodoroMinutes = _readRange(
      _Keys.pomodoroMinutes,
      pomodoroRange.$1,
      pomodoroRange.$2,
      defaultPomodoroMinutes,
    );
    _shortBreakMinutes = _readRange(
      _Keys.shortBreakMinutes,
      shortBreakRange.$1,
      shortBreakRange.$2,
      defaultShortBreakMinutes,
    );
    _longBreakMinutes = _readRange(
      _Keys.longBreakMinutes,
      longBreakRange.$1,
      longBreakRange.$2,
      defaultLongBreakMinutes,
    );
    _autoNextSession = _prefs.getBool(_Keys.autoNextSession) ?? false;
  }

  /// Đọc cài đặt đã lưu (hoặc mặc định nếu chưa có).
  static Future<SettingsController> load() async =>
      SettingsController._(await SharedPreferences.getInstance());

  /// Dùng khi đã có [SharedPreferences] (test).
  factory SettingsController.fromPrefs(SharedPreferences prefs) =>
      SettingsController._(prefs);

  static const defaultWeekStart = 1;
  static const defaultReminderMinutesValue = 15;
  static const defaultMorningSummaryMinutes = 7 * 60;
  static const defaultPomodoroMinutes = 25;
  static const defaultShortBreakMinutes = 5;
  static const defaultLongBreakMinutes = 15;

  /// Khoảng cho phép (nhỏ nhất, lớn nhất) của thời gian, tính bằng phút.
  static const pomodoroRange = (5, 60);
  static const shortBreakRange = (1, 30);
  static const longBreakRange = (5, 60);

  final SharedPreferences _prefs;

  late ThemeMode _themeMode;
  late Color _accent;
  late int _weekStart;
  late int _defaultReminderMinutes;
  late bool _remindersEnabled;
  late bool _morningSummaryEnabled;
  late int _morningSummaryMinutes;
  late int _pomodoroMinutes;
  late int _shortBreakMinutes;
  late int _longBreakMinutes;
  late bool _autoNextSession;

  ThemeMode get themeMode => _themeMode;

  /// Màu nhấn của app (một trong [accentOptions]).
  Color get accent => _accent;

  /// Ngày đầu tuần của Lịch và Thống kê: 1 = Thứ Hai, 7 = Chủ Nhật.
  int get weekStart => _weekStart;

  /// Số phút nhắc trước mặc định của việc mới (một trong [reminderChoices]).
  int get defaultReminderMinutes => _defaultReminderMinutes;

  bool get remindersEnabled => _remindersEnabled;

  bool get morningSummaryEnabled => _morningSummaryEnabled;

  /// Giờ gửi tóm tắt buổi sáng, số phút từ 00:00.
  int get morningSummaryMinutes => _morningSummaryMinutes;

  int get pomodoroMinutes => _pomodoroMinutes;

  int get shortBreakMinutes => _shortBreakMinutes;

  int get longBreakMinutes => _longBreakMinutes;

  /// Hết phiên thì tự chạy phiên kế tiếp (giờ nghỉ hoặc phiên tập trung).
  bool get autoNextSession => _autoNextSession;

  Future<void> setThemeMode(ThemeMode value) => _set(
    _themeMode,
    value,
    () => _themeMode = value,
    () => _prefs.setString(_Keys.themeMode, value.name),
  );

  /// [value] phải là một màu trong [accentOptions].
  Future<void> setAccent(Color value) {
    if (!accentOptions.any((o) => o.color.toARGB32() == value.toARGB32())) {
      throw ArgumentError.value(value, 'value', 'Không phải màu nhấn hợp lệ');
    }
    return _set(
      _accent.toARGB32(),
      value.toARGB32(),
      () => _accent = value,
      () => _prefs.setInt(_Keys.accentColor, value.toARGB32()),
    );
  }

  /// 1 = Thứ Hai hoặc 7 = Chủ Nhật.
  Future<void> setWeekStart(int value) {
    _expectOneOf(value, const [1, 7], 'weekStart');
    return _set(
      _weekStart,
      value,
      () => _weekStart = value,
      () => _prefs.setInt(_Keys.weekStart, value),
    );
  }

  Future<void> setDefaultReminderMinutes(int value) {
    _expectOneOf(value, reminderChoices, 'defaultReminderMinutes');
    return _set(
      _defaultReminderMinutes,
      value,
      () => _defaultReminderMinutes = value,
      () => _prefs.setInt(_Keys.defaultReminderMinutes, value),
    );
  }

  Future<void> setRemindersEnabled(bool value) => _set(
    _remindersEnabled,
    value,
    () => _remindersEnabled = value,
    () => _prefs.setBool(_Keys.remindersEnabled, value),
  );

  Future<void> setMorningSummaryEnabled(bool value) => _set(
    _morningSummaryEnabled,
    value,
    () => _morningSummaryEnabled = value,
    () => _prefs.setBool(_Keys.morningSummaryEnabled, value),
  );

  Future<void> setMorningSummaryMinutes(int value) {
    _expectInRange(value, 0, 24 * 60 - 1, 'morningSummaryMinutes');
    return _set(
      _morningSummaryMinutes,
      value,
      () => _morningSummaryMinutes = value,
      () => _prefs.setInt(_Keys.morningSummaryTime, value),
    );
  }

  Future<void> setPomodoroMinutes(int value) {
    _expectInRange(value, pomodoroRange.$1, pomodoroRange.$2, 'pomodoro');
    return _set(
      _pomodoroMinutes,
      value,
      () => _pomodoroMinutes = value,
      () => _prefs.setInt(_Keys.pomodoroMinutes, value),
    );
  }

  Future<void> setShortBreakMinutes(int value) {
    _expectInRange(value, shortBreakRange.$1, shortBreakRange.$2, 'shortBreak');
    return _set(
      _shortBreakMinutes,
      value,
      () => _shortBreakMinutes = value,
      () => _prefs.setInt(_Keys.shortBreakMinutes, value),
    );
  }

  Future<void> setLongBreakMinutes(int value) {
    _expectInRange(value, longBreakRange.$1, longBreakRange.$2, 'longBreak');
    return _set(
      _longBreakMinutes,
      value,
      () => _longBreakMinutes = value,
      () => _prefs.setInt(_Keys.longBreakMinutes, value),
    );
  }

  Future<void> setAutoNextSession(bool value) => _set(
    _autoNextSession,
    value,
    () => _autoNextSession = value,
    () => _prefs.setBool(_Keys.autoNextSession, value),
  );

  /// Lưu rồi mới đổi giá trị trong bộ nhớ và báo người nghe; nếu lưu lỗi thì
  /// giao diện không hiện giá trị chưa được lưu.
  Future<void> _set<T>(
    T current,
    T value,
    VoidCallback apply,
    Future<bool> Function() save,
  ) async {
    if (current == value) return;
    await save();
    apply();
    notifyListeners();
  }

  ThemeMode _readThemeMode() {
    final name = _prefs.getString(_Keys.themeMode);
    return ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  Color _readAccent() {
    final value = _prefs.getInt(_Keys.accentColor);
    for (final option in accentOptions) {
      if (option.color.toARGB32() == value) return option.color;
    }
    return accentOptions.first.color;
  }

  int _readChoice(String key, List<int> choices, int fallback) {
    final value = _prefs.getInt(key);
    return value != null && choices.contains(value) ? value : fallback;
  }

  int _readRange(String key, int min, int max, int fallback) {
    final value = _prefs.getInt(key);
    return value != null && value >= min && value <= max ? value : fallback;
  }

  void _expectOneOf(int value, List<int> choices, String name) {
    if (!choices.contains(value)) {
      throw ArgumentError.value(value, name, 'Chỉ nhận một trong $choices');
    }
  }

  void _expectInRange(int value, int min, int max, String name) {
    if (value < min || value > max) {
      throw ArgumentError.value(value, name, 'Phải từ $min đến $max');
    }
  }
}

/// Key lưu trong shared_preferences. Không đổi tên sau khi app đã phát hành.
abstract final class _Keys {
  static const themeMode = 'theme_mode';
  static const accentColor = 'accent_color';
  static const weekStart = 'week_start';
  static const defaultReminderMinutes = 'default_reminder_minutes';
  static const remindersEnabled = 'reminders_enabled';
  static const morningSummaryEnabled = 'morning_summary_enabled';
  static const morningSummaryTime = 'morning_summary_time';
  static const pomodoroMinutes = 'pomodoro_minutes';
  static const shortBreakMinutes = 'short_break_minutes';
  static const longBreakMinutes = 'long_break_minutes';
  static const autoNextSession = 'auto_next_session';
}
