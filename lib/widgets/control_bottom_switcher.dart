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
    final h= (MediaQuery.of(context).size.height* 0.38).clamp(280.0, 360.0);
    return Column(
      children: [
        SizedBox(
          height: h,
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
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 6),
          child: Padding(
            padding:  EdgeInsets.only( top: 6 ),
            child: SmoothPageIndicator(
              controller: _controller,
              count: 2,
              effect: WormEffect(
                dotHeight: 8,
                dotWidth: 8,
                activeDotColor: Colors.blue.shade800,
                dotColor: Colors.grey.shade400,
              ),
            ),
          ),
        ),
      ],
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

  // زر بصورة ثابتة لكن بحجم مرن
  Widget _btn(String asset, double size, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border.all(color: Colors.grey.shade500, width: 1.5),
          borderRadius: BorderRadius.circular(12),
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
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // أبعاد مرنة:
    // - حجم الزر بين 56 و 84
    // - مسافة عمودية بين الصفوف
    final double btnSize =
    (size.width * 0.18).clamp(56.0, 84.0);      // حجم الزر
    final double rowGap =
    (size.height * 0.02).clamp(8.0, 16.0);      // فراغ بين الصفوف
    final double bottomPad =
        (bottomInset > 0 ? bottomInset : 12) + 8;   // حتى ما يختفي وراء أزرار النظام

    // لحساب total shields باليمين
    final b = controller.allowedBounds;
    final int virtualTotal = b.maxAllowed + 1;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // + Group (يسار/يمين)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _btn('assets/arrow_icon/left_plus.jpg',  btnSize, () {
                controller.groupLeft((_, _) {});
                onChanged();
              }),
              SizedBox(width: 12),
              _btn('assets/arrow_icon/right_plus.jpg', btnSize, () {
                controller.groupRight(virtualTotal, (_) {});
                onChanged();
              }),
            ],
          ),

          SizedBox(height: rowGap),

          // Select (يسار/يمين)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _btn('assets/arrow_icon/left.jpg',  btnSize, () {
                controller.selectLeft();
                onChanged();
              }),
              SizedBox(width: 12),
              _btn('assets/arrow_icon/right.jpg', btnSize, () {
                controller.selectRight(virtualTotal);
                onChanged();
              }),
            ],
          ),

          SizedBox(height: rowGap),

          // Remove (يسار/يمين)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _btn('assets/arrow_icon/left_mius.jpg',  btnSize, () {
                controller.removeFromLeft();
                onChanged();
              }),
              SizedBox(width: 12),
              _btn('assets/arrow_icon/right_mius.jpg', btnSize, () {
                controller.removeFromRight();
                onChanged();
              }),
            ],
          ),
        ],
      ),
    );
  }
}