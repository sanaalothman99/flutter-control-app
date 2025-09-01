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


              final bool isCurrent     = shieldIndex == controller.currentShield;
              final bool isHighlighted = controller.groupSize == 0 &&
                  (shieldIndex == controller.currentShield + controller.selectionDistance);
              final bool inGroup       = controller.selectedShields.contains(shieldIndex);

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
                    isSelected:    inGroup,
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
    int minIndex = controller.currentShield - 8;
    final highlighted = controller.currentShield + controller.selectionDistance;
    if (highlighted < minIndex) minIndex = highlighted;
    if (controller.selectedShields.isNotEmpty) {
      final groupMin = controller.selectedShields.reduce((a, b) => a < b ? a : b);
      if (groupMin < minIndex) minIndex = groupMin;
    }
    return minIndex < 0 ? 0 : minIndex;
  }

  int _calculateEnd() {
    int maxIndex = controller.currentShield + 6;
    final highlighted = controller.currentShield + controller.selectionDistance;
    if (highlighted > maxIndex) maxIndex = highlighted;
    if (controller.selectedShields.isNotEmpty) {
      final groupMax = controller.selectedShields.reduce((a, b) => a > b ? a : b);
      if (groupMax > maxIndex) maxIndex = groupMax;
    }
    return maxIndex;
  }



  Widget _numbersRow() {
    // مجموعة: نعرض المدى بأرقام الوحدات الحقيقية
    if (controller.groupSize > 0) {
      // حوّل كل indices إلى unitNumbers ثم خذ min/max
      final units = controller.selectedShields.map(_unitOfIndex).toList();
      if (units.isEmpty) {
        return const SizedBox.shrink();
      }
      units.sort();
      final text = controller.isReversed
          ? '${units.last} - ${units.first}'
          : '${units.first} - ${units.last}';
      return Text(
        text,
        style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.w600),
      );
    }

    // تحديد فردي: استخدم رقم الوحدة الحقيقي
    if (controller.selectionDistance != 0) {
      final hiIdx = controller.highlightedUnit;
      final hiUnit = _unitOfIndex(hiIdx);
      return Text(
        '$hiUnit',
        style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.w600),
      );
    }

    // بدون تحديد: الشيلد الحالي برقم وحدته الحقيقي
    final curUnit = _unitOfIndex(controller.currentShield);
    return Text(
      '$curUnit',
      style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.w600),
    );}}