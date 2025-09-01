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
  final int? moveRange; // أقصى حجم مجموعة (Dynamic بدل 15)

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
    );}

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

  bool get isError => pressure1 == 255 || pressure2 == 255 || ramStroke == 255;

// من بايتات → ShieldData
  static ShieldData fromBytes(List<int> data, int offset) {
    if (offset == 0) {
      if (data.length < mainLength) {
        throw StateError("Main shield frame too short: ${data.length}");
      }

      // 🟢 Debug print للـ maxUp / maxDown (الشيلد الرئيسي)
     /* print("maxUp raw=${data[16].toRadixString(16)} ${data[17].toRadixString(16)} "
          "BE=${_be16(data,16)} LE=${_le16(data,16)}");
      print("maxDn raw=${data[14].toRadixString(16)} ${data[15].toRadixString(16)} "
          "BE=${_be16(data,14)} LE=${_le16(data,14)}");*/

      return ShieldData(
        // pressure1: _be16(data, 0),   // ← استعملي هاد إذا طلعت Big Endian
        pressure1: _le16(data, 0),       // ← حالياً Little Endian

        // pressure2: _be16(data, 2),
        pressure2: _le16(data, 2),

        // ramStroke: _be16(data, 4),
        ramStroke: _le16(data, 4),

        // sensor4: _be16(data, 6),
        sensor4: _le16(data, 6),

        // sensor5: _be16(data, 8),
        sensor5: _le16(data, 8),

        // sensor6: _be16(data,10),
        sensor6: _le16(data,10),

        faceOrientation: data[13],

        // maxDownSelection: _be16(data, 14),
        maxDownSelection: _le16(data, 14),

        // maxUpSelection: _be16(data, 16),
        maxUpSelection: _le16(data, 16),

        moveRange: data[18],
      );
    } else {
      if (offset + additionalLength > data.length) {
        throw StateError("Additional shield frame too short at $offset");
      }

      // 🟢 Debug print للـ unitNumber (الشيلد الإضافي)
      print("unit raw=${data[offset].toRadixString(16)} ${data[offset+1].toRadixString(16)} "
          "BE=${_be16(data,offset)} LE=${_le16(data,offset)}");

      return ShieldData(
        // unitNumber: _be16(data, offset + 0),
        unitNumber: _le16(data, offset + 0),

        // pressure1: _be16(data, offset + 2),
        pressure1: _le16(data, offset + 2),

        // pressure2: _be16(data, offset + 4),
        pressure2: _le16(data, offset + 4),

        // ramStroke: _be16(data, offset + 6),
        ramStroke: _le16(data, offset + 6),
      );
    }}
}