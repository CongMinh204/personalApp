import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/habit.dart';
import '../../data/repositories/habit_repository.dart';
import 'habit_logic.dart';

/// Các thói quen đã lưu trữ: khôi phục hoặc xóa hẳn. Mở từ tab Thói quen.
class HabitArchivedScreen extends StatefulWidget {
  const HabitArchivedScreen({super.key});

  @override
  State<HabitArchivedScreen> createState() => _HabitArchivedScreenState();
}

class _HabitArchivedScreenState extends State<HabitArchivedScreen> {
  late final HabitRepository _repo = context.read<HabitRepository>();

  StreamSubscription<List<Habit>>? _sub;
  List<Habit>? _habits;
  Map<String, int> _best = const {};
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _sub = _repo.watchArchived().listen((habits) async {
      final id = ++_request;
      final best = <String, int>{};
      await Future.wait([
        for (final h in habits)
          _repo.bestStreakOf(h.id).then((v) => best[h.id] = v),
      ]);
      if (!mounted || id != _request) return;
      setState(() {
        _habits = habits;
        _best = best;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _restore(Habit habit) async {
    final messenger = ScaffoldMessenger.of(context);
    await _repo.setArchived(habit.id, false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Đã khôi phục "${habit.name}"')));
  }

  Future<void> _delete(Habit habit) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa hẳn thói quen này?'),
        content: Text(
          'Toàn bộ nhật ký và chuỗi ngày của "${habit.name}" sẽ bị xóa vĩnh '
          'viễn. Không thể hoàn tác.',
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
            child: const Text('Xóa hẳn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await _repo.delete(habit.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Đã xóa "${habit.name}"')));
  }

  @override
  Widget build(BuildContext context) {
    final habits = _habits;
    return Scaffold(
      appBar: AppBar(title: const Text('Đã lưu trữ')),
      body: habits == null
          ? const Center(child: CircularProgressIndicator())
          : habits.isEmpty
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Text(
                    'Thói quen đã lưu trữ không hiện ở danh sách và không nhắc '
                    'nữa. Lịch sử và chuỗi ngày vẫn được giữ.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
                for (final habit in habits) ...[
                  _ArchivedTile(
                    habit: habit,
                    best: _best[habit.id] ?? 0,
                    onRestore: () => _restore(habit),
                    onDelete: () => _delete(habit),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class _ArchivedTile extends StatelessWidget {
  const _ArchivedTile({
    required this.habit,
    required this.best,
    required this.onRestore,
    required this.onDelete,
  });

  final Habit habit;
  final int best;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final at = habit.archivedAt;
    final date = at == null
        ? ''
        : ' · lưu trữ ${at.day.toString().padLeft(2, '0')}/'
              '${at.month.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                habitIconData(habit.icon),
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Chuỗi dài nhất $best ngày$date',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRestore, child: const Text('Khôi phục')),
            IconButton(
              tooltip: 'Xóa hẳn ${habit.name}',
              color: scheme.error,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 36,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có thói quen nào được lưu trữ',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Thói quen bạn lưu trữ sẽ nằm ở đây.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
