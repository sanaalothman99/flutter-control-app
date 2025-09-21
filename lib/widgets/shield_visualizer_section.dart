import 'package:flutter/material.dart';
import '../cotrollers/shield_controller.dart';
import '../models/shield_data.dart';
import 'shield_widget.dart';

class ShieldVisualizerSection extends StatelessWidget {
  final ShieldController controller;

  const ShieldVisualizerSection({
    super.key,
    required this.controller,
  });
  // == helpers داخل ShieldVisualizerSection ==
  int? _deviceUnitFromName() {
    final name = controller.connectionShieldName;
    if (name == null) return null;
    final m = RegExp(r'(\d{3})$').firstMatch(name);
    return m != null ? int.parse(m.group(1)!) : null;
  }

  /// رجّع رقم الوحدة للعرض:
  /// 1) من الداتا (unitNumber) إذا متوفر
  /// 2) إذا كان idx هو الشيلد الحالي ومافي رقم، حاول من اسم الجهاز
  /// 3) وإلا رجّع index كحل أخير
  int _unitOfIndex(int idx) {
    final sd = controller.tryGetUnit(idx);
    final un = sd?.unitNumber;
    if (un != null && un > 0) return un;

    if (idx == controller.currentShield) {
      final guessed = _deviceUnitFromName();
      if (guessed != null) return guessed;
    }
    return idx;}

  @override
  Widget build(BuildContext context) {
    const double shieldHeight = 90;
    const double spacing = 3;

    // احسبي النطاق الخام حول الشيلد الحالي + التحديد/المجموعة
    int rawStart = _calculateStart();
    int rawEnd   = _calculateEnd();

    // طبّقي حدود المسموح (حسب maxUp/maxDown مع انعكاس الوجهة)
    final b = controller.allowedBounds;
    final startShield = rawStart < b.minAllowed ? b.minAllowed : rawStart;
    final endShield   = rawEnd   > b.maxAllowed ? b.maxAllowed : rawEnd;

    if (endShield < startShield) {
      return const SizedBox(height: 120);
    }

    final int visibleCount = endShield - startShield + 1;

    return Column(
      children: [
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.grey.shade500,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            textDirection: controller.isReversed ? TextDirection.rtl : TextDirection.ltr,
            children: List.generate(visibleCount, (i) {
              final shieldIndex = startShield + i;

              // ==== الأسلوب الجديد (المعتمد): جلب آمن من الخريطة بدون توليد إجباري ====
             final ShieldData? data = controller.tryGetUnit(shieldIndex);

              // ==== الأسلوب القديم (احتياطي) — مُعَلَّق: أدناه يعتمد على القائمة وتوليد عناصر ====

             /* if (shieldIndex >= 0 && shieldIndex >= controller.shields.length) {
                controller.generateShield(shieldIndex);
              }
              final ShieldData? data = (shieldIndex >= 0 && shieldIndex < controller.shields.length)
                  ? controller.shields[shieldIndex]
                  : null;*/


              final bool isCurrent = shieldIndex == controller.currentShield;

// ✅ إذا في مجموعة: الأزرق على كل أعضاء المجموعة
              final bool isSelected = controller.groupSize > 0
                  ? (controller.selectedShields.contains(shieldIndex) ||
                  shieldIndex == controller.selectionStart)
                  : false;

// ✅ إذا ما في مجموعة: الأزرق بس على الشيلد الفردي المحدد
              final bool isHighlighted = controller.groupSize > 0
                  ? isSelected: (shieldIndex == controller.highlightedUnit);
// ✅ إذا في مجموعة: كل الأعضاء + نقطة البداية
             /* final bool inGroup = controller.groupSize > 0
                  ? (controller.selectedShields.contains(shieldIndex) ||
                  shieldIndex == controller.selectionStart)
                  : controller.selectedShields.contains(shieldIndex);

// ✅ highlight = نفس inGroup إذا في مجموعة، أو للـ selection الفردي
              final bool isHighlighted = controller.groupSize > 0
                  ? inGroup: (shieldIndex == controller.currentShield +controller.selectionDistance);*/


              final bool hasData = (data != null );/*&&
                  ((data!.pressure1 != 0) || (data.pressure2 != 0) || (data.ramStroke != 0));*/

              if (!hasData) {
                // Placeholder بسيط إن ما وصلتنا داتا لهالشيلد
                return Expanded(
                  child: Container(
                    height: shieldHeight,
                    margin: EdgeInsets.only(right: i < visibleCount - 1 ? spacing : 0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade600),
                    ),
                  ),
                );
              }

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < visibleCount - 1 ? spacing : 0),
                  child: ShieldWidget(
                    width: double.infinity,
                    height: shieldHeight,
                    pressureLeft:  (data.pressure1  ).toDouble(),
                    pressureRight: (data.pressure2  ).toDouble(),
                    ramValue:      (data.ramStroke  ).toDouble(),
                    faceOrientation: data.faceOrientation ?? 0,
                    isCurrent:     isCurrent,
                    isHighlighted: isHighlighted,
                    isSelected:    isSelected,
                    groupSize:     controller.groupSize,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        _numbersRow(),
      ],
    );
  }

  int _calculateStart() {
    // خلي currentShield بالنص (5) إذا ما في مجموعة
    int base = controller.currentShield - 5;

    final highlighted = controller.currentShield + controller.selectionDistance;
    if (highlighted < base) base = highlighted - 5;

    if (controller.selectedShields.isNotEmpty) {
      final groupMin = controller.selectedShields.reduce((a, b) => a < b ? a : b);
      if (groupMin < base) base = groupMin - 1;
    }

    return base < 0 ? 0 : base;
  }

  int _calculateEnd() {
    int base = controller.currentShield + 5;

    final highlighted = controller.currentShield + controller.selectionDistance;
    if (highlighted > base) base = highlighted + 5;

    if (controller.selectedShields.isNotEmpty) {
      final groupMax = controller.selectedShields.reduce((a, b) => a > b ? a : b);
      if (groupMax > base) base = groupMax + 1;
    }

    return base;
  }



  Widget _numbersRow() {
    if (controller.groupSize > 0) {
      final start = controller.selectionStart;
      final step = controller.stepFor(controller.selectionDirection);
      final last  = start + step * controller.groupSize;

      final startUnit = _unitOfIndex(start);
      final endUnit   = _unitOfIndex(last.toInt());

      final text = controller.isReversed
          ? '$endUnit - $startUnit'
          : '$startUnit - $endUnit';

      return Text(
        text,
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // تحديد فردي
    if (controller.selectionDistance != 0) {
      final hiUnit = _unitOfIndex(controller.highlightedUnit);
      return Text(
        '$hiUnit',
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // شيلد رئيسي فقط
    final curUnit = _unitOfIndex(controller.currentShield);
    return Text(
      '$curUnit',
      style: const TextStyle(
        color: Colors.blue,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );}
}