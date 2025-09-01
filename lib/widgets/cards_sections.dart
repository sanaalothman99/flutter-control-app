import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../cotrollers/shield_controller.dart';
import '../utils/responsive.dart';
import 'ShieldDataTable.dart';
import 'controller_info_with_pad.dart';
import 'shield_visualizer_section.dart';

class ControlInfoAndShieldSection extends StatefulWidget {
  final ShieldController controller;

  const ControlInfoAndShieldSection({
    super.key,
    required this.controller,
  });

  @override
  State<ControlInfoAndShieldSection> createState() =>
      _ControlInfoAndShieldSectionState();
}

class _ControlInfoAndShieldSectionState
    extends State<ControlInfoAndShieldSection> {
  final PageController _pageController = PageController();
  final ScrollController _tableScrollController = ScrollController();

  bool get showTable =>
      widget.controller.selectionDistance != 0 ||
          widget.controller.groupSize > 0;

  List<int> get displayedShields {
    final list = <int>[widget.controller.currentShield];

    // إذا لم يكن هناك مجموعة، نعرض الـ highlighted فقط
    if (widget.controller.selectionDistance != 0 &&
        widget.controller.groupSize == 0) {
      list.add(widget.controller.selectionStart);
    }

    list.addAll(widget.controller.selectedShields);
    return list.toSet().toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    widget.controller.onUpdate = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final ui = UIScale.of(context);

    return Expanded(
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: ui.pageH,
            child: PageView(
              controller: _pageController,
              children: [
                ControllerInfoWithPad(controller: c),
                ShieldVisualizerSection(controller: c),
                Scrollbar(
                  controller: _tableScrollController,
                  thumbVisibility: true,
                  radius: const Radius.circular(10),
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ShieldInfoTable(
                      shields: c.shields,
                      currentShield: c.currentShield,
                      highlightedShield: c.selectionDistance != 0 &&
                          c.groupSize == 0 ? c.selectionStart : null,
                      selectedShields: displayedShields,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ui.gapBelowPage),
          Padding(
            padding: EdgeInsets.only(bottom: ui.indicatorPad),
            child: SmoothPageIndicator(
              controller: _pageController,
              count: 3,
              effect: WormEffect(
                dotHeight: 8, dotWidth: 8,
                activeDotColor: Colors.blue.shade800,
                dotColor: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }}