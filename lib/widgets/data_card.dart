import 'package:flutter/material.dart';
import '../cotrollers/shield_controller.dart';
import '../models/shield_data.dart';

class DataCard extends StatelessWidget {
  final ShieldController controller;

  const DataCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final String title = controller.connectionShieldName ??
        'DRD_EC${controller.currentShield.toString().padLeft(3, '0')}';

    final ShieldData? main =
    controller.shields.isNotEmpty ? controller.shields[0] : null;

    final int p1 = main?.pressure1 ?? 0;
    final int p2 = main?.pressure2 ?? 0;
    final int lengthMm = main?.ramStroke ?? 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: screenWidth * 0.04,
          horizontal: screenWidth * 0.06,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Divider(height: 18, thickness: 1.1),
            _infoRow(Icons.straighten, 'Length', '$lengthMm mm', screenWidth),
            SizedBox(height: screenWidth * 0.02),
            _infoRow(Icons.speed, 'Pressure 1', '$p1 Bar', screenWidth),
            SizedBox(height: screenWidth * 0.02),
            _infoRow(Icons.speed, 'Pressure 2', '$p2 Bar', screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, double w) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: w * 0.045, color: Colors.grey[700]),
        SizedBox(width: w * 0.02),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: w * 0.032,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: w * 0.031,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }}