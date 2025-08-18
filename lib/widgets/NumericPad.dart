import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cotrollers/shield_controller.dart';
import 'toggle_button.dart';

class ReorderableToggleGrid extends StatefulWidget {
  final ValueNotifier<bool> handEnabledNotifier;   // زر اليد
  final ValueNotifier<bool> reorderModeNotifier;   // وضع الترتيب
  final ShieldController controller;
  final double topSpacing;

  const ReorderableToggleGrid({
    super.key,
    required this.handEnabledNotifier,
    required this.reorderModeNotifier,
    required this.controller,
    this.topSpacing = 20,
  });

  @override
  State<ReorderableToggleGrid> createState() => _ReorderableToggleGridState();
}

class _ReorderableToggleGridState extends State<ReorderableToggleGrid> {
  static const Map<String, int> valveCodeByLabel = {
    '0': 0x0000, '1': 0x0001, '2': 0x0002, '3': 0x0003, '4': 0x0004,
    '5': 0x0005, '6': 0x0006, '7': 0x0007, '8': 0x0008, '9': 0x0009,
    'i': 0x0011, 'x': 0x0012,
  };

  List<Map<String, String>> buttons = [
    {'label': '0', 'icon': 'T_Baselift_Ext.png'},
    {'label': '1', 'icon': 'T_Lowering.png'},
    {'label': '2', 'icon': 'T_Pull.png'},
    {'label': '3', 'icon': 'T_Push.png'},
    {'label': '4', 'icon': 'T_Setting.png'},
    {'label': '5', 'icon': 'T_Side_R_Ext.png'},
    {'label': '6', 'icon': 'T_Side_R_Retr.png'},
    {'label': '7', 'icon': 'T_Spray_Track.png'},
    {'label': '8', 'icon': 'T_Stab_Ext.png'},
    {'label': '9', 'icon': 'T_Stab_Retr.png'},
    {'label': 'i', 'icon': 'T_TFlipper_3_Ext.png'},
    {'label': 'x', 'icon': 'T_TFlipper_3_Retr.png'},
  ];

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('buttonOrder');
    if (saved == null) return;
    setState(() {
      buttons.sort((a, b) => saved.indexOf(a['label']!) - saved.indexOf(b['label']!));
    });
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('buttonOrder', buttons.map((b) => b['label']!).toList());
  }

  @override
  Widget build(BuildContext context) {
    const columns = 4;
    final screenW = MediaQuery.of(context).size.width;
    final tileW = screenW / columns;
    const aspect = 0.85;
    final tileH = tileW / aspect;
    const spacing = 12.0;
    final rows = (buttons.length / columns).ceil();
    final gridH = rows * tileH + (rows - 1) * spacing;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, widget.topSpacing, 12, 12),
      child: SizedBox(
        height: gridH,
        child: ValueListenableBuilder<bool>(
          valueListenable: widget.reorderModeNotifier,
          builder: (_, reorderMode, _) {
        return ValueListenableBuilder<bool>(
        valueListenable: widget.handEnabledNotifier,
        builder: (_, handEnabled, _) {
        return ReorderableGridView.builder(
        key: const PageStorageKey('valve-grid'),
        dragEnabled: reorderMode,                         // ✅ السحب فقط عند Reorder
        dragStartBehavior: DragStartBehavior.down,
        dragStartDelay: const Duration(milliseconds: 250),
        onReorder: (oldIndex, newIndex) {
        setState(() {
        final it = buttons.removeAt(oldIndex);
        buttons.insert(newIndex, it);
        });
        _saveOrder();
        },
        itemCount: buttons.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: aspect,
        ),
        itemBuilder: (context, index) {
        final btn = buttons[index];
        final label = btn['label']!;
        final icon = btn['icon']!;
        final slot = index.clamp(0, 5); // أول 6 فقط لإرسال أوامر متزامنة

        return ToggleButton(
        key: ValueKey(label),
        label: label,
        iconName: icon,
        handEnabled: handEnabled,
        reorderMode: reorderMode,
        onChanged: (isOn) {
        final code = valveCodeByLabel[label] ?? 0;
        if (isOn) {
        widget.controller.setValveFunction(slot, code);
        } else {
        widget.controller.clearValveSlot(slot);
        }
        },
        );
        },
        dragWidgetBuilder: (index, child) => Material(child: child),
        );
        },
        );
        },
        ),
      ),
    );
  }}