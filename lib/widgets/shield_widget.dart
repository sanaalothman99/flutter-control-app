import 'package:flutter/material.dart';

class ShieldWidget extends StatelessWidget {
  final double width;
  final double height;

  final double pressureLeft;
  final double pressureRight;
  final double ramValue;
  final int faceOrientation;

  final bool isCurrent;
  final bool isHighlighted;
  final bool isSelected;
  final int groupSize;

  const ShieldWidget({
    super.key,
    required this.width,
    required this.height,
    required this.pressureLeft,
    required this.pressureRight,
    required this.ramValue,
    required this.faceOrientation,
    required this.isCurrent,
    required this.isHighlighted,
    required this.isSelected,
    required this.groupSize,
  });
  Color _colorFor(double value, Color normal) {
    final int intValue = value.toInt();

    // 0xFFFF (65535) = Error → red
    if (intValue == 65535) return Colors.red;

    // 0xFFFE (65534) = Ignored → brown
    if (intValue == 65534) return Colors.brown;

    return normal;
  }

  double _factor(double value) {
    if (value.toInt() == 255 || value.toInt() == 254) return 1.0;
    return value.clamp(0, 100) / 100.0;
  }

  BorderSide get _border {
    if (isCurrent) {
      if (isSelected) {
        return const BorderSide(color: Colors.blue, width: 3.0);
      }// else {
       // return const BorderSide(color: Colors.blue, width: 2.5);
     // }
    }
    if (isHighlighted) return const BorderSide(color: Colors.blue, width: 3.0);
    if (isSelected) return const BorderSide(color: Colors.blue, width: 2.0);
    return BorderSide.none;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isCurrent)
          const Text('▼', style: TextStyle(fontSize: 16, height: 0.7, color: Colors.black)),
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
            border: Border.fromBorderSide(_border),
          ),
          child: Column(
            children: [
              // ── Pressure row (with face orientation)
              Expanded(
                flex: 1,
                child: Row(
                  children: faceOrientation == 1
                      ? _buildReversedPressureBars()
                      : _buildNormalPressureBars(),
                ),
              ),

              // ── Spacer
              Container(
                height: 4,
                width: double.infinity,
                color: Colors.grey.shade500,
              ),

              // ── RAM row
              Expanded(
                flex: 1,
                child: Container(
                  alignment: Alignment.bottomCenter,
                  color: Colors.grey.shade100,
                  child: FractionallySizedBox(
                    heightFactor: _factor(ramValue),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      color: _colorFor(ramValue, Colors.green),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isCurrent)
          const Text('▲', style: TextStyle(fontSize: 16, height: 0.7, color: Colors.black)),
      ],
    );
  }

  List<Widget> _buildNormalPressureBars() {
    return [
      _buildPressureBar(pressureLeft, Colors.green, true),
      _buildPressureBar(pressureRight, Colors.green.shade700, false),
    ];
  }

  List<Widget> _buildReversedPressureBars() {
    return [
      _buildPressureBar(pressureRight, Colors.green.shade700, true),
      _buildPressureBar(pressureLeft, Colors.green, false),
    ];
  }

  Widget _buildPressureBar(double value, Color color, bool withRightBorder) {
    return Expanded(
      child: Container(
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border(
            right: withRightBorder
                ? const BorderSide(color: Colors.black12, width: 0.5)
                : BorderSide.none,
          ),
        ),
        child: FractionallySizedBox(
          heightFactor: _factor(value),
          alignment: Alignment.bottomCenter,
          child: Container(color: _colorFor(value, color)),
        ),
      ),
    );
  }}