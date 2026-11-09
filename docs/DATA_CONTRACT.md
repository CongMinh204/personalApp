# Hợp đồng dữ liệu – personal_app

> Bản 1 · chờ nhóm duyệt · người giữ: A (nền tảng)

Tài liệu này chốt **model**, **bảng SQLite** và **interface repository** mà cả nhóm dùng chung. Code nằm trong `lib/data/`.

Bản SQLite sẽ làm ở bước 1. Trong lúc chờ, các màn dùng bản Fake (dữ liệu trong bộ nhớ) qua **đúng các interface này**, nên khi chuyển sang SQLite không phải sửa màn nào.

## 1. Quy tắc

- Chỉ A sửa `lib/data/` và file này. Ai cần thêm hay đổi trường, hàm thì nhắn nhóm; A cập nhật cả code lẫn tài liệu, rồi mọi người kéo về.
- Sau khi nhóm duyệt bản 1, **không đổi tên trường, tên cột hay chữ ký hàm**. Chỉ được *thêm*: trường mới có giá trị mặc định, hàm mới. Mỗi lần đổi bảng, A tăng version database và viết `onUpgrade`.
- Màn hình chỉ gọi interface trong `lib/data/repositories/`. Không gọi SQLite trực tiếp, không tự tạo bảng.

## 2. Quy ước chung

| Chủ đề | Quy ước |
|---|---|
| id | Chuỗi, tạo bằng `newId()` (`lib/data/ids.dart`) ngay lúc tạo bản ghi, trước khi lưu. Không bao giờ đổi, không được cấp lại sau khi xóa, không hiện trên giao diện. |
| id thông báo | `flutter_local_notifications` cần id kiểu số: dùng `stableIntId(task.id)`. Cùng một id luôn ra cùng một số. |
| Thời điểm | Cột `INTEGER` lưu `millisecondsSinceEpoch` theo giờ máy. |
| Ngày không có giờ | `Habit.startDate`, `HabitLog.date`: cột `TEXT` dạng `yyyy-MM-dd`; trong Dart là `DateTime` lúc 00:00. Việc "Cả ngày" có `due` lúc 00:00 và `hasTime = false`. |
| Giờ trong ngày | `Habit.reminderTime` (`TimeOfDay`) lưu số phút tính từ 00:00, ví dụ 20:00 → 1200. |
| Đúng/sai | `INTEGER` 0/1. |
| Enum | Lưu bằng `code` cố định (xem mục 3), không dùng `.index`. Đọc ra mã lạ thì nhận giá trị mặc định. |
| Khoảng thời gian | Kiểu `DateTimeRange`, **không tính `end`**. Tạo bằng `dayRange(ngày)`, `daysRange(ngàyĐầu, sốNgày)`, `monthRange(ngày)` trong `lib/utils/dates.dart`. Lưu ý: `showDateRangePicker` trả `end` là ngày cuối *có tính*, nên phải cộng thêm 1 ngày. |
| copyWith | Trường có thể trống thì truyền dạng hàm: `task.copyWith(tagId: () => null)` để bỏ nhãn, `task.copyWith(tagId: () => tag.id)` để gán nhãn. Bỏ qua tham số thì giữ nguyên giá trị cũ. `id` và `createdAt` không đổi được. |
| So sánh | Model không định nghĩa `==`; so sánh hai bản ghi bằng `id`. |
| Stream `watch…` | Phát ngay giá trị hiện tại khi được lắng nghe, rồi phát lại mỗi khi dữ liệu liên quan thay đổi. Dùng với `StreamBuilder`. |
| Lỗi | Tiêu đề/tên trống, id tham chiếu không tồn tại, giá trị ngoài miền → `ArgumentError`. Thêm bản ghi trùng id đã có → `StateError`. Tên nhãn trùng → `DuplicateTagNameException`. Sửa hoặc xóa id không tồn tại → bỏ qua, không báo lỗi. |

## 3. Model và bảng

### Task — bảng `tasks` (`lib/data/models/task.dart`)

| Trường | Kiểu Dart | Cột | Trống? | Ghi chú |
|---|---|---|---|---|
| `id` | `String` | `id TEXT PRIMARY KEY` | không | |
| `title` | `String` | `title TEXT` | không | không được rỗng |
| `note` | `String` | `note TEXT` | không | mặc định `''` |
| `tagId` | `String?` | `tag_id TEXT` → `tags.id` | có | `null` = Không nhãn. Mỗi việc tối đa một nhãn; xóa nhãn thì về `null` |
| `due` | `DateTime?` | `due_at INTEGER` | có | ngày hẹn, kèm giờ bắt đầu nếu `hasTime`. `null` = không có ngày (hiện ở nhóm Hôm nay) |
| `end` | `DateTime?` | `end_at INTEGER` | có | giờ kết thúc, chỉ dùng khi `hasTime` |
| `hasTime` | `bool` | `has_time INTEGER` | không | `false` = Cả ngày |
| `priority` | `Priority` | `priority INTEGER` | không | `low` 0 · `medium` 1 · `high` 2; mặc định `medium` |
| `done` | `bool` | `done INTEGER` | không | chỉ đổi bằng `setDone` |
| `completedAt` | `DateTime?` | `completed_at INTEGER` | có | lúc bấm xong, do `setDone` đặt. Thống kê tính theo trường này |
| `reminderMinutes` | `int?` | `reminder_minutes INTEGER` | có | nhắc trước bao nhiêu phút: 0 = đúng giờ, `null` = không nhắc. Màn Sửa việc có các mức 0, 5, 15, 30, 60, 1440 |
| `repeatRule` | `RepeatRule` | `repeat_rule TEXT` | không | `none` · `day` · `week` · `month` |
| `createdAt` | `DateTime` | `created_at INTEGER` | không | |
| `subtaskDone`, `subtaskTotal` | `int` | — | — | chỉ đọc, không phải cột: repository đếm từ bảng `subtasks` mỗi lần đọc việc |

### Subtask — bảng `subtasks`

| Trường | Kiểu Dart | Cột | Trống? | Ghi chú |
|---|---|---|---|---|
| `id` | `String` | `id TEXT PRIMARY KEY` | không | |
| `taskId` | `String` | `task_id TEXT` → `tasks.id` | không | xóa việc thì việc con bị xóa theo |
| `title` | `String` | `title TEXT` | không | không được rỗng |
| `done` | `bool` | `done INTEGER` | không | |

Việc con hiện theo thứ tự thêm vào; không có kéo thả sắp xếp.

### Tag — bảng `tags`

| Trường | Kiểu Dart | Cột | Trống? | Ghi chú |
|---|---|---|---|---|
| `id` | `String` | `id TEXT PRIMARY KEY` | không | |
| `name` | `String` | `name TEXT` | không | lưu sau khi cắt khoảng trắng hai đầu; không trùng nhãn khác, không phân biệt hoa thường, kể cả chữ có dấu |
| `color` | `TagColor` | `color TEXT` | không | `violet` · `orange` · `green` · `red` · `grey` |

- Danh sách nhãn xếp theo thứ tự tạo.
- 4 nhãn mặc định có sẵn khi cài app (`lib/data/default_tags.dart`): `tag-study` Học tập (violet), `tag-work` Công việc (orange), `tag-personal` Cá nhân (green), `tag-health` Sức khỏe (red). Trong code dùng `DefaultTagIds.study`, `DefaultTagIds.work`…
- Màu badge: `TaskColors.of(context).tag(tag.color)` trả về `(nền, chữ)` đúng cho cả sáng lẫn tối. Các tông này cố định, không đổi theo màu nhấn.

### FocusSession — bảng `focus_sessions`

| Trường | Kiểu Dart | Cột | Trống? | Ghi chú |
|---|---|---|---|---|
| `id` | `String` | `id TEXT PRIMARY KEY` | không | |
| `taskId` | `String?` | `task_id TEXT` → `tasks.id` | có | `null` = Không gắn việc. Xóa việc thì về `null`, lịch sử vẫn giữ |
| `type` | `FocusType` | `type TEXT` | không | `pomodoro` · `short` (nghỉ ngắn) · `long` (nghỉ dài) · `custom`. `type.isFocus` đúng với pomodoro và custom |
| `startedAt` | `DateTime` | `started_at INTEGER` | không | |
| `durationSec` | `int` | `duration_sec INTEGER` | không | số giây đã chạy thực tế; phiên bỏ dở thì ít hơn thời lượng đặt |
| `completed` | `bool` | `completed INTEGER` | không | `true` = chạy hết giờ, `false` = bỏ dở |

Getter `endedAt` = `startedAt` + `durationSec`.

### Habit — bảng `habits`

| Trường | Kiểu Dart | Cột | Trống? | Ghi chú |
|---|---|---|---|---|
| `id` | `String` | `id TEXT PRIMARY KEY` | không | |
| `name` | `String` | `name TEXT` | không | không được rỗng |
| `icon` | `String` | `icon TEXT` | không | khóa biểu tượng: `drop`, `book`, `heart`, `moon`, `bolt`. E tự ánh xạ sang `IconData` và được thêm khóa mới. Không lưu mã `IconData`, vì làm hỏng bước build release |
| `color` | `Color` | `color INTEGER` (ARGB) | không | gợi ý theo mockup: `#5B4FE0`, `#1E6FD9`, `#23774F`, `#C2410C`, `#BE185D` |
| `repeatDays` | `Set<int>` | `repeat_days TEXT`, ví dụ `'1,3,5'` | không | 1 = Thứ Hai … 7 = Chủ Nhật (như `DateTime.weekday`); không được rỗng; mặc định cả tuần |
| `goalPerDay` | `int` | `goal_per_day INTEGER` | không | ≥ 1; số lần cần làm trong ngày để tính là xong |
| `unit` | `String` | `unit TEXT` | không | đơn vị, ví dụ `'ly'`; có thể rỗng |
| `reminderTime` | `TimeOfDay?` | `reminder_time INTEGER` (phút) | có | `null` = không nhắc |
| `startDate` | `DateTime` | `start_date TEXT` (`yyyy-MM-dd`) | không | những ngày trước đó không tính vào chuỗi |
| `archivedAt` | `DateTime?` | `archived_at INTEGER` | có | `null` = đang dùng. Getter `archived` = `archivedAt != null` |

### HabitLog — bảng `habit_logs` (khóa chính `habit_id` + `date`)

| Trường | Kiểu Dart | Cột | Trống? | Ghi chú |
|---|---|---|---|---|
| `habitId` | `String` | `habit_id TEXT` → `habits.id` | không | xóa thói quen thì nhật ký bị xóa theo |
| `date` | `DateTime` | `date TEXT` (`yyyy-MM-dd`) | không | |
| `count` | `int` | `count INTEGER` | không | số lần đã làm trong ngày; bằng 0 thì không lưu dòng |

### Khóa ngoại và index (làm ở bước 1)

- `tasks.tag_id` → `tags.id`, khi xóa nhãn: `SET NULL`
- `subtasks.task_id` → `tasks.id`, khi xóa việc: `CASCADE`
- `focus_sessions.task_id` → `tasks.id`, khi xóa việc: `SET NULL`
- `habit_logs.habit_id` → `habits.id`, khi xóa thói quen: `CASCADE`
- Index: `tasks(due_at)`, `tasks(tag_id)`, `tasks(completed_at)`, `subtasks(task_id)`, `focus_sessions(started_at)`, `focus_sessions(task_id)`

## 4. Repository

Từ bước 1, lấy repository qua Provider, ví dụ `context.read<TaskRepository>()`. Trước đó thì dùng bản Fake (mục 7).

### TaskRepository (`lib/data/repositories/task_repository.dart`)

| Hàm | Màn dùng | Ý nghĩa |
|---|---|---|
| `watchAll()` | Hôm nay | mọi việc, cả việc đã xong; chia nhóm Quá hạn/Hôm nay/Sắp tới làm trong bộ nhớ (`groupTasks`) |
| `getAll()` | chưa màn nào dùng | như `watchAll`, đọc một lần (dự phòng) |
| `watchByDay(day)` | Lịch (timeline) | việc có `due` trong ngày, sắp theo `due`; không gồm việc không có ngày |
| `watchByRange(range)` | Lịch tháng/tuần (chấm dưới ngày) | việc có `due` trong khoảng |
| `getUnfinished()` | Nhắc việc (C) | việc chưa xong, để lên lịch lại thông báo khi mở app |
| `getById(id)`, `watchById(id)` | Chi tiết, Sửa việc | trả `null` nếu không có |
| `search(query)` | Tìm kiếm | tìm trong tiêu đề, ghi chú, tên nhãn; không phân biệt hoa thường và dấu tiếng Việt ("hoc tap" ra "Học tập", chuẩn hóa bằng `foldVietnamese`); `query` rỗng → `[]`. Lọc Chưa xong/Đã xong/theo nhãn thì màn tự làm |
| `countDoneByDay(range)` | Thống kê | số việc xong mỗi ngày, tính theo `completedAt`; có đủ mọi ngày trong khoảng, ngày không có việc = 0 |
| `getCompletedInRange(range)` | Thống kê | việc có `completedAt` trong khoảng (để tính đúng hạn, thống kê theo nhãn) |
| `add(task, subtasks:)` | Thêm việc, hoàn tác xóa | `taskId` của từng việc con phải bằng `task.id` |
| `update(task, subtasks:)` | Sửa việc | không đổi `done`/`completedAt`. Có truyền `subtasks` thì thay toàn bộ việc con |
| `setDone(id, done)` | mọi chỗ có checkbox | xong: `completedAt` = bây giờ; bỏ xong: `completedAt` = `null` |
| `delete(id)` | Hôm nay, Chi tiết | xóa cả việc con; phiên tập trung chuyển thành Không gắn việc |
| `deleteCompleted()` | Cài đặt | trả về số việc đã xóa |
| `getSubtasks(taskId)`, `watchSubtasks(taskId)` | Sửa, Chi tiết | theo thứ tự thêm |
| `setSubtaskDone(id, done)` | Chi tiết | |

Thứ tự chung của danh sách việc: `due` tăng dần, việc không có ngày ở cuối; cùng `due` thì theo lúc tạo.

### TagRepository (`lib/data/repositories/tag_repository.dart`)

| Hàm | Màn dùng | Ý nghĩa |
|---|---|---|
| `watchAll()`, `getAll()`, `getById(id)` | Hôm nay (lọc), Sửa việc, Quản lý nhãn | theo thứ tự tạo |
| `watchTaskCounts()` | Quản lý nhãn | `tagId → số việc`, tính cả việc đã xong; nhãn chưa có việc thì không có trong map |
| `add(tag)`, `update(tag)` | Quản lý nhãn, Sửa việc ("+ Nhãn mới") | cắt khoảng trắng; tên trống → `ArgumentError`; tên trùng → `DuplicateTagNameException` |
| `delete(id)` | Quản lý nhãn | các việc đang dùng nhãn chuyển thành Không nhãn |

### FocusRepository (`lib/data/repositories/focus_repository.dart`)

| Hàm | Màn dùng | Ý nghĩa |
|---|---|---|
| `add(session)` | Hẹn giờ | lưu khi phiên chạy hết giờ hoặc bị dừng |
| `sessionsByRange(range)`, `watchByRange(range)` | Lịch sử tập trung, Thống kê | theo `startedAt`, mới nhất trước |
| `totalForTask(taskId)` | Chi tiết việc ("Đã tập trung 50 phút · 2 phiên") | `FocusTotal(seconds, sessions)`: chỉ cộng phiên tập trung (`type.isFocus`), kể cả phiên bỏ dở |
| `delete(id)` | Lịch sử tập trung | |

### HabitRepository (`lib/data/repositories/habit_repository.dart`)

| Hàm | Màn dùng | Ý nghĩa |
|---|---|---|
| `watchActive()` | Thói quen | thói quen đang dùng, theo thứ tự tạo |
| `watchArchived()` | Đã lưu trữ | mới lưu trữ trước |
| `getById(id)`, `watchById(id)` | Chi tiết, Sửa | |
| `add(habit)`, `update(habit)` | Thêm/sửa | tên trống, `goalPerDay` < 1, `repeatDays` rỗng hoặc ngoài 1–7 → `ArgumentError`. `update` không đổi `archivedAt` |
| `setArchived(id, archived)` | Sửa, Đã lưu trữ (Khôi phục) | lưu trữ: `archivedAt` = bây giờ; khôi phục: `null` |
| `delete(id)` | Đã lưu trữ (Xóa hẳn) | xóa luôn nhật ký |
| `watchCountsOn(day)` | Thói quen | `habitId → số lần` trong ngày; không có trong map = 0 |
| `logsByRange(habitId, range)` | Chi tiết | theo ngày tăng dần |
| `setCount(habitId, day, count)`, `increment(habitId, day)` | Thói quen, Chi tiết | `count` ≥ 0, bằng 0 thì xóa nhật ký ngày đó; `increment` trả về số lần mới |
| `streakOf(habitId, today:)`, `bestStreakOf(habitId)` | Thói quen, Chi tiết, Đã lưu trữ | quy tắc ở mục 5 |

## 5. Quy tắc chuỗi ngày

- Chỉ xét ngày có lịch (thứ nằm trong `repeatDays`), từ `startDate` đến hôm nay.
- Một ngày có lịch là "xong" khi `count ≥ goalPerDay`.
- Ngày không có lịch thì bỏ qua: không cộng, cũng không làm đứt chuỗi.
- Hôm nay chưa xong thì chưa làm đứt chuỗi, vì ngày chưa kết thúc.
- Chuỗi hiện tại = số ngày "xong" liên tiếp, tính ngược từ hôm nay. Chuỗi dài nhất tính từ `startDate`.

Code nằm ở `lib/data/habit_streak.dart`, đã có test. E muốn đổi quy tắc thì báo A; chỉ sửa trong file này và giữ nguyên chữ ký hàm.

## 6. Lưu ý cho từng mảng

**B (Việc)**
- Hoàn thành hay bỏ hoàn thành đều gọi `setDone`; không sửa `done` qua `update`.
- Việc lặp lại: khi hoàn thành, giữ nguyên việc đã xong (để Thống kê đếm được) và `add` lần kế tiếp thành một việc mới, id mới.
  - Việc con của lần kế tiếp được sao chép sang, đặt lại chưa xong, id mới.
  - Giờ bắt đầu, giờ kết thúc, nhãn, ưu tiên, nhắc trước và kiểu lặp giữ nguyên.
  - Hoàn thành trễ thì nhảy tới lần lặp đầu tiên từ hôm nay trở đi (không tạo việc đã quá hạn).
  - Lặp theo tháng giữ cùng ngày trong tháng, tháng ngắn hơn lấy ngày cuối tháng (31/1 → 28/2); các lần sau tính tiếp từ ngày đã rút ngắn vì việc không lưu ngày gốc.
  - Việc không có ngày thì không tạo lần kế tiếp; việc lặp lại bắt buộc có ngày.
  - Bỏ đánh dấu xong không xóa việc kế tiếp đã tạo.
- Xóa rồi hoàn tác: các phiên tập trung của việc đó đã chuyển thành "không gắn việc" và không được gắn lại.
- Mỗi việc chỉ có một nhãn; bấm lại nhãn đang chọn để bỏ nhãn. Nhắc trước cũng bỏ được bằng cách bấm lại mức đang chọn (`reminderMinutes` = `null`).
- Hoàn tác xóa: giữ lại task và việc con trước khi xóa, rồi gọi `add(task, subtasks: …)` với đúng các bản cũ.
- "Tìm gần đây" lưu bằng shared_preferences, key `search_recent` (danh sách chuỗi, mới nhất trước, tối đa 5, không trùng không phân biệt hoa thường). Từ khóa được ghi nhớ khi nhấn Enter hoặc khi bấm vào một kết quả.

**C (Lịch, nhắc việc, thống kê)**
- id thông báo = `stableIntId(task.id)`. Khi mở app, lên lịch lại từ `getUnfinished()`.
- Việc không có giờ (`hasTime = false`) thì nhắc lúc mấy giờ do C chọn, rồi ghi quyết định vào đây.
- Đề xuất cách tính "đúng hạn" (C chốt rồi ghi lại vào đây):
  - việc có giờ: xong trước `end` (nếu có) hoặc trước `due`;
  - việc cả ngày: xong trước khi hết ngày `due`;
  - việc không có ngày: không tính.

**D (Hẹn giờ)**
- Lưu `FocusSession` khi phiên hết giờ hoặc bị dừng giữa chừng. `durationSec` là thời gian chạy thực tế, không tính lúc tạm dừng.
- Phiên **hoàn thành** (`completed = true`): chạy hết giờ, `durationSec` bằng thời lượng đặt.
- Phiên **bỏ dở** (`completed = false`): bị dừng trước khi hết giờ bằng Đặt lại, Bỏ qua phiên hoặc đổi chế độ khi đang chạy hoặc tạm dừng. Chỉ lưu nếu đã chạy từ **10 giây** trở lên (ít hơn coi như bấm nhầm). Chưa bấm Chạy thì không lưu gì.
- `taskId` là việc chọn lúc bắt đầu phiên và không đổi được khi phiên đang chạy; `null` nếu không gắn việc, hoặc việc đã bị xóa trong lúc đếm.
- Giờ nghỉ (`short`, `long`) vẫn lưu nhưng **không gắn việc** (`taskId` = `null`) và không tính vào thời gian tập trung của việc. Lịch sử tập trung **không hiện** phiên nghỉ (theo mockup) và các số tóm tắt chỉ tính phiên tập trung.
- Chu kỳ Pomodoro: 4 phiên tập trung (`pomodoro`) xen nghỉ ngắn, sau phiên thứ 4 là nghỉ dài, rồi chu kỳ bắt đầu lại. Chế độ Tùy chỉnh (`custom`, 1–180 phút) đứng ngoài chu kỳ.
- **Bấm giờ (stopwatch) không lưu** vào lịch sử (hợp đồng không có loại phiên cho nó); các vòng chỉ để đo.
- Đồng hồ không được khôi phục nếu tắt hẳn app khi đang chạy (phiên đang chạy bị mất, không lưu).

**E (Thói quen)**
- `icon` là khóa chữ, `color` là `Color`.
- Nút "+1" gọi `increment`; tích xong gọi `setCount(habitId, ngày, habit.goalPerDay)`.
- Lưu trữ/khôi phục bằng `setArchived`; xóa hẳn bằng `delete` (màn tự hỏi xác nhận).

## 7. Bản Fake và dữ liệu mẫu

- `FakeStore()` giống app mới cài: chỉ có 4 nhãn mặc định.
- `FakeStore.sample()` thêm dữ liệu mẫu tính theo ngày hiện tại (`lib/data/fake/sample_data.dart`):
  - 8 việc của màn Hôm nay (2 quá hạn, 4 hôm nay, 2 sắp tới) và 6 việc đã xong trong tuần trước;
  - 3 việc con của "Ôn tập PE Flutter";
  - 6 phiên hẹn giờ hôm nay và hôm qua;
  - 6 thói quen đang dùng, 3 đã lưu trữ, kèm nhật ký. Ví dụ "Uống 2 lít nước" có chuỗi 12 ngày, dài nhất 15.
- Các Fake repository dùng chung một `FakeStore`, nên xóa nhãn hay xóa việc cũng ảnh hưởng đúng sang repository khác, giống SQLite:

```dart
final store = FakeStore.sample();
final tasks = FakeTaskRepository(store);
final tags = FakeTagRepository(store);
final focus = FakeFocusRepository(store);
final habits = FakeHabitRepository(store);
```

- Từ bước 1, chỗ duy nhất chọn Fake hay SQLite là `lib/app/dependencies.dart`; các màn không tự tạo repository.
- Bộ test hợp đồng `test/data/repository_contract.dart` đang chạy cho bản Fake; từ bước 1 sẽ chạy thêm cho SQLite, để hai bản cư xử giống nhau.

## 8. Cài đặt dùng chung

Lưu bằng shared_preferences, đọc và ghi qua `SettingsController` (`lib/app/settings_controller.dart`, có sẵn trong Provider). Giá trị lưu hỏng hoặc ngoài khoảng thì dùng mặc định; setter nhận giá trị sai thì báo `ArgumentError`, không lưu.

| Key | Kiểu và khoảng hợp lệ | Mặc định | Ai đọc |
|---|---|---|---|
| `theme_mode` | `system` / `light` / `dark` | `system` | app |
| `accent_color` | một trong 5 màu ARGB: `0xFF5B4FE0`, `0xFF1E6FD9`, `0xFF23774F`, `0xFFC2410C`, `0xFFBE185D` | `0xFF5B4FE0` | app |
| `week_start` | 1 = Thứ Hai hoặc 7 = Chủ Nhật | 1 | Lịch, Thống kê |
| `default_reminder_minutes` | 0, 5, 15, 30, 60 hoặc 1440 | 15 | Thêm việc, Nhắc việc |
| `reminders_enabled` | bool | `true` | Nhắc việc |
| `morning_summary_enabled` | bool | `true` | Nhắc việc |
| `morning_summary_time` | số phút từ 00:00, 0–1439 | 420 (07:00) | Nhắc việc |
| `pomodoro_minutes` | 5–60 | 25 | Hẹn giờ |
| `short_break_minutes` | 1–30 | 5 | Hẹn giờ |
| `long_break_minutes` | 5–60 | 15 | Hẹn giờ |
| `auto_next_session` | bool | `false` | Hẹn giờ |

Màn Tìm kiếm tự lưu "tìm gần đây" bằng key bắt đầu bằng `search_`.

## 9. Lịch sử thay đổi

| Bản | Ngày | Nội dung |
|---|---|---|
| 1 | 07/11/2026 | Bản đầu, chờ nhóm duyệt |
| 1.1 | 09/11/2026 | Dự án chuyển sang một người làm; hợp đồng không đổi schema, vẫn là khung thiết kế cho bước 1 trở đi |
| 1.2 | 09/11/2026 | Chốt mục 8 (cài đặt dùng chung) khi làm `SettingsController`: thêm 5 key (`reminders_enabled`, `morning_summary_enabled`, `short_break_minutes`, `long_break_minutes`, `auto_next_session`) và khoảng hợp lệ của từng key. Schema database không đổi |
| 1.3 | 10/11/2026 | Bước 4: ghi thêm quy tắc việc lặp lại, hoàn tác xóa và chọn nhãn/nhắc trước ở mục 6 (B). Schema database không đổi |
| 1.4 | 10/11/2026 | Màn Tìm kiếm: chốt key `search_recent` và quy tắc ghi nhớ từ khóa ở mục 6; `search` bỏ qua dấu tiếng Việt (trước đây chỉ bỏ qua hoa thường). Schema database không đổi |
| 1.5 | 10/11/2026 | Bước 5 (Hẹn giờ): chốt ở mục 6 (D) quy tắc phiên hoàn thành và bỏ dở, ngưỡng lưu 10 giây, phiên nghỉ không gắn việc và không hiện trong lịch sử, bấm giờ không lưu. Schema database không đổi |
