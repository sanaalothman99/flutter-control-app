import 'package:flutter/material.dart';
import '../cotrollers/shield_controller.dart';
import 'data_card.dart';

class ControllerInfoWithPad extends StatelessWidget {
  final ShieldController controller;

  const ControllerInfoWithPad({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: DataCard(controller: controller),
            ),
          ),
        ],
      ),
    );
  }}