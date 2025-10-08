import 'package:drd_app/cotrollers/shield_controller.dart';
import 'package:drd_app/screens/connection_screen.dart';
import 'package:drd_app/widgets/cards_sections.dart';
import 'package:drd_app/widgets/control_bottom_switcher.dart';
import 'package:flutter/material.dart';

import '../services/bluetooth_services.dart';



class ControlScreen extends StatefulWidget {
  final ShieldController controller;
  final BluetoothService bluetoothService;

  const ControlScreen({
    super.key,
    required this.controller,
    required this.bluetoothService,
  });

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  // زر اليد: يفعّل/يعطّل الأزرار فقط
  final ValueNotifier<bool> _isGridEnabled = ValueNotifier(false);

  // وضع إعادة الترتيب: من المينيو فقط
  final ValueNotifier<bool> isReorderMode = ValueNotifier(false);

  ShieldController get controller => widget.controller;
  BluetoothService get bluetoothService => widget.bluetoothService;

  @override
  void initState() {
    super.initState();
    // 🟢 شغّل مؤقت الخمول أول ما تفتح الشاشة
    controller.resetInactivityTimer(() {
      bluetoothService.disconnect();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ConnectionScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _isGridEnabled.dispose();
    isReorderMode.dispose();
    controller.cancelInactivityTimer(); // 🟢 أوقف مؤقت الخمول
    controller.reset();
    bluetoothService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: _buildAppBarTitle(controller),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: .6, color: Colors.grey.shade300),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenW * .05),
        child: Column(
          children: [
            // أعلى الشاشة: الكارد/الفيجوال/الجدول
            ControlInfoAndShieldSection(controller: controller),

            // سويتشر الأزرار + الأسهم
            ControlBottomSwitcher(
              handEnabled: _isGridEnabled,
              reorderMode: isReorderMode,
              controller: controller,
              onUserInteraction: () {
                controller.resetInactivityTimer(() {
                  bluetoothService.disconnect();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/connection');
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(ShieldController controller) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
    // القائمة + الاسم
    Expanded(
    child: Row(
    children: [
        PopupMenuButton<String>(
        icon: const Icon(Icons.menu, color: Colors.black87),
    onSelected: (v) {
    if (v == 'back') {
    Navigator.of(context).maybePop();
    } else if (v == 'reorder') {
    isReorderMode.value = !isReorderMode.value;
    }
    },
    itemBuilder: (_) => [
    const PopupMenuItem(
    value: 'back',
    child: Row(
    children: [Icon(Icons.arrow_back), SizedBox(width: 8), Text('Back')],
    ),
    ),
    PopupMenuItem(
    value: 'reorder',
    child: Row(
    children: [
    const Icon(Icons.grid_view),
    const SizedBox(width: 8),
    Text(isReorderMode.value ? 'Done reordering' : 'Reorder icons'),
    ],
    ),
    ),
    ],
    ),
    const SizedBox(width: 12),
    Flexible(
    child: Text(
    controller.connectionShieldName ??
    controller.currentShield.toString().padLeft(3, '0'),
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
    color: Colors.green,
    ),
    ),
    ),
    ],
    ),
    ),

    // ✅ العداد (مع مسافة صغيرة)
    Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: ValueListenableBuilder<int>(
    valueListenable: controller.inactivitySecondsLeft,
    builder: (_, seconds, __) {
    return Text(
    "⏳ $seconds ",
    style: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.red,
    ),
    );
    },
    ),
    ),

    // زر اليد + اللوجو
    Row(
    children: [
    ValueListenableBuilder<bool>(
    valueListenable: _isGridEnabled,
    builder: (_, enabled, __) => AbsorbPointer(/*GestureDetector(
    onTapDown: (_) {
    _isGridEnabled.value = true;
    controller.resetInactivityTimer(() {
    bluetoothService.disconnect();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConnectionScreen()),
      );
    }
    });
    },
    onTapUp: (_) => _isGridEnabled.value = false,
    onTapCancel: () => _isGridEnabled.value = false,*/
    child: Container(
    decoration: BoxDecoration(
    color: Colors.white,
    border: Border.all(
    color: enabled ? Colors.green : Colors.blue.shade800,
    width: 2,
    ),
    borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(8),
    child: Image.asset(
    'assets/hand.jpg',
    width: 22,
    height: 22,
    fit: BoxFit.contain,
    ),
    ),
    ),
    ),
    const SizedBox(width: 12),
    Image.asset(
    'assets/LogoDRD.png',
    height: 40, // 🔹 خفّضنا حجم اللوجو ليتفادى overflow
    ),
    ],
    ),
    ],
    );
  }}