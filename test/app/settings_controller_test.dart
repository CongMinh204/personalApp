import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/app/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SettingsController> load([
    Map<String, Object> stored = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(stored);
    return SettingsController.fromPrefs(await SharedPreferences.getInstance());
  }

  group('giá trị mặc định', () {
    test('app mới cài dùng mặc định của hợp đồng', () async {
      final s = await load();
      expect(s.themeMode, ThemeMode.system);
      expect(s.accent, accentOptions.first.color);
      expect(s.accent, const Color(0xFF5B4FE0));
      expect(s.weekStart, 1);
      expect(s.defaultReminderMinutes, 15);
      expect(s.remindersEnabled, isTrue);
      expect(s.morningSummaryEnabled, isTrue);
      expect(s.morningSummaryMinutes, 420);
      expect(s.pomodoroMinutes, 25);
      expect(s.shortBreakMinutes, 5);
      expect(s.longBreakMinutes, 15);
      expect(s.autoNextSession, isFalse);
    });

    test('giá trị lưu hỏng hoặc ngoài khoảng thì dùng mặc định', () async {
      final s = await load({
        'theme_mode': 'rainbow',
        'accent_color': 0x12345678,
        'week_start': 3,
        'default_reminder_minutes': 7,
        'morning_summary_time': 99999,
        'pomodoro_minutes': 1,
        'short_break_minutes': 100,
        'long_break_minutes': 0,
      });
      expect(s.themeMode, ThemeMode.system);
      expect(s.accent, accentOptions.first.color);
      expect(s.weekStart, 1);
      expect(s.defaultReminderMinutes, 15);
      expect(s.morningSummaryMinutes, 420);
      expect(s.pomodoroMinutes, 25);
      expect(s.shortBreakMinutes, 5);
      expect(s.longBreakMinutes, 15);
    });
  });

  group('lưu và đọc lại', () {
    test(
      'mọi giá trị đã đặt vẫn còn khi đọc lại từ shared_preferences',
      () async {
        final s = await load();
        await s.setThemeMode(ThemeMode.dark);
        await s.setAccent(accentOptions[3].color);
        await s.setWeekStart(7);
        await s.setDefaultReminderMinutes(60);
        await s.setRemindersEnabled(false);
        await s.setMorningSummaryEnabled(false);
        await s.setMorningSummaryMinutes(8 * 60 + 30);
        await s.setPomodoroMinutes(50);
        await s.setShortBreakMinutes(10);
        await s.setLongBreakMinutes(30);
        await s.setAutoNextSession(true);

        final reloaded = SettingsController.fromPrefs(
          await SharedPreferences.getInstance(),
        );
        expect(reloaded.themeMode, ThemeMode.dark);
        expect(reloaded.accent, accentOptions[3].color);
        expect(reloaded.weekStart, 7);
        expect(reloaded.defaultReminderMinutes, 60);
        expect(reloaded.remindersEnabled, isFalse);
        expect(reloaded.morningSummaryEnabled, isFalse);
        expect(reloaded.morningSummaryMinutes, 510);
        expect(reloaded.pomodoroMinutes, 50);
        expect(reloaded.shortBreakMinutes, 10);
        expect(reloaded.longBreakMinutes, 30);
        expect(reloaded.autoNextSession, isTrue);
      },
    );

    test('dùng đúng key của hợp đồng', () async {
      final s = await load();
      await s.setThemeMode(ThemeMode.light);
      await s.setWeekStart(7);
      await s.setPomodoroMinutes(30);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
      expect(prefs.getInt('week_start'), 7);
      expect(prefs.getInt('pomodoro_minutes'), 30);
    });
  });

  group('kiểm tra giá trị', () {
    test('Pomodoro chỉ nhận 5–60 phút (kể cả hai đầu)', () async {
      final s = await load();
      await s.setPomodoroMinutes(5);
      await s.setPomodoroMinutes(60);
      expect(s.pomodoroMinutes, 60);
      expect(() => s.setPomodoroMinutes(4), throwsArgumentError);
      expect(() => s.setPomodoroMinutes(61), throwsArgumentError);
      expect(s.pomodoroMinutes, 60);
    });

    test('nghỉ ngắn 1–30, nghỉ dài 5–60', () async {
      final s = await load();
      expect(() => s.setShortBreakMinutes(0), throwsArgumentError);
      expect(() => s.setShortBreakMinutes(31), throwsArgumentError);
      expect(() => s.setLongBreakMinutes(4), throwsArgumentError);
      expect(() => s.setLongBreakMinutes(61), throwsArgumentError);
    });

    test('tuần chỉ bắt đầu từ Thứ Hai (1) hoặc Chủ Nhật (7)', () async {
      final s = await load();
      expect(() => s.setWeekStart(2), throwsArgumentError);
      await s.setWeekStart(7);
      expect(s.weekStart, 7);
    });

    test('nhắc trước chỉ nhận các mức của màn Sửa việc', () async {
      final s = await load();
      for (final minutes in reminderChoices) {
        await s.setDefaultReminderMinutes(minutes);
        expect(s.defaultReminderMinutes, minutes);
      }
      expect(() => s.setDefaultReminderMinutes(10), throwsArgumentError);
    });

    test('màu nhấn phải là một trong 5 màu', () async {
      final s = await load();
      expect(() => s.setAccent(const Color(0xFF000000)), throwsArgumentError);
      expect(accentOptions, hasLength(5));
    });

    test('giờ tóm tắt buổi sáng trong 00:00–23:59', () async {
      final s = await load();
      await s.setMorningSummaryMinutes(0);
      await s.setMorningSummaryMinutes(1439);
      expect(() => s.setMorningSummaryMinutes(-1), throwsArgumentError);
      expect(() => s.setMorningSummaryMinutes(1440), throwsArgumentError);
    });
  });

  group('báo thay đổi', () {
    test(
      'báo người nghe khi đổi, không báo khi đặt lại đúng giá trị cũ',
      () async {
        final s = await load();
        var calls = 0;
        s.addListener(() => calls++);

        await s.setThemeMode(ThemeMode.dark);
        expect(calls, 1);
        await s.setThemeMode(ThemeMode.dark);
        expect(calls, 1);
        await s.setAutoNextSession(true);
        expect(calls, 2);
      },
    );

    test('giá trị sai thì không báo và không lưu', () async {
      final s = await load();
      var calls = 0;
      s.addListener(() => calls++);

      expect(() => s.setPomodoroMinutes(999), throwsArgumentError);

      expect(calls, 0);
      expect(
        (await SharedPreferences.getInstance()).containsKey('pomodoro_minutes'),
        isFalse,
      );
    });
  });
}
