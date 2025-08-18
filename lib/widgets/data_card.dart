import 'package:flutter/material.dart';
import '../cotrollers/shield_controller.dart';

class DataCard extends StatelessWidget {
  final ShieldController controller;

  const DataCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final int current = controller.currentShield;

    // ✅ اسم الشيلد الرئيسي حسب موقعه في القائمة
    final String name = "DRD_EC${current.toString().padLeft(3, '0')}";

    // ✅ شيلدين مجاورين فقط بالأرقام
    final int nextShield1 = current + 1;
    final int nextShield2 = current + 2;

    final String addAd = [
      if (nextShield1 < controller.shields.length)
        "#${nextShield1.toString().padLeft(3, '0')}",
      if (nextShield2 < controller.shields.length)
        "#${nextShield2.toString().padLeft(3, '0')}",
    ].join(", ");

    final int pressureLeft = current < controller.shields.length
        ? controller.shields[current].pressure1
        : 0;

    final int pressureRight = current < controller.shields.length
        ? controller.shields[current].pressure2
        : 0;

    final int totalShields = controller.shields.length;
    final int lengthMm = totalShields * 90;

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            dataText(name, screenWidth),
            const Divider(height: 20, thickness: 1.2),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      dataRow(Icons.add_box_outlined, "addAd", addAd, screenWidth),
                      SizedBox(height: screenWidth * 0.03),
                      dataRow(Icons.straighten, "Length", "$lengthMm mm", screenWidth),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      dataRow(Icons.speed, "Pressure 1", "$pressureLeft Bar", screenWidth),
                      SizedBox(height: screenWidth * 0.03),
                      dataRow(Icons.speed, "Pressure 2", "$pressureRight Bar", screenWidth),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget dataRow(IconData icon, String label, String value, double screenWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: screenWidth * 0.045, color: Colors.grey[800]),
        SizedBox(width: screenWidth * 0.02),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: screenWidth * 0.028,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: screenWidth * 0.028,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget dataText(String label, double screenWidth) {
    return Text(
      label,
      style: TextStyle(
        fontSize: screenWidth * 0.052,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }}