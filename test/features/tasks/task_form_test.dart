import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/data/models/task.dart';
import 'package:personal_app/features/tasks/task_form.dart';

void main() {
  final date = DateTime(2026, 10, 29);
  const nine = TimeOfDay(hour: 9, minute: 0);
  const ten = TimeOfDay(hour: 10, minute: 30);

  TaskFormErrors validate({
    String title = 'Việc',
    DateTime? date,
    bool allDay = true,
    TimeOfDay? start,
    TimeOfDay? end,
    RepeatRule repeat = RepeatRule.none,
  }) => validateTaskForm(
    title: title,
    date: date,
    allDay: allDay,
    start: start,
    end: end,
    repeat: repeat,
  );

  group('validateTaskForm', () {
    test('form hợp lệ thì không có lỗi', () {
      expect(validate(date: date).hasError, isFalse);
      expect(
        validate(date: date, allDay: false, start: nine, end: ten).hasError,
        isFalse,
      );
    });

    test('tiêu đề trống hoặc chỉ khoảng trắng là lỗi', () {
      expect(validate(title: '').title, 'Vui lòng nhập tên việc');
      expect(validate(title: '   ').title, 'Vui lòng nhập tên việc');
      expect(validate(title: ' A ').title, isNull);
    });

    test('giờ kết thúc phải sau giờ bắt đầu', () {
      for (final end in [nine, const TimeOfDay(hour: 8, minute: 59)]) {
        expect(
          validate(date: date, allDay: false, start: nine, end: end).time,
          'Giờ kết thúc phải sau giờ bắt đầu',
        );
      }
      expect(
        validate(
          date: date,
          allDay: false,
          start: nine,
          end: const TimeOfDay(hour: 9, minute: 1),
        ).time,
        isNull,
      );
    });

    test('giờ kết thúc là tùy chọn', () {
      expect(
        validate(date: date, allDay: false, start: nine).hasError,
        isFalse,
      );
    });

    test('việc có giờ mà chưa chọn giờ bắt đầu là lỗi', () {
      expect(validate(date: date, allDay: false).time, 'Chọn giờ bắt đầu');
    });

    test('việc cả ngày hoặc không có ngày thì bỏ qua kiểm tra giờ', () {
      expect(validate(date: date, start: ten, end: nine).time, isNull);
      expect(validate(allDay: false, start: ten, end: nine).time, isNull);
    });

    test('việc lặp lại cần có ngày', () {
      expect(
        validate(repeat: RepeatRule.daily).repeat,
        'Việc lặp lại cần có ngày',
      );
      expect(validate(date: date, repeat: RepeatRule.daily).repeat, isNull);
      expect(validate().repeat, isNull);
    });

    test('nhiều lỗi cùng lúc', () {
      final errors = validate(
        title: '',
        allDay: false,
        date: date,
        start: ten,
        end: nine,
      );
      expect(errors.title, isNotNull);
      expect(errors.time, isNotNull);
      expect(errors.hasError, isTrue);
    });
  });

  group('buildTask', () {
    final created = DateTime(2026, 10, 1);

    Task build({
      DateTime? date,
      bool allDay = true,
      TimeOfDay? start,
      TimeOfDay? end,
    }) => buildTask(
      id: 'a',
      createdAt: created,
      title: '  Học bài  ',
      note: '  ghi chú ',
      date: date,
      allDay: allDay,
      start: start,
      end: end,
      reminderMinutes: 30,
      repeat: RepeatRule.weekly,
      priority: Priority.high,
      tagId: 'tag-study',
    );

    test('cả ngày: due là 00:00 của ngày, không có giờ', () {
      final task = build(date: date, start: nine, end: ten);
      expect(task.due, DateTime(2026, 10, 29));
      expect(task.hasTime, isFalse);
      expect(task.end, isNull);
    });

    test('có giờ: due là giờ bắt đầu, end là giờ kết thúc', () {
      final task = build(date: date, allDay: false, start: nine, end: ten);
      expect(task.due, DateTime(2026, 10, 29, 9));
      expect(task.end, DateTime(2026, 10, 29, 10, 30));
      expect(task.hasTime, isTrue);
    });

    test('có giờ nhưng không có giờ kết thúc', () {
      final task = build(date: date, allDay: false, start: nine);
      expect(task.hasTime, isTrue);
      expect(task.end, isNull);
    });

    test('không có ngày thì không có giờ', () {
      final task = build(allDay: false, start: nine, end: ten);
      expect(task.due, isNull);
      expect(task.hasTime, isFalse);
      expect(task.end, isNull);
    });

    test('cắt khoảng trắng và giữ các trường khác', () {
      final task = build(date: date);
      expect((task.title, task.note), ('Học bài', 'ghi chú'));
      expect(task.id, 'a');
      expect(task.createdAt, created);
      expect(task.reminderMinutes, 30);
      expect(task.repeatRule, RepeatRule.weekly);
      expect(task.priority, Priority.high);
      expect(task.tagId, 'tag-study');
      expect(task.done, isFalse);
    });
  });

  group('repeatDescription', () {
    test('không lặp hoặc chưa có ngày thì không có mô tả', () {
      expect(repeatDescription(date, nine, RepeatRule.none), isNull);
      expect(repeatDescription(null, nine, RepeatRule.daily), isNull);
    });

    test('lặp ngày, tuần, tháng kèm giờ', () {
      expect(
        repeatDescription(date, nine, RepeatRule.daily),
        'Lặp mỗi ngày lúc 09:00',
      );
      expect(
        repeatDescription(date, ten, RepeatRule.weekly),
        'Lặp mỗi Thứ Năm hằng tuần lúc 10:30',
      );
      expect(
        repeatDescription(date, nine, RepeatRule.monthly),
        startsWith('Lặp ngày 29 hằng tháng'),
      );
    });

    test('cả ngày thì không có "lúc"', () {
      expect(
        repeatDescription(date, null, RepeatRule.weekly),
        'Lặp mỗi Thứ Năm hằng tuần',
      );
    });

    test('ngày cuối tháng có ghi chú về tháng ngắn', () {
      expect(
        repeatDescription(DateTime(2026, 1, 31), null, RepeatRule.monthly),
        contains('tháng ngắn hơn'),
      );
      expect(
        repeatDescription(DateTime(2026, 1, 28), null, RepeatRule.monthly),
        'Lặp ngày 28 hằng tháng',
      );
    });
  });
}
