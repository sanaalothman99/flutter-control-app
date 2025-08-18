import 'package:flutter/material.dart';

class ArrowImageButton extends StatelessWidget {
  final String imagePath;
  final VoidCallback onTap;

  const ArrowImageButton({
    super.key,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1, // مربع
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade700, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ArrowButtonPanel extends StatelessWidget {
  final VoidCallback onGroupLeft;
  final VoidCallback onGroupRight;
  final VoidCallback onSelectLeft;
  final VoidCallback onSelectRight;
  final VoidCallback onRemoveLeft;
  final VoidCallback onRemoveRight;

  const ArrowButtonPanel({
    super.key,
    required this.onGroupLeft,
    required this.onGroupRight,
    required this.onSelectLeft,
    required this.onSelectRight,
    required this.onRemoveLeft,
    required this.onRemoveRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            ArrowImageButton(
              imagePath: 'assets/arrow_icon/left_plus.jpg',
              onTap: onGroupLeft,
            ),
            const SizedBox(width: 12),
            ArrowImageButton(
              imagePath: 'assets/arrow_icon/right_plus.jpg',
              onTap: onGroupRight,
            ),
          ]),
          Row(children: [
            ArrowImageButton(
              imagePath: 'assets/arrow_icon/left.jpg',
              onTap: onSelectLeft,
            ),
            const SizedBox(width: 12),
            ArrowImageButton(
              imagePath: 'assets/arrow_icon/right.jpg',
              onTap: onSelectRight,
            ),
          ]),
          Row(children: [
            ArrowImageButton(
              imagePath: 'assets/arrow_icon/left_mius.jpg',
              onTap: onRemoveLeft,
            ),
            const SizedBox(width: 12),
            ArrowImageButton(
              imagePath: 'assets/arrow_icon/right_mius.jpg',
              onTap: onRemoveRight,
            ),
          ]),
        ],
      ),
    );
  }}