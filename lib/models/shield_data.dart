class ShieldData {
  // ملاحظة: unitNumber = null للشيلد الرئيسي
  final int? unitNumber;

  // قراءات المستشعرات الأساسية
  final int pressure1; // Pusher pressure
  final int pressure2; // Shield pressure
  final int ramStroke; // Pusher ram

  // حقول إضافية للشيلد الرئيسي (إذا موجودة في الإطار)
  final int? sensor4;
  final int? sensor5;
  final int? sensor6;

  // إعدادات الشيلد الرئيسي
  final int? faceOrientation; // 0 = left (عادي), 1 = right (معكوس)
  final int? maxDownSelection; // أقصى مسافة اختيار باتجاه Down
  final int? maxUpSelection; // أقصى مسافة اختيار باتجاه Up
  final int? moveRange; // أقصى حجم مجموعة

  const ShieldData({
    this.unitNumber,
    required this.pressure1,
    required this.pressure2,
    required this.ramStroke,
    this.sensor4,
    this.sensor5,
    this.sensor6,
    this.faceOrientation,
    this.maxDownSelection,
    this.maxUpSelection,
    this.moveRange,
  });

  factory ShieldData.empty({required int unitNumber}) {
    return ShieldData(
      unitNumber: unitNumber,
      pressure1: 0,
      pressure2: 0,
      ramStroke: 0,
      sensor4: 0,
      sensor5: 0,
      sensor6: 0,
      faceOrientation: 0,
      maxDownSelection: 0,
      maxUpSelection: 0,
      moveRange: 0,
    );
  }

  // طول الإطارات حسب المواصفة
  static const int mainLength = 19; // الشيلد الرئيسي
  static const int additionalLength = 8; // كل شيلد إضافي

  // Helpers
  static int _le16(List<int> d, int i) =>
      (i + 1 < d.length) ? ((d[i] & 0xff) | ((d[i + 1] & 0xff) << 8)) : 0;

  static int _be16(List<int> d, int i) =>
      (i + 1 < d.length) ? (((d[i] & 0xff) << 8) | (d[i + 1] & 0xff)) : 0;

  bool get isIgnored =>
      pressure1 == 254 || pressure2 == 254 || ramStroke == 254;

  bool get isError =>
      pressure1 == 255 || pressure2 == 255 || ramStroke == 255;

  // من بايتات → ShieldData
  static ShieldData fromBytes(List<int> data, int offset) {
    if (offset == 0) {
      if (data.length < mainLength) {
        throw StateError("Main shield frame too short: ${data.length}");
      }

      final p1 = _le16(data, 0);
      final p2 = _le16(data, 2);
      final ram = _le16(data, 4);

      final s4 = _le16(data, 6);
      final s5 = _le16(data, 8);
      final s6 = _le16(data, 10);

      final face = data[13];

      final maxDn = _be16(data, 14);
      final maxUp = _be16(data, 16);

      final move = data[18];

      // 🟢 Debug
     // print(
          //"🧩 MainShield: p1=$p1 p2=$p2 ram=$ram face=$face maxDn=$maxDn maxUp=$maxUp move=$move");

      return ShieldData(
        pressure1: p1,
        pressure2: p2,
        ramStroke: ram,
        sensor4: s4,
        sensor5: s5,
        sensor6: s6,
        faceOrientation: face,
        maxDownSelection: maxDn,
        maxUpSelection: maxUp,
        moveRange: move,
      );
    } else {
      if (offset + additionalLength > data.length) {
        throw StateError("Additional shield frame too short at $offset");
      }

      final unit = _le16(data, offset + 0);
      final p1 = _le16(data, offset + 2);
      final p2 = _le16(data, offset + 4);
      final ram = _le16(data, offset + 6);

      // 🟢 Debug
     // print("🧩 ExtraShield unit=$unit p1=$p1 p2=$p2 ram=$ram");

      return ShieldData(
        unitNumber: unit,
        pressure1: p1,
        pressure2: p2,
        ramStroke: ram,
      );
    }
  }
  ShieldData copyWith({
    int? unitNumber,
    int? pressure1,
    int? pressure2,
    int? ramStroke,
    int? sensor4,
    int? sensor5,
    int? sensor6,
    int? faceOrientation,
    int? maxDownSelection,
    int? maxUpSelection,
    int? moveRange,
  }) {
    return ShieldData(
      unitNumber: unitNumber ?? this.unitNumber,
      pressure1: pressure1 ?? this.pressure1,
      pressure2: pressure2 ?? this.pressure2,
      ramStroke: ramStroke ?? this.ramStroke,
      sensor4: sensor4 ?? this.sensor4,
      sensor5: sensor5 ?? this.sensor5,
      sensor6: sensor6 ?? this.sensor6,
      faceOrientation: faceOrientation ?? this.faceOrientation,
      maxDownSelection: maxDownSelection ?? this.maxDownSelection,
      maxUpSelection: maxUpSelection ?? this.maxUpSelection,
      moveRange: moveRange ?? this.moveRange,
    );
}
}