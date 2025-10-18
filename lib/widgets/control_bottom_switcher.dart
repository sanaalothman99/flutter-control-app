import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../cotrollers/shield_controller.dart';
import '../screens/connection_screen.dart';
import 'NumericPad.dart';

class ControlBottomSwitcher extends StatefulWidget {
  final ValueNotifier<bool> handEnabled;
  final ValueNotifier<bool> reorderMode;
  final ShieldController controller;
  final VoidCallback onUserInteraction;

  const ControlBottomSwitcher({
    super.key,
    required this.handEnabled,
    required this.reorderMode,
    required this.controller,
    required this.onUserInteraction,
  });

  @override
  State<ControlBottomSwitcher> createState() => _ControlBottomSwitcherState();
}

class _ControlBottomSwitcherState extends State<ControlBottomSwitcher> {
  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    final h = (MediaQuery.of(context).size.height * 0.38).clamp(280.0, 360.0);

    return Column(
      children: [
        SizedBox(
          height: h,
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.handEnabled,
            builder: (_, handOn, _) {
          return RawGestureDetector(
          gestures: <Type, GestureRecognizerFactory>{
          HorizontalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<
          HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(),
          (HorizontalDragGestureRecognizer instance) {
          instance
          ..onUpdate = (details) {
          _controller.position.moveTo(
          _controller.offset - details.primaryDelta!,
          );
          }
          ..onEnd = (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() > 200) {
          final nextPage = velocity < 0
          ? (_controller.page!.ceil())
              : (_controller.page!.floor());
          _controller.animateToPage(
          nextPage.clamp(0, 1),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          );
          } else {
          _controller.animateToPage(
          _controller.page!.round().clamp(0, 1),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          );
          }
          };
          },
          ),
          },
          behavior: HitTestBehavior.translucent,
          child: PageView(
          controller: _controller,
          physics:
          const NeverScrollableScrollPhysics(), // منع scroll الافتراضي
          children: [
          _ArrowControlsPage(
          controller: widget.controller,
          onChanged: () {
          widget.onUserInteraction();
          setState(() {});
          },
          ),
          ReorderableToggleGrid(
          handEnabledNotifier: widget.handEnabled,
          reorderModeNotifier: widget.reorderMode,
          controller: widget.controller,
          topSpacing: 20,
          onUserInteraction: () {
          widget.controller.userInteracted(() {
          Navigator.of(context).pushReplacement(
          MaterialPageRoute(
          builder: (_) => const ConnectionScreen(),
          ),
          );
          });
          },
          ),
          ],
          ),
          );
          },
          ),
        ),
        const SizedBox(height: 8),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 6),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SmoothPageIndicator(
              controller: _controller,
              count: 2,
              effect: WormEffect(
                dotHeight: 8,
                dotWidth: 8,
                activeDotColor: Colors.blue.shade800,
                dotColor: Colors.grey.shade400,
              ),
              onDotClicked: (index) {
                _controller.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
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

  Widget _btn(String asset, double size, VoidCallback onTap) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        onTap();
        onChanged();
      },
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
          child: IgnorePointer(
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final double btnSize = (size.width * 0.18).clamp(56.0, 84.0);
    final double rowGap = (size.height * 0.02).clamp(8.0, 16.0);
    final double bottomPad = (bottomInset > 0 ? bottomInset : 12) + 8;

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
              _btn('assets/arrow_icon/left_plus.jpg', btnSize, () {
                controller.groupLeft((_, _) {});
              }),
              SizedBox(width: 12),
              _btn('assets/arrow_icon/right_plus.jpg', btnSize, () {
                controller.groupRight(virtualTotal, (_) {});
              }),
            ],
          ),
          SizedBox(height: rowGap),

          // Select (يسار/يمين)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _btn('assets/arrow_icon/left.jpg', btnSize, () {
                controller.selectLeft();
              }),
              SizedBox(width: 12),
              _btn('assets/arrow_icon/right.jpg', btnSize, () {
                controller.selectRight(virtualTotal);
              }),
            ],
          ),
          SizedBox(height: rowGap),

          // Remove (يسار/يمين)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _btn('assets/arrow_icon/left_mius.jpg', btnSize, () {
                controller.removeFromLeft();
              }),
              SizedBox(width: 12),
              _btn('assets/arrow_icon/right_mius.jpg', btnSize, () {
                controller.removeFromRight();
              }),
            ],
          ),
        ],
      ),
    );
  }
}