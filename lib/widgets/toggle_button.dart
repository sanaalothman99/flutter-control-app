import 'package:flutter/material.dart';

class ToggleButton extends StatefulWidget {
  final String label;
  final String iconName;
  final ValueChanged<bool> onChanged;
  final bool handEnabled;   // من زر اليد
  final bool reorderMode;   // من وضع إعادة الترتيب

  const ToggleButton({
    super.key,
    required this.label,
    required this.iconName,
    required this.onChanged,
    required this.handEnabled,
    required this.reorderMode,
  });

  @override
  State<ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<ToggleButton> {
  bool isPressed = false;

  void _down() {
    // يشتغل فقط إذا اليد ON ومو بوضع إعادة الترتيب
    if (!widget.handEnabled || widget.reorderMode || isPressed) return;
    setState(() => isPressed = true);
    widget.onChanged(true);
  }

  void _up() {
    if (!isPressed) return;
    setState(() => isPressed = false);
    widget.onChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final buttonW = screenW * 0.22;
    final iconSize = buttonW * 0.7;

    final bool tapEnabled = widget.handEnabled && !widget.reorderMode;

    final Color bg = tapEnabled
        ? (isPressed ? Colors.blue.shade700 : Colors.black) // ✅ أسود لما اليد شغّالة
        : Colors.grey.shade500;

    return Listener(
      behavior: HitTestBehavior.opaque, // يسمح بعدّة أصابع على عدّة أزرار
      onPointerDown: (_) => _down(),
      onPointerUp: (_) => _up(),
      onPointerCancel: (_) => _up(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Image.asset(
            'assets/icons/${widget.iconName}',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }}