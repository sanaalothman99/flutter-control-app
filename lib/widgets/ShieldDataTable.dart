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
  // يعرض رقم الشيلد من unitNumber إن وُجد وإلا fallback على الفهرس
  String _unitLabel(int i, ShieldData? sd) {
    final unit = sd?.unitNumber ?? i;
    return '#${unit.toString().padLeft(3, '0')}';
  }

// تجيب صف الداتا بأمان (null لو خارج النطاق)
  ShieldData? _dataForRow(int i) {
    return (i >= 0 && i < shields.length) ? shields[i] : null;
  }

// خلية نصية جاهزة
  Widget _cell(String text) => Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text),);

  @override
  Widget build(BuildContext context) {
    // اختاري ما سيُعرض:
    final List<int> shieldsToDisplay;
    if (selectedShields.isNotEmpty) {
      shieldsToDisplay = {
        ...selectedShields.where((i) => i >= 0),
      }.toList()
        ..sort();
    } else if (highlightedShield != null) {
      shieldsToDisplay = [highlightedShield!];
    } else {
      shieldsToDisplay = [currentShield];
    }

    // دالة تجيب البيانات الصحيحة لكل صف:
    ShieldData? dataForRow(int unitIndex) {
      if (unitIndex == currentShield) {
        // الشيلد الحالي يقرأ من الإطار الرئيسي (index 0) إن وُجد
        if (shields.isNotEmpty) return shields[0];
        return null;
      }
      // غير الحالي يقرأ من مكانه إن كان متاحاً
      if (unitIndex >= 0 && unitIndex < shields.length) {
        return shields[unitIndex];
      }
      return null;
    }

    Widget cell(String text) => Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text),
    );

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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Pusher Ram',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Pusher Pressure',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Shield Pressure',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),

            for (final i in shieldsToDisplay)
              (() {
                final sd = dataForRow(i);
                final isCurrent = (i == currentShield);

                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _unitLabel(i, sd),
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    cell(sd != null ? '${sd.ramStroke} mm' : '—'),
                    cell(sd != null ? '${sd.pressure1} bar' : '—'),
                    cell(sd != null ? '${sd.pressure2} bar' : '—'),
                  ],
                );
              })(),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }}