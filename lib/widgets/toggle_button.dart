import 'package:flutter/material.dart';
import '../cotrollers/shield_controller.dart';

class ToggleButton extends StatefulWidget {
  final String label;
  final String iconName;
  final ValueChanged<bool> onChanged;
  final bool handEnabled;
  final bool reorderMode;
  final ShieldController controller;

  const ToggleButton({
    super.key,
    required this.label,
    required this.iconName,
    required this.onChanged,
    required this.handEnabled,
    required this.reorderMode,
    required this.controller,
  });

  @override
  State<ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<ToggleButton> {
  bool isPressed = false;
  bool keepSending = false;

  void _down(PointerDownEvent event) {
    if (!widget.handEnabled || widget.reorderMode) return;
    if (isPressed) return;

    setState(() => isPressed = true);

    widget.controller.pauseIdleTimer();
    widget.controller.userInteracted(() {});
    widget.onChanged(true);

    keepSending = true;
    _continuousSend();
  }

  void _up(PointerUpEvent event) {
    if (!isPressed) return;
    setState(() => isPressed = false);
    keepSending = false;

    widget.controller.resumeIdleTimer();
    widget.onChanged(false);
  }

  Future<void> _continuousSend() async {
    while (keepSending) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (keepSending) widget.onChanged(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final buttonW = screenW * 0.22;
    final iconSize = buttonW * 0.7;
    final bool tapEnabled = widget.handEnabled && !widget.reorderMode;

    final Color bg = tapEnabled
        ? (isPressed ? Colors.blueAccent : Colors.black)
        : Colors.grey.shade500;

    return Listener(
      // 🟢 أهم جزء: لكل زر جلسة لمس مستقلة بدون حجز الأحداث
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: (e) => _up(PointerUpEvent()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: IgnorePointer(
          child: Center(
            child: Image.asset(
              'assets/icons/${widget.iconName}',
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}