import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_info.dart';
import '../../app/routes.dart';
import '../../app/settings_controller.dart';
import '../../data/models/tag.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/task_repository.dart';
import 'settings_labels.dart';
import 'widgets/settings_dialogs.dart';
import 'widgets/settings_widgets.dart';

/// Màn Cài đặt, mở từ biểu tượng bánh răng ở header Hôm nay.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SettingsSection(
            title: 'Giao diện',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chủ đề', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 10),
                    ThemeModePicker(
                      selected: settings.themeMode,
                      onChanged: settings.setThemeMode,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Màu nhấn', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 10),
                    AccentPicker(
                      selected: settings.accent,
                      onChanged: settings.setAccent,
                    ),
                  ],
                ),
              ),
              SettingsRow(
                title: 'Tuần bắt đầu từ',
                value: weekStartLabel(settings.weekStart),
                onTap: () => _pickWeekStart(context, settings),
              ),
            ],
          ),
          SettingsSection(
            title: 'Thông báo',
            children: [
              SettingsSwitchRow(
                title: 'Nhắc việc',
                subtitle: 'Thông báo trước giờ hẹn',
                value: settings.remindersEnabled,
                onChanged: settings.setRemindersEnabled,
              ),
              SettingsRow(
                title: 'Nhắc trước mặc định',
                value: reminderLabel(settings.defaultReminderMinutes),
                onTap: () => _pickReminder(context, settings),
              ),
              // Chưa chọn được âm báo (để sau), chỉ hiện giá trị mặc định.
              const SettingsRow(title: 'Âm báo', value: 'Mặc định'),
              SettingsSwitchRow(
                title: 'Tóm tắt buổi sáng',
                subtitle:
                    '${clockLabel(settings.morningSummaryMinutes)} · '
                    'danh sách việc trong ngày',
                value: settings.morningSummaryEnabled,
                onChanged: settings.setMorningSummaryEnabled,
                // Bấm vào chữ để đổi giờ, bấm công tắc để bật hoặc tắt.
                onTap: settings.morningSummaryEnabled
                    ? () => _pickMorningTime(context, settings)
                    : null,
              ),
            ],
          ),
          SettingsSection(
            title: 'Hẹn giờ',
            children: [
              SettingsRow(
                title: 'Phiên Pomodoro',
                value: minutesLabel(settings.pomodoroMinutes),
                onTap: () => _pickPomodoro(context, settings),
              ),
              SettingsRow(
                title: 'Nghỉ ngắn / nghỉ dài',
                value:
                    '${settings.shortBreakMinutes} / '
                    '${minutesLabel(settings.longBreakMinutes)}',
                onTap: () => _pickBreaks(context, settings),
              ),
              SettingsSwitchRow(
                title: 'Tự chạy phiên tiếp theo',
                subtitle: 'Chuyển ngay sang giờ nghỉ khi hết phiên',
                value: settings.autoNextSession,
                onChanged: settings.setAutoNextSession,
              ),
            ],
          ),
          SettingsSection(
            title: 'Dữ liệu',
            children: [
              StreamBuilder<List<Tag>>(
                stream: context.read<TagRepository>().watchAll(),
                builder: (context, snapshot) => SettingsRow(
                  title: 'Quản lý nhãn',
                  value: '${snapshot.data?.length ?? 0} nhãn',
                  showChevron: true,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.tagManager),
                ),
              ),
              SettingsRow(
                title: 'Xóa các việc đã hoàn thành',
                destructive: true,
                onTap: () => _deleteCompleted(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Phiên bản $appVersion',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickWeekStart(
    BuildContext context,
    SettingsController settings,
  ) async {
    final value = await showChoiceDialog(
      context,
      title: 'Tuần bắt đầu từ',
      values: const [1, 7],
      selected: settings.weekStart,
      labelOf: weekStartLabel,
    );
    if (value != null) await settings.setWeekStart(value);
  }

  Future<void> _pickReminder(
    BuildContext context,
    SettingsController settings,
  ) async {
    final value = await showChoiceDialog(
      context,
      title: 'Nhắc trước mặc định',
      values: reminderChoices,
      selected: settings.defaultReminderMinutes,
      labelOf: reminderLabel,
    );
    if (value != null) await settings.setDefaultReminderMinutes(value);
  }

  Future<void> _pickMorningTime(
    BuildContext context,
    SettingsController settings,
  ) async {
    final minutes = settings.morningSummaryMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: 'Giờ gửi tóm tắt buổi sáng',
    );
    if (picked != null) {
      await settings.setMorningSummaryMinutes(picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _pickPomodoro(
    BuildContext context,
    SettingsController settings,
  ) async {
    final values = await showMinutesDialog(
      context,
      title: 'Phiên Pomodoro',
      specs: [
        MinutesSpec(
          label: 'Thời lượng',
          value: settings.pomodoroMinutes,
          min: SettingsController.pomodoroRange.$1,
          max: SettingsController.pomodoroRange.$2,
          step: 5,
        ),
      ],
    );
    if (values != null) await settings.setPomodoroMinutes(values[0]);
  }

  Future<void> _pickBreaks(
    BuildContext context,
    SettingsController settings,
  ) async {
    final values = await showMinutesDialog(
      context,
      title: 'Nghỉ ngắn / nghỉ dài',
      specs: [
        MinutesSpec(
          label: 'Nghỉ ngắn',
          value: settings.shortBreakMinutes,
          min: SettingsController.shortBreakRange.$1,
          max: SettingsController.shortBreakRange.$2,
          step: 1,
        ),
        MinutesSpec(
          label: 'Nghỉ dài',
          value: settings.longBreakMinutes,
          min: SettingsController.longBreakRange.$1,
          max: SettingsController.longBreakRange.$2,
          step: 5,
        ),
      ],
    );
    if (values == null) return;
    await settings.setShortBreakMinutes(values[0]);
    await settings.setLongBreakMinutes(values[1]);
  }

  /// Xóa mọi việc đã hoàn thành sau khi hỏi lại. Nói rõ Thống kê các ngày
  /// trước cũng mất vì thống kê tính từ chính các việc này.
  Future<void> _deleteCompleted(BuildContext context) async {
    final tasks = context.read<TaskRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final completed = (await tasks.getAll()).where((t) => t.done).length;
    if (!context.mounted) return;

    if (completed == 0) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Không có việc nào đã hoàn thành')),
        );
      return;
    }

    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa $completed việc đã hoàn thành?'),
        content: const Text(
          'Các việc này và việc con của chúng sẽ bị xóa vĩnh viễn. '
          'Thống kê các ngày trước cũng mất theo. Không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deleted = await tasks.deleteCompleted();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Đã xóa $deleted việc')));
  }
}
