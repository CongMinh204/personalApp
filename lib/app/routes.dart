import 'package:flutter/material.dart';

import '../features/focus_history/focus_history_screen.dart';
import '../features/habits/habit_archived_screen.dart';
import '../features/habits/habit_detail_screen.dart';
import '../features/habits/habit_edit_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/tag_manager_screen.dart';
import '../features/tasks/task_detail_screen.dart';
import '../features/tasks/task_edit_screen.dart';

/// Tên và cách mở các màn không phải tab. Màn nào cũng mở bằng
/// `Navigator.pushNamed(context, AppRoutes.xxx)`, không tự import màn khác.
///
/// Màn chưa làm thì mở trang "Sắp có" có nút quay lại. Khi làm xong một màn,
/// thay trang đó trong [_builders] bằng màn thật.
abstract final class AppRoutes {
  /// Cài đặt, mở từ header Hôm nay.
  static const settings = '/settings';

  /// Quản lý nhãn, mở từ Cài đặt.
  static const tagManager = '/settings/tags';

  /// Tìm kiếm, mở từ header Hôm nay.
  static const search = '/search';

  /// Chi tiết việc, mở khi bấm tên việc. Tham số: id việc (`String`).
  static const taskDetail = '/task';

  /// Thêm việc (không tham số) hoặc sửa việc (tham số: id việc, `String`).
  static const taskEdit = '/task/edit';

  /// Lịch sử tập trung, mở từ header màn Hẹn giờ.
  static const focusHistory = '/timer/history';

  /// Thêm thói quen (không tham số) hoặc sửa (tham số: id, `String`).
  static const habitEdit = '/habit/edit';

  /// Chi tiết thói quen. Tham số: id thói quen (`String`).
  static const habitDetail = '/habit';

  /// Thói quen đã lưu trữ.
  static const habitArchived = '/habit/archived';

  static const _titles = {
    settings: 'Cài đặt',
    tagManager: 'Quản lý nhãn',
    search: 'Tìm kiếm',
    taskDetail: 'Chi tiết việc',
    taskEdit: 'Thêm/sửa việc',
    focusHistory: 'Lịch sử tập trung',
    habitEdit: 'Thêm/sửa thói quen',
    habitDetail: 'Chi tiết thói quen',
    habitArchived: 'Thói quen đã lưu trữ',
  };

  /// Màn thật của từng route, thêm vào khi màn được làm xong.
  static final _builders = <String, WidgetBuilder>{
    settings: (_) => const SettingsScreen(),
    tagManager: (_) => const TagManagerScreen(),
    search: (_) => const SearchScreen(),
    focusHistory: (_) => const FocusHistoryScreen(),
    habitEdit: (context) {
      // Tham số là id thói quen (sửa) hoặc không có (thêm).
      final argument = ModalRoute.of(context)?.settings.arguments;
      return HabitEditScreen(habitId: argument is String ? argument : null);
    },
    habitArchived: (_) => const HabitArchivedScreen(),
    habitDetail: (context) =>
        HabitDetailScreen(habitId: _argument<String>(context)!),
    taskDetail: (context) =>
        TaskDetailScreen(taskId: _argument<String>(context)!),
    taskEdit: (context) {
      // Tham số là id việc (sửa) hoặc ngày điền sẵn (thêm), hoặc không có.
      final argument = ModalRoute.of(context)?.settings.arguments;
      return TaskEditScreen(
        taskId: argument is String ? argument : null,
        initialDate: argument is DateTime ? argument : null,
      );
    },
  };

  static T? _argument<T>(BuildContext context) {
    final argument = ModalRoute.of(context)?.settings.arguments;
    return argument is T ? argument : null;
  }

  /// Dùng cho `MaterialApp.onGenerateRoute`.
  static Route<dynamic>? onGenerateRoute(RouteSettings route) {
    final title = _titles[route.name];
    if (title == null) return null;
    final builder =
        _builders[route.name] ?? (_) => ComingSoonPage(title: title);
    return MaterialPageRoute<Object?>(builder: builder, settings: route);
  }
}

/// Trang tạm cho màn chưa làm, có nút quay lại.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          'Sắp có',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
