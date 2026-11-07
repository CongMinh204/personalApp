// Chuyển giá trị giữa model và cột SQLite, dùng trong toMap/fromMap.

int? encodeTime(DateTime? t) => t?.millisecondsSinceEpoch;

DateTime? decodeTime(Object? value) =>
    value == null ? null : DateTime.fromMillisecondsSinceEpoch(value as int);

int encodeBool(bool b) => b ? 1 : 0;

bool decodeBool(Object? value) => value == 1 || value == true;
