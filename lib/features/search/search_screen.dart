import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/routes.dart';
import '../../data/models/tag.dart';
import '../../data/models/task.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../utils/vi_date.dart';
import '../tasks/task_actions.dart';
import '../today/widgets/task_tile.dart';
import 'recent_searches.dart';
import 'search_filter.dart';

/// Tìm việc theo tiêu đề, ghi chú và tên nhãn. Mở từ header màn Hôm nay.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.clock = DateTime.now});

  /// Nguồn thời gian hiện tại; thay bằng giờ cố định khi test.
  final DateTime Function() clock;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TaskRepository _tasks = context.read<TaskRepository>();
  late final TagRepository _tagRepo = context.read<TagRepository>();
  late final TaskActions _actions = TaskActions(_tasks, clock: widget.clock);

  final _controller = TextEditingController();
  final _focus = FocusNode();

  StreamSubscription<List<Task>>? _taskSub;
  StreamSubscription<List<Tag>>? _tagSub;

  List<Task> _results = const [];
  List<Tag> _tags = const [];
  SearchFilter _filter = SearchFilter.all;

  RecentSearches _recent = const RecentSearches();
  RecentSearchesStore? _store;

  // Mỗi lần tìm tăng số này; kết quả của lần tìm cũ (đến trễ) bị bỏ.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    // Việc hoặc nhãn đổi (tick xong, sửa, xóa...) thì tìm lại.
    _taskSub = _tasks.watchAll().listen((_) => _search());
    _tagSub = _tagRepo.watchAll().listen(_onTags);
    // Đặt con trỏ vào ô tìm kiếm một lần khi mở.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    _tagSub?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final store = RecentSearchesStore(await SharedPreferences.getInstance());
    if (!mounted) return;
    setState(() {
      _store = store;
      _recent = store.load();
    });
  }

  void _onTags(List<Tag> tags) {
    if (!mounted) return;
    setState(() {
      _tags = tags;
      // Nhãn đang lọc đã bị xóa thì quay về Tất cả.
      final tagId = _filter.tagId;
      if (tagId != null && !tags.any((t) => t.id == tagId)) {
        _filter = SearchFilter.all;
      }
    });
    _search();
  }

  Future<void> _search() async {
    final id = ++_request;
    final query = _controller.text;
    final found = query.trim().isEmpty
        ? const <Task>[]
        : await _tasks.search(query);
    if (!mounted || id != _request) return;
    setState(() => _results = found);
  }

  void _setQuery(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
    _search();
  }

  /// Ghi nhớ từ khóa hiện tại vào "Tìm gần đây".
  void _remember() {
    final next = _recent.add(_controller.text);
    setState(() => _recent = next);
    _store?.save(next);
  }

  void _clearRecent() {
    setState(() => _recent = _recent.clear());
    _store?.save(_recent);
  }

  Future<void> _toggleDone(Task task) async {
    final next = await _actions.toggleDone(task);
    if (next == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Đã tạo việc lặp kế tiếp (${taskTimeLabel(next, widget.clock())})',
          ),
        ),
      );
  }

  void _openDetail(Task task) {
    _remember();
    Navigator.of(context).pushNamed(AppRoutes.taskDetail, arguments: task.id);
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final visible = _filter.apply(_results);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            if (query.isNotEmpty) _filters(context),
            Expanded(
              child: query.isEmpty
                  ? _recentSection(context)
                  : visible.isEmpty
                  ? const _NoResults()
                  : _resultList(context, visible),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onChanged: (_) {
                setState(() {});
                _search();
              },
              onSubmitted: (_) => _remember(),
              decoration: InputDecoration(
                hintText: 'Tìm việc, ghi chú, nhãn',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: hasText
                    ? IconButton(
                        tooltip: 'Xóa từ khóa',
                        onPressed: () => _setQuery(''),
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final options = <(String, SearchFilter)>[
      ('Tất cả', SearchFilter.all),
      ('Chưa xong', SearchFilter.pending),
      ('Đã xong', SearchFilter.done),
      for (final tag in _tags) (tag.name, SearchFilter.tag(tag.id)),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, filter) = options[index];
          return ChoiceChip(
            label: Text(label),
            selected: _filter == filter,
            onSelected: (_) => setState(() => _filter = filter),
          );
        },
      ),
    );
  }

  Widget _resultList(BuildContext context, List<Task> visible) {
    final theme = Theme.of(context);
    final tagById = {for (final tag in _tags) tag.id: tag};
    final now = widget.clock();
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: visible.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text(
              '${visible.length} kết quả',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }
        final task = visible[index - 1];
        return TaskTile(
          task: task,
          tag: tagById[task.tagId],
          now: now,
          onToggle: () => _toggleDone(task),
          onTap: () => _openDetail(task),
        );
      },
    );
  }

  Widget _recentSection(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (_recent.isEmpty) {
      return Center(
        child: Text(
          'Nhập từ khóa để tìm việc',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'Tìm gần đây',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            TextButton(onPressed: _clearRecent, child: const Text('Xóa')),
          ],
        ),
        for (final text in _recent.items)
          ListTile(
            leading: Icon(Icons.history_rounded, color: muted),
            title: Text(text),
            onTap: () => _setQuery(text),
          ),
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

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
                Icons.search_off_rounded,
                size: 36,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy việc nào',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Thử từ khóa khác hoặc bỏ bớt bộ lọc.',
              textAlign: TextAlign.center,
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
