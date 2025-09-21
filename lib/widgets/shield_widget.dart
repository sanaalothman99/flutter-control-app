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
  static const int kMaxPressureBar = 600;  // أقصى ضغط لملء العمود
  static const int kMaxRamMm       = 600; // أقصى شوط رام


  Color _colorFor(double value, Color normal) {
    final int v = value.toInt();
    // 16-بت فقط
    if (v == 65535) return Colors.red;     // Error
    if (v == 65534) return Colors.brown;   // Ignored
    return normal;
  }

  double _norm(double value, int max) {
    final int v = value.toInt();
    // لو Error/Ignored خلّي العمود ممتلئ ليوضح بصريًا
    if (v == 65535 || v == 65534) return 1.0;

    if (max <= 0) return 0.0;
    final f = value / max;
    if (f.isNaN || f.isInfinite) return 0.0;
    return f.clamp(0.02, 1.0);
  }

  BorderSide get _border {
    if (isCurrent) {
      if (isSelected) return const BorderSide(color: Colors.blue, width: 3.0);
    }
    if (isHighlighted) return const BorderSide(color: Colors.blue, width: 3.0);
    if (isSelected)    return const BorderSide(color: Colors.blue, width: 2.0);
    return BorderSide.none;
  }

  @override
  Widget build(BuildContext context) {
    final pL = _norm(pressureLeft,  kMaxPressureBar);
    final pR = _norm(pressureRight, kMaxPressureBar);
    final rF = _norm(ramValue,      kMaxRamMm);

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
              Expanded(
                child: Row(
                  children: faceOrientation == 1
                      ? _buildReversedPressureBars(pL, pR)
                      : _buildNormalPressureBars(pL, pR),
                ),
              ),
              Container(height: 4, width: double.infinity, color: Colors.grey.shade500),
              Expanded(
                child: Container(
                  alignment: Alignment.bottomCenter,
                  color: Colors.grey.shade100,
                  child: FractionallySizedBox(
                    heightFactor: rF,
                    alignment: Alignment.bottomCenter,
                    child: Container(color: _colorFor(ramValue, Colors.green)),
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

  List<Widget> _buildNormalPressureBars(double fLeft, double fRight) => [
    _buildPressureBar(fLeft,  _colorFor(pressureLeft,  Colors.green),          true),
    _buildPressureBar(fRight, _colorFor(pressureRight, Colors.green.shade700), false),
  ];

  List<Widget> _buildReversedPressureBars(double fLeft, double fRight) => [
    _buildPressureBar(fRight, _colorFor(pressureRight, Colors.green.shade700), true),
    _buildPressureBar(fLeft,  _colorFor(pressureLeft,  Colors.green),          false),
  ];

  Widget _buildPressureBar(double factor, Color color, bool withRightBorder) {
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
          heightFactor: factor,
          alignment: Alignment.bottomCenter,
          child: Container(color: color),
        ),
      ),
    );
  }}