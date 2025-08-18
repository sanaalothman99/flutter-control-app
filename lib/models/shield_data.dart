class ShieldData {
  // ملاحظة: unitNumber = null للشيلد الرئيسي
  final int? unitNumber;

  // قراءات المستشعرات الأساسية
  final int pressure1;  // Pusher pressure
  final int pressure2;  // Shield pressure
  final int ramStroke;  // Pusher ram

  // حقول إضافية للشيلد الرئيسي (إذا موجودة في الإطار)
  final int? sensor4;
  final int? sensor5;
  final int? sensor6;

  // إعدادات الشيلد الرئيسي
  final int? faceOrientation;   // 0 = left (عادي), 1 = right (معكوس)
  final int? maxDownSelection;  // أقصى مسافة اختيار باتجاه Down
  final int? maxUpSelection;    // أقصى مسافة اختيار باتجاه Up
  final int? moveRange;         // أقصى حجم مجموعة (Dynamic بدل 15)

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

  // طول الإطارات حسب المواصفة
  static const int mainLength = 19;        // الشيلد الرئيسي
  static const int additionalLength = 8;   // كل شيلد إضافي

  // Helpers
  static int _le16(List<int> d, int i) => (i + 1 < d.length) ? (d[i] | (d[i + 1] << 8)) : 0;

  bool get isIgnored => pressure1 == 254 || pressure2 == 254 || ramStroke == 254;
  bool get isError   => pressure1 == 255 || pressure2 == 255 || ramStroke == 255;

  // من بايتات → ShieldData
  static ShieldData fromBytes(List<int> data, int offset) {
    if (offset == 0) {
      if (data.length < mainLength) {
        throw StateError("Main shield frame too short: ${data.length}");
      }
      return ShieldData(
        pressure1: _le16(data, 0),
        pressure2: _le16(data, 2),
        ramStroke: _le16(data, 4),
        sensor4: _le16(data, 6),
        sensor5: _le16(data, 8),
        sensor6: _le16(data,10),
        faceOrientation: data[13],
        maxDownSelection: _le16(data,14),
        maxUpSelection:   _le16(data,16),
        moveRange:        data[18],
      );
    } else {
      if (offset + additionalLength > data.length) {
        throw StateError("Additional shield frame too short at $offset");
      }
      return ShieldData(
        unitNumber: _le16(data, offset + 0),
        pressure1:  _le16(data, offset + 2),
        pressure2:  _le16(data, offset + 4),
        ramStroke:  _le16(data, offset + 6),
      );
    }
  }}