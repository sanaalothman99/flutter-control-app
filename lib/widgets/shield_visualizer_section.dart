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

  @override
  Widget build(BuildContext context) {
    const double shieldHeight = 90;
    const double spacing = 3;

    // احسبي النطاق الخام
    int rawStart = _calculateStart();
    int rawEnd   = _calculateEnd();

    // طبّقي حدود المسموح (maxUp/maxDown مع faceOrientation)
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

              // فقط ضمن الحدود نسمح بالتوليد/العرض
              if (shieldIndex >= 0 &&
                  shieldIndex >= controller.shields.length) {
                controller.generateShield(shieldIndex);
              }

              final ShieldData? data = (shieldIndex >= 0 &&
                  shieldIndex < controller.shields.length)
                  ? controller.shields[shieldIndex]
                  : null;

              final bool hasData = data != null &&
                  ((data.pressure1 != 0) ||
                      (data.pressure2 != 0) ||
                      (data.ramStroke != 0));

              final bool isCurrent     = shieldIndex == controller.currentShield;
              final bool isHighlighted = controller.groupSize == 0 &&
                  (shieldIndex ==
                      controller.currentShield + controller.selectionDistance);
              final bool inGroup = controller.selectedShields.contains(shieldIndex);

              if (!hasData) {
                // Placeholder فضي
                return Expanded(
                  child: Container(
                    height: shieldHeight,
                    margin: EdgeInsets.only(
                      right: i < visibleCount - 1 ? 3 : 0,
                    ),
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
                  padding: EdgeInsets.only(
                    right: i < visibleCount - 1 ? spacing : 0,
                  ),
                  child: ShieldWidget(
                    width: double.infinity,
                    height: shieldHeight,
                    pressureLeft:  data.pressure1.toDouble(),
                    pressureRight: data.pressure2.toDouble(),
                    ramValue:      data.ramStroke.toDouble(),
                    isCurrent:     isCurrent,     // الرئيسي حدوده أزرق دائمًا
                    isHighlighted: isHighlighted, // تحديد فردي
                    isSelected:    inGroup,       // كل عناصر المجموعة حدودها أزرق
                    groupSize:     controller.groupSize,
                    faceOrientation: data.faceOrientation ?? 0,
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
    // مجموعة: نعرض "بداية - نهاية" باللون الأزرق، مع عكس الترتيب إذا الوجهة معكوسة
    if (controller.groupSize > 0) {
      final r = controller.groupRange; // (min, max) بوحدات unitNumber
      final bool reversed = controller.isReversed;
      final text = reversed ? '${r.max} - ${r.min}' : '${r.min} - ${r.max}';
      return Text(
        text,
        style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.w600),
      );
    }

    // تحديد فردي: نعرض رقم الشيلد المظلّل بالأزرق
    if (controller.selectionDistance != 0) {
      final hi = controller.highlightedUnit;
      return Text(
        '$hi',
        style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.w600),
      );
    }

    // بدون تحديد: نعرض رقم الشيلد الرئيسي بالأزرق
    return Text(
      '${controller.currentShield}',
      style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.w600),
    );
  }}