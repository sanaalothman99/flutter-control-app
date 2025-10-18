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
  final VoidCallback? onUserInteraction;

  const ReorderableToggleGrid({
    super.key,
    required this.handEnabledNotifier,
    required this.reorderModeNotifier,
    required this.controller,
    this.topSpacing = 20,
    this.onUserInteraction,
  });

  @override
  State<ReorderableToggleGrid> createState() => _ReorderableToggleGridState();
}

class _ReorderableToggleGridState extends State<ReorderableToggleGrid> {
  static const Map<String, int> valveCodeByLabel = {
    '0': 0x0012,
    '1': 0x0001,
    '2': 0x000C,
    '3': 0x0033,
    '4': 0x0002,
    '5': 0x000B,
    '6': 0x0032,
    '7': 0x002D,
    '8': 0x001D,
    '9': 0x0031,
    'i': 0x002E,
    'x': 0x0011,
  };

  List<Map<String, String>> buttons = [
    {'label': '8', 'icon': 'T_Baselift_Ext.png'},
    {'label': '4', 'icon': 'T_Lowering.png'},
    {'label': '5', 'icon': 'T_Pull.png'},
    {'label': '2', 'icon': 'T_Push.png'},
    {'label': '1', 'icon': 'T_Setting.png'},
    {'label': '7', 'icon': 'T_Side_R_Ext.png'},
    {'label': 'i', 'icon': 'T_Side_R_Retr.png'},
    {'label': '9', 'icon': 'T_Spray_Track.png'},
    {'label': '6', 'icon': 'T_Stab_Ext.png'},
    {'label': '3', 'icon': 'T_Stab_Retr.png'},
    {'label': 'x', 'icon': 'T_Flipper_Ext.png'},
    {'label': '0', 'icon': 'T_Flipper_Retr.png'},
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
      buttons.sort((a, b) =>
      saved.indexOf(a['label']!) - saved.indexOf(b['label']!));
    });
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'buttonOrder',
      buttons.map((b) => b['label']!).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const columns = 4;
    final screenW = MediaQuery.of(context).size.width;
    final tileW = screenW / columns;
    const aspect = 0.95;
    final tileH = tileW / aspect;
    const spacing = 10.0;
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
        // 🟢 وضع الترتيب: نستخدم ReorderableGridView
        if (reorderMode) {
        return ReorderableGridView.builder(
        key: const PageStorageKey('valve-grid-reorder'),
        dragEnabled: true,
        dragStartBehavior: DragStartBehavior.down,
        dragStartDelay: const Duration(milliseconds: 250),
        onReorder: (oldIndex, newIndex) {
        setState(() {
        final item = buttons.removeAt(oldIndex);
        buttons.insert(newIndex, item);
        });
        _saveOrder();
        },
        itemCount: buttons.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: aspect,
        ),
        itemBuilder: (context, index) {
        final btn = buttons[index];
        return ToggleButton(
        key: ValueKey(btn['label']),
        label: btn['label']!,
        iconName: btn['icon']!,
        handEnabled: false,
        reorderMode: true,
        controller: widget.controller,
        onChanged: (_) {},
        );
        },
        dragWidgetBuilder: (index, child) => Material(child: child),
        );
        }

        // 🟢 الوضع العادي: GridView (multi-touch + تحديث الجدول)
        return GridView.builder(
        key: const PageStorageKey('valve-grid-normal'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: aspect,
        ),
        itemCount: buttons.length,
        itemBuilder: (context, index) {
        final btn = buttons[index];
        final label = btn['label']!;
        final icon = btn['icon']!;
        final code = valveCodeByLabel[label] ?? 0;

        return ToggleButton(
        key: ValueKey(label),
        label: label,
        iconName: icon,
        handEnabled: handEnabled,
        reorderMode: false,
        controller: widget.controller,
        onChanged: (isOn) {
        if (reorderMode) return;

        int slot = widget.controller.findSlotByCode(code);

        if (isOn) {
        if (slot == -1) {
        slot = widget.controller.firstFreeSlot();
        if (slot == -1) {
        print("⚠️ لا توجد خانة شاغرة لتفعيل $label");
        return;
        }
        }
        widget.controller.setValveFunction(slot, code);
        } else {
        if (slot != -1) {
        widget.controller.clearValveSlot(slot);
        }
        }

        // ✅ تحديث الجدول والرسم مثل السابق
        final selected = widget.controller.selectedShields;
        if (selected.isNotEmpty) {
        for (final shieldNumber in selected) {
        final data = widget.controller.tryGetUnit(shieldNumber);
        if (data != null) {
        widget.controller.updateShieldData(shieldNumber, data);
        }
        }
        } else {
        final mainData = widget.controller.shields.isNotEmpty
        ? widget.controller.shields.first
            : null;
        if (mainData != null) {
        widget.controller.updateShieldData(
        widget.controller.currentShield,
        mainData,
        );
        }
        }

        widget.controller.onUpdate?.call();
        widget.controller.onControlChanged?.call();
        widget.controller.userInteracted(() {});
        widget.controller.pauseIdleTimer();

        widget.onUserInteraction?.call();
        },
        );
        },
        );
        },
        );
        },
        ),
      ),
    );
  }
}