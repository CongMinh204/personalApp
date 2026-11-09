class Habit {
  const Habit({
    required this.id,
    required this.title,
    this.description = '',
    this.iconCode = 0xe28d, // Mặc định icon thể thao
    this.streak = 0,
    this.completedDates = const [],
    this.targetDaysPerWeek = 7,
    this.durationMinutes = 20, // Thời gian đếm ngược mặc định (phút)
    this.isArchived = false,
  });

  final String id;
  final String title;
  final String description;
  final int iconCode;
  final int streak;
  final List<String> completedDates; // Lưu ngày theo chuỗi YYYY-MM-DD
  final int targetDaysPerWeek;
  final int durationMinutes;
  final bool isArchived;

  bool isCompletedToday(DateTime now) {
    final key =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return completedDates.contains(key);
  }

  Habit toggleToday(DateTime now) {
    final key =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final isDone = completedDates.contains(key);
    final updatedList = List<String>.from(completedDates);

    int newStreak = streak;
    if (isDone) {
      updatedList.remove(key);
      newStreak = (newStreak > 0) ? newStreak - 1 : 0;
    } else {
      updatedList.add(key);
      newStreak += 1;
    }

    return copyWith(streak: newStreak, completedDates: updatedList);
  }

  Habit copyWith({
    String? id,
    String? title,
    String? description,
    int? iconCode,
    int? streak,
    List<String>? completedDates,
    int? targetDaysPerWeek,
    int? durationMinutes,
    bool? isArchived,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconCode: iconCode ?? this.iconCode,
      streak: streak ?? this.streak,
      completedDates: completedDates ?? this.completedDates,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
