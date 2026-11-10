# Việc của tôi (personal_app)

Ứng dụng todo cá nhân viết bằng Flutter, giao diện tiếng Việt, tối giản, bo góc lớn, màu nhấn xanh tím.

Hiện có các màn **Hôm nay**, **Lịch**, **Thêm/sửa việc**, **Chi tiết việc**, **Tìm kiếm**, **Hẹn giờ**, **Lịch sử tập trung**, **Thói quen** (danh sách, Chi tiết, Thêm/sửa, Đã lưu trữ), **Cài đặt** và **Quản lý nhãn**. Tab Thống kê đang hiện "Sắp có".

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
- Lịch (tab thứ 2): xem Tháng hoặc Tuần, nút ◀ ▶ (sang tháng/tuần khác) và "Hôm nay"; ngày có việc có chấm, ngày đầu tuần theo Cài đặt. Chạm một ngày để xem việc của ngày đó: việc cả ngày ("Không có giờ"), dải giờ của việc có giờ (màu theo nhãn, vạch đỏ là giờ hiện tại), rồi danh sách việc của ngày (bấm checkbox để hoàn thành, bấm việc mở Chi tiết, nút đồng hồ mở Hẹn giờ). Ngày trống có nút "Thêm việc vào ngày này" (form Thêm việc điền sẵn ngày đó).
- Thêm/sửa việc: tiêu đề, ghi chú, ngày (hoặc không có ngày), cả ngày hoặc giờ bắt đầu–kết thúc, nhắc trước, lặp lại, ưu tiên, một nhãn (có thể tạo nhãn mới ngay trong form), việc con.
- Chi tiết việc: thông tin, việc con, thời gian đã tập trung, nút Bắt đầu / Sửa / Xóa.
- Tìm kiếm (biểu tượng ở header Hôm nay): tìm theo tiêu đề, ghi chú và tên nhãn (không phân biệt hoa thường và dấu tiếng Việt: gõ "hoc tap" vẫn ra "Học tập"), lọc Chưa xong / Đã xong / theo nhãn, "Tìm gần đây" (tối đa 5 từ khóa).
- Hẹn giờ: đếm ngược Pomodoro (Pomodoro, Nghỉ ngắn, Nghỉ dài, Tùy chỉnh 1–180 phút; chu kỳ 4 phiên rồi nghỉ dài) và bấm giờ có vòng (nhanh nhất / chậm nhất). Chọn việc để tập trung; phiên hết giờ hoặc bỏ dở được lưu và cộng vào "Đã tập trung" ở Chi tiết việc. Đồng hồ chạy tiếp khi đổi tab. Hết giờ thì rung, phát âm hệ thống và hiện hộp báo (thông báo khi app ở nền làm sau).
- Lịch sử tập trung (nút ở header Hẹn giờ): các phiên tập trung (Pomodoro, Tùy chỉnh; giờ nghỉ không hiện) gom theo Ngày / Tuần / Tháng, mỗi nhóm kèm tổng thời gian. Ba ô tóm tắt (Phiên, Hoàn thành x/y, và tổng thời gian tập trung của Tuần này / Tháng này / Năm nay) đổi theo tab. Mỗi dòng có tên việc, khoảng giờ, loại, thời lượng và huy hiệu Hoàn thành / Bỏ dở. Vuốt trái để xóa một phiên (có Hoàn tác).
- Thói quen (tab thứ 5): thẻ "Thói quen hôm nay x/y", mỗi thói quen có biểu tượng màu, chuỗi ngày, tiến độ trong ngày ("5/8 ly", "Đã xong") và nút chấm (mục tiêu 1 lần: bấm là xong; nhiều lần: mỗi lần cộng 1). Thói quen không có lịch hôm nay mờ đi ở cuối danh sách. Thêm/sửa: tên, biểu tượng, màu, lặp lại (mỗi ngày hoặc theo thứ), mục tiêu mỗi ngày (kèm đơn vị khi nhiều lần), nhắc mỗi ngày, ngày bắt đầu, Lưu trữ và Xóa. Đã lưu trữ: khôi phục hoặc xóa hẳn.
- Chi tiết thói quen (chạm vào một thói quen): chuỗi hiện tại, chuỗi dài nhất, tỷ lệ hoàn thành, lịch tháng (đã làm, bỏ lỡ, hôm nay, chưa tới, ngày nghỉ; chuyển tháng từ tháng bắt đầu tới tháng này), biểu đồ 4 tuần gần nhất. Chạm một ngày đã qua trên lịch để bổ sung hoặc bỏ đánh dấu; nút ở cuối đánh dấu hôm nay xong cả mục tiêu.
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
utils/                     vi_date (ngày giờ tiếng Việt, tên thứ, "Tháng 10, 2026"), dates (khoảng ngày) — dùng chung
screens/home_shell.dart    khung 5 tab (tab đang mở do ShellController giữ)
app/settings_controller.dart  cài đặt lưu bằng shared_preferences (key: docs/DATA_CONTRACT.md mục 8)
app/shell_controller.dart  tab đang mở; app/routes.dart tên các màn không phải tab
features/calendar/         calendar_screen, calendar_logic (lưới tháng/tuần, ◀ ▶, dải giờ, việc của ngày)
features/habits/           habits_screen, habit_detail_screen, habit_edit_screen, habit_archived_screen, habit_logic, habit_detail_logic (lịch tháng, tuần, tỷ lệ)
features/focus_history/    focus_history_screen, focus_history_logic (gom nhóm, tóm tắt, định dạng)
features/timer/            timer_screen, countdown_controller (đếm ngược, chu kỳ, lưu phiên), stopwatch_controller, TimerController.prepare(taskId)
features/today/            màn Hôm nay: today_screen, task_groups (groupTasks, nextTask)
features/today/widgets/    task_tile, progress_card, empty_state
features/search/           search_screen, recent_searches (tìm gần đây), search_filter
features/tasks/            task_edit_screen, task_detail_screen, recurrence (việc lặp), task_form (kiểm tra form), task_actions
features/settings/         settings_screen, tag_manager_screen, tag_validation (kiểm tra tên nhãn), widgets/
```
