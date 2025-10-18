import 'package:flutter/material.dart';
import '../cotrollers/shield_controller.dart';
import '../models/shield_data.dart';

class DataCard extends StatelessWidget {
  final ShieldController controller;

  const DataCard({super.key, required this.controller});

  // ✅ دالة لتنسيق القيم (65535 = Error, 65534 = Ignored)
  String _formatValue(int? value, String unit) {
    if (value == null) return '———';
    if (value == 65535) return '———'; // Error
    if (value == 65534) return 'IGN'; // Ignored
    return '$value $unit';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final String title = controller.connectionShieldName ??
        'DRD_EC${controller.currentShield.toString().padLeft(3, '0')}';

    final ShieldData? main =
    controller.shields.isNotEmpty ? controller.shields[0] : null;

    final int? p1 = main?.pressure1;
    final int? p2 = main?.pressure2;
    final int? lengthMm = main?.ramStroke;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.035,
        horizontal: screenWidth * 0.05,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Divider(height: 18, thickness: 1),
          _infoRow(Icons.straighten, 'Length', _formatValue(lengthMm, 'mm'), screenWidth),
          SizedBox(height: screenWidth * 0.02),
          _infoRow(Icons.speed, 'Pressure 1', _formatValue(p1, 'Bar'), screenWidth),
          SizedBox(height: screenWidth * 0.02),
          _infoRow(Icons.speed, 'Pressure 2', _formatValue(p2, 'Bar'), screenWidth),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, double w) {
    final bool isSpecial = value == '———' || value == 'IGN';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: w * 0.04, color: Colors.grey[700]),
        SizedBox(width: w * 0.02),
        Flexible(
          child: Text(
            '$label: $value',
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: w * 0.032,
              fontWeight: FontWeight.w500,
              color: isSpecial ? Colors.grey : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}