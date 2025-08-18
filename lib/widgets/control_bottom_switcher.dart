import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../cotrollers/shield_controller.dart';
import 'NumericPad.dart';

class ControlBottomSwitcher extends StatefulWidget {
  final ValueNotifier<bool> handEnabled;   // زر اليد
  final ValueNotifier<bool> reorderMode;   // من المنيو
  final ShieldController controller;

  const ControlBottomSwitcher({
    super.key,
    required this.handEnabled,
    required this.reorderMode,
    required this.controller,
  });

  @override
  State<ControlBottomSwitcher> createState() => _ControlBottomSwitcherState();
}

class _ControlBottomSwitcherState extends State<ControlBottomSwitcher> {
  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 310,
      child: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: widget.handEnabled,
              builder: (_, handOn, _) {
            return PageView(
            controller: _controller,
            // ✅ سحب مفعّل فقط إذا اليد مطفية
            physics: handOn
            ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            children: [
            _ArrowControlsPage(
            controller: widget.controller,
            onChanged: () => setState(() {}),
            ),
            ReorderableToggleGrid(
            handEnabledNotifier: widget.handEnabled,
            reorderModeNotifier: widget.reorderMode,
            controller: widget.controller,
            topSpacing: 20,
            ),
            ],
            );
            },
            ),
          ),
          const SizedBox(height: 8),
          SmoothPageIndicator(
            controller: _controller,
            count: 2,
            effect: WormEffect(
              dotHeight: 8,
              dotWidth: 8,
              activeDotColor: Colors.blue.shade800,
              dotColor: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
class _ArrowControlsPage extends StatelessWidget {
  final ShieldController controller;
  final VoidCallback onChanged;

  const _ArrowControlsPage({
    required this.controller,
    required this.onChanged,
  });

  Widget _btn(String asset, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // ✅ امنع تمرير اللمسة للـPageView
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border.all(color: Colors.grey.shade500, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = controller.allowedBounds;
    final int virtualTotal = b.maxAllowed + 1;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // + Group (يسار/يمين)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _btn('assets/arrow_icon/left_plus.jpg', () {
                controller.groupLeft((_, _) {});
                onChanged();
              }),
              _btn('assets/arrow_icon/right_plus.jpg', () {
                controller.groupRight(virtualTotal, (_) {});
                onChanged();
              }),
            ],
          ),
          // Select (يسار/يمين)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _btn('assets/arrow_icon/left.jpg', () {
                controller.selectLeft();
                onChanged();
              }),
              _btn('assets/arrow_icon/right.jpg', () {
                controller.selectRight(virtualTotal);
                onChanged();
              }),
            ],
          ),
          // Remove (يسار/يمين)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _btn('assets/arrow_icon/left_mius.jpg', () {
                controller.removeFromLeft();
                onChanged();
              }),
              _btn('assets/arrow_icon/right_mius.jpg', () {
                controller.removeFromRight();
                onChanged();
              }),
            ],
          ),
        ],
      ),
    );
  }}