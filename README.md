# Việc của tôi (personal_app)

Ứng dụng todo cá nhân viết bằng Flutter, giao diện tiếng Việt, tối giản, bo góc lớn, màu nhấn xanh tím.

Hiện có các màn **Hôm nay**, **Thêm/sửa việc**, **Chi tiết việc**, **Cài đặt** và **Quản lý nhãn**. Các tab Lịch, Hẹn giờ, Thống kê, Thói quen và màn Tìm kiếm đang hiện "Sắp có".

## Tính năng

- Thanh tab dưới cùng 5 mục: Hôm nay, Lịch, Hẹn giờ, Thống kê, Thói quen. Cài đặt mở từ biểu tượng bánh răng ở header Hôm nay; chủ đề sáng/tối và màu nhấn lưu trong cài đặt (mặc định theo hệ thống).
- Màn Hôm nay (đọc và ghi qua `TaskRepository`, nhãn lấy từ `TagRepository`):
  - Lọc theo nhãn (nhãn thêm ở Quản lý nhãn hiện ra ngay).
  - Thẻ tiến độ trong ngày, thẻ "Xong hết việc hôm nay!" và màn trống.
  - Ba nhóm việc: Quá hạn, Hôm nay, Sắp tới.
  - Bấm checkbox để hoàn thành, vuốt trái để xóa (có "Hoàn tác", khôi phục cả việc con).
  - Việc có lặp lại: hoàn thành thì tự tạo việc cho lần kế tiếp.
  - Nút đồng hồ trên mỗi việc chưa xong mở tab Hẹn giờ với việc đó chọn sẵn.
  - Bấm vào việc mở Chi tiết; nút "+" mở form Thêm việc.
- Thêm/sửa việc: tiêu đề, ghi chú, ngày (hoặc không có ngày), cả ngày hoặc giờ bắt đầu–kết thúc, nhắc trước, lặp lại, ưu tiên, một nhãn (có thể tạo nhãn mới ngay trong form), việc con.
- Chi tiết việc: thông tin, việc con, thời gian đã tập trung, nút Bắt đầu / Sửa / Xóa.
- Cài đặt (bánh răng ở header Hôm nay): chủ đề sáng/tối/hệ thống, 5 màu nhấn, ngày đầu tuần, nhắc trước mặc định, Pomodoro và giờ nghỉ, xóa các việc đã hoàn thành. Quản lý nhãn (mở từ Cài đặt): thêm, sửa, xóa nhãn.
- Tầng lưu trữ SQLite (sqflite) đã xong và có test; Android, iOS, macOS dùng SQLite, web và Windows dùng bản Fake trong bộ nhớ (`lib/app/dependencies.dart`). Trên Android database lúc đầu trống; bản Fake (web, Windows) có dữ liệu mẫu ở `lib/data/fake/sample_data.dart`.
- Model, bảng và repository dùng chung của nhóm: [docs/DATA_CONTRACT.md](docs/DATA_CONTRACT.md).

## Hướng dẫn chạy dự án

### 1. Chuẩn bị

- **Flutter SDK 3.47 trở lên** (`pubspec.yaml` yêu cầu Dart `^3.13.2`). Kiểm tra bằng `flutter --version`.
- **Git**.
- **VS Code** cài extension *Flutter* (tự kèm extension *Dart*).

### 2. Lấy code và cài package

```bash
git clone https://github.com/CongMinh204/personalApp.git
cd personalApp
flutter pub get
```

### 3. Chạy app

**Chrome hoặc Edge (cách nhanh nhất):**

```bash
flutter run -d chrome
```

Thay bằng `flutter run -d edge` nếu muốn dùng Edge. Lần đầu biên dịch mất khoảng 1 phút. Muốn xem đúng khung điện thoại, nhấn F12 rồi Ctrl+Shift+M.

**Trong VS Code:** mở thư mục dự án, chọn thiết bị (Chrome) ở góc phải thanh trạng thái, nhấn F5 (có debug) hoặc Ctrl+F5 (không debug).

**Android:**

```bash
flutter emulators                      # xem danh sách máy ảo
flutter emulators --launch <tên_máy_ảo>
flutter run
```

Với điện thoại thật: bật *Gỡ lỗi USB*, cắm cáp, kiểm tra bằng `flutter devices`, rồi `flutter run`.

**Windows desktop:** cần cài Visual Studio (bản Community) với workload **Desktop development with C++**, sau đó:

```bash
flutter doctor
flutter run -d windows
```

### 4. Phím tắt khi app đang chạy

| Phím | Tác dụng |
|---|---|
| `r` | Hot reload, giữ nguyên dữ liệu |
| `R` | Hot restart, nạp lại dữ liệu mẫu |
| `q` | Thoát |

Trong VS Code, lưu file (Ctrl+S) là tự hot reload.

### 5. Kiểm tra code và test

```bash
flutter analyze   # No issues found!
flutter test      # All tests passed!
```

### Gặp lỗi

- `flutter doctor` liệt kê những gì máy còn thiếu.
- Lỗi SDK version khi `pub get`: chạy `flutter upgrade`.
- Lỗi lạ sau khi kéo code mới: `flutter clean` rồi `flutter pub get`.

## Cấu trúc thư mục `lib/`

```
main.dart                  MaterialApp, theme, locale vi
theme/app_theme.dart       màu, theme sáng/tối, TaskColors
data/models/               Task, Subtask, Tag, FocusSession, Habit, HabitLog
data/repositories/         interface repository (xem docs/DATA_CONTRACT.md)
data/fake/                 bản Fake trong bộ nhớ và dữ liệu mẫu
data/sqlite/               AppDatabase (6 bảng, khóa ngoại, index) và 4 repository SQLite
app/dependencies.dart      chỗ duy nhất chọn SQLite hay Fake; main.dart đưa xuống bằng Provider
utils/                     vi_date (ngày giờ tiếng Việt), dates (khoảng ngày) — dùng chung
screens/home_shell.dart    khung 5 tab (tab đang mở do ShellController giữ)
app/settings_controller.dart  cài đặt lưu bằng shared_preferences (key: docs/DATA_CONTRACT.md mục 8)
app/shell_controller.dart  tab đang mở; app/routes.dart tên các màn không phải tab
features/timer/            TimerController.prepare(taskId): chọn sẵn việc rồi mở tab Hẹn giờ
features/today/            màn Hôm nay: today_screen, task_groups (groupTasks, nextTask)
features/today/widgets/    task_tile, progress_card, empty_state
features/tasks/            task_edit_screen, task_detail_screen, recurrence (việc lặp), task_form (kiểm tra form), task_actions
features/settings/         settings_screen, tag_manager_screen, tag_validation (kiểm tra tên nhãn), widgets/
```
