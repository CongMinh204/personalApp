/// Khóa dùng để so sánh tên nhãn: bỏ khoảng trắng hai đầu và không phân biệt
/// hoa thường, kể cả chữ có dấu ("HỌC TẬP" trùng "Học tập").
String tagNameKey(String name) => name.trim().toLowerCase();
