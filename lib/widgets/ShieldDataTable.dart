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

  @override
  Widget build(BuildContext context) {
    // ✅ إصلاح إزالة التكرار + التحقق من الحدود (>=0 و < length)
    final List<int> shieldsToDisplay = <int>{
      currentShield,
      if (highlightedShield != null) highlightedShield!,
      ...selectedShields,
    }
        .where((i) => i >= 0 && i < shields.length)
        .toList()
      ..sort();

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
            // ✅ عناوين مطابقة للمواصفة
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
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      // ✅ نستخدم unitNumber إن وُجد، وإلا نfallback على الفهرس
                      '#${(shields[i].unitNumber ?? i).toString().padLeft(3, '0')}',
                      style: TextStyle(
                        fontWeight: i == currentShield ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('${shields[i].ramStroke} mm'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('${shields[i].pressure1} bar'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('${shields[i].pressure2} bar'),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }}