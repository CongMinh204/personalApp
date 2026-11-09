# Việc của tôi (personal_app)

Ứng dụng todo cá nhân viết bằng Flutter, giao diện tiếng Việt, tối giản, bo góc lớn, màu nhấn xanh tím.

Hiện mới có màn **Hôm nay**. Các tab Lịch, Hẹn giờ, Thống kê, Cài đặt đang hiện "Sắp có".

## Tính năng

- Thanh tab dưới cùng 5 mục, giao diện sáng/tối (mặc định theo hệ thống, đổi bằng nút trên header).
- Màn Hôm nay:
  - Lọc theo nhãn: Học tập, Công việc, Cá nhân, Sức khỏe.
  - Thẻ tiến độ trong ngày, thẻ "Xong hết việc hôm nay!" và màn trống.
  - Ba nhóm việc: Quá hạn, Hôm nay, Sắp tới.
  - Bấm checkbox để hoàn thành, vuốt trái để xóa (có "Hoàn tác").
  - Nút "+" mở form thêm nhanh: tên việc, nhãn, ưu tiên, giờ.
- Tầng lưu trữ SQLite (sqflite) đã xong và có test; Android, iOS, macOS dùng SQLite, web và Windows dùng bản Fake trong bộ nhớ (`lib/app/dependencies.dart`). Các màn chưa nối vào repository nên màn Hôm nay vẫn hiện dữ liệu mẫu ở `lib/data/fake/sample_data.dart`.
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
screens/home_shell.dart    khung 5 tab
features/today/            màn Hôm nay: today_screen, task_groups (groupTasks, nextTask)
features/today/widgets/    task_tile, progress_card, empty_state, quick_add_sheet
```
