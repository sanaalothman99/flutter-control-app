import 'package:flutter/widgets.dart';

class UIScale {
  final double pageH;
  final double gapBelowPage;   // مسافة بين الـPageView والمؤشّر
  final double gridTop;        // مسافة فوق شبكة الأزرار
  final double indicatorPad;   // Padding سفلي للمؤشّر

  UIScale._(this.pageH, this.gapBelowPage, this.gridTop, this.indicatorPad);

  factory UIScale.of(BuildContext context) {
    final s = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;
    final shortest = s.shortestSide;

    // ثلاث درجات حسب حجم الجهاز
    if (shortest < 360) {
      // شاشات صغيرة
      return UIScale._(
        (s.height * 0.24).clamp(180.0, 230.0),
        8, 12, 10 + (bottom * 0.40),
      );
    } else if (shortest < 420) {
      // متوسطة (الأشيَع)
      return UIScale._(
        (s.height * 0.26).clamp(200.0, 260.0),
        12, 16, 12 + (bottom * 0.45),
      );
    } else {
      // كبيرة (شاومي كبير/توب)
      return UIScale._(
        (s.height * 0.28).clamp(220.0, 280.0),
        14, 20, 14 + (bottom * 0.50),
      );
    }
  }
}