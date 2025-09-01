import 'package:flutter/material.dart';
import '../cotrollers/shield_controller.dart';
import '../models/shield_data.dart';

class DataCard extends StatelessWidget {
  final ShieldController controller;

  const DataCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // اسم العرض: أولويته لاسم الجهاز المتصل
    final String title = controller.connectionShieldName ??
        'DRD_EC${controller.currentShield.toString().padLeft(3, '0')}';

    // الشيلد الرئيسي (الإطار 0 من MCU)
    final ShieldData? main =
    controller.shields.isNotEmpty ? controller.shields[0] : null;

    // addAd: جرّب عرض الشيلدين بعد current إن وُجدا
    final int cur = controller.currentShield;
    final String addAd = [
      if (cur + 1 < controller.shields.length)
        '#${(cur + 1).toString().padLeft(3, '0')}',
      if (cur + 2 < controller.shields.length)
        '#${(cur + 2).toString().padLeft(3, '0')}',
    ].join(', ');

    // الضغطين والطول من الشيلد الرئيسي (أقرب للي عم يوصلك)
    final int p1 = main?.pressure1 ?? 0;
    final int p2 = main?.pressure2 ?? 0;

    // “Length” حسب صورك كان يعرض قيمة الرام (من الرئيسي)
    final int lengthMm = main?.ramStroke ?? 0;

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _title(title, screenWidth),
            const Divider(height: 20, thickness: 1.2),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _row(Icons.add_box_outlined, 'addAd', addAd, screenWidth),
                      SizedBox(height: screenWidth * 0.03),
                      _row(Icons.straighten, 'Length', '$lengthMm mm', screenWidth),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _row(Icons.speed, 'Pressure 1', '$p1 Bar', screenWidth),
                      SizedBox(height: screenWidth * 0.03),
                      _row(Icons.speed, 'Pressure 2', '$p2 Bar', screenWidth),
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

  Widget _row(IconData icon, String label, String value, double w) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: w * 0.045, color: Colors.grey[800]),
        SizedBox(width: w * 0.02),
        Text(
          '$label: ',
          style: TextStyle(fontSize: w * 0.028, fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: TextStyle(fontSize: w * 0.028, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _title(String label, double w) {
    return Text(
      label,
      style: TextStyle(
        fontSize: w * 0.052,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }}