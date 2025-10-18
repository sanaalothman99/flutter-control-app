import 'package:flutter/material.dart';
import '../models/shield_data.dart';

class ShieldInfoTable extends StatelessWidget {
  final int currentShield;
  final int? highlightedShield;
  final List<int> selectedShields;
  final List<ShieldData> shields;

  const ShieldInfoTable({
    super.key,
    required this.currentShield,
    required this.highlightedShield,
    required this.selectedShields,
    required this.shields,
  });

  // يكتب رقم الشيلد كما هو مطلوب في الجدول
  String _unitLabel(int unit) {
    return '#${unit.toString().padLeft(3, '0')}';
  }

  // ✅ دالة لتنسيق القيم (65535 = Error, 65534 = Ignored)
  String _formatValue(int? value, String unit) {
    if (value == null) return '———';
    if (value == 65535) return '———'; // Error
    if (value == 65534) return 'IGN'; // Ignored
    return '$value $unit';
  }

  // ابحثي عن صف بالداتا عبر unitNumber (بدل استخدام الفهرس)
  ShieldData? _findByUnitNumber(int unit) {
    for (final sd in shields) {
      if (sd.unitNumber == unit) return sd;
    }
    return null;
  }

  // خلية نصية جاهزة
  Widget _cell(String text) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(text),
  );

  @override
  Widget build(BuildContext context) {
    // اختاري ما سيُعرض:
    final List<int> shieldsToDisplay;
    if (selectedShields.isNotEmpty) {
      shieldsToDisplay = {...selectedShields.where((u) => u >= 0)}.toList()
        ..sort();
    } else if (highlightedShield != null) {
      shieldsToDisplay = [highlightedShield!];
    } else {
      shieldsToDisplay = [currentShield];
    }

    // جلب بيانات الصف للـ unit الصحيح:
    ShieldData? dataForRow(int unit) {
      if (unit == currentShield) {
        // الشيلد الحالي → من الإطار الرئيسي (index 0) إن وُجد
        return shields.isNotEmpty ? shields[0] : null;
      }
      // باقي الوحدات → ابحثي بالـ list وفق unitNumber
      return _findByUnitNumber(unit);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: Colors.black54, width: 1),
          columnWidths: const {
            0: FlexColumnWidth(1.5),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Shield',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Pusher Ram',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Pusher Pressure',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Shield Pressure',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),

            for (final unit in shieldsToDisplay)
              (() {
                final sd = dataForRow(unit);
                final isCurrent = (unit == currentShield);

                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _unitLabel(unit),
                        style: TextStyle(
                          fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    _cell(sd != null
                        ? _formatValue(sd.ramStroke, "mm")
                        : '———'),
                    _cell(sd != null
                        ? _formatValue(sd.pressure1, "bar")
                        : '———'),
                    _cell(sd != null
                        ? _formatValue(sd.pressure2, "bar")
                        : '———'),
                  ],
                );
              })(),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}