import 'package:flutter/material.dart';
import '../cotrollers/shield_controller.dart';
import '../services/bluetooth_services.dart';

// أقسام الشاشة (الكارد + الفيجوال + الجدول):
import '../../widgets/cards_sections.dart';
// السويتشر السفلي (الأسهم + شبكة الأزرار):
import '../../widgets/control_bottom_switcher.dart';

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

  @override
  void dispose() {
    _isGridEnabled.dispose();
    isReorderMode.dispose();
    widget.controller.reset();
    widget.bluetoothService.disconnect();
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
            // أعلى الشاشة: الكارد/الفيجوال/الجدول (كما هو)
            ControlInfoAndShieldSection(controller: controller),

        // سويتشر الأزرار + الأسهم
        ControlBottomSwitcher(
          handEnabled:  _isGridEnabled,
          reorderMode:  isReorderMode,
          controller: controller,
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
    // القائمة والاسم
    Row(
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
    itemBuilder: (_) =>  [
    PopupMenuItem(
    value: 'back',
    child: Row(
    children: [Icon(Icons.arrow_back), SizedBox(width: 8), Text('Back')],
    ),
    ),
    PopupMenuItem(
    value: 'reorder',
    child: Row(
    children: [Icon(Icons.grid_view), SizedBox(width: 8), Text(isReorderMode.value ? 'Done reordering' : 'Reorder icons')],
    ),
    ),
    ],
    ),
    const SizedBox(width: 12),
    Text(
    controller.connectionShieldName != null
    ? controller.connectionShieldName!
        : controller.currentShield.toString().padLeft(3, '0'),
    style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
    color: Colors.green,
    ),
    ),
    ],
    ),

    // زر اليد + الشعار
    Row(
    children: [
    // زر اليد: يفعّل/يعطّل الأزرار فقط (لا علاقة له بالـ reorder)
    ValueListenableBuilder<bool>(
    valueListenable: _isGridEnabled,
    builder: (_, enabled, _) => GestureDetector(
    onTapDown: (_) { _isGridEnabled.value = true;
      print("hand enable true");
    },
    onTapUp: (_) { _isGridEnabled.value = false; print("hand enable false");     }
,    onTapCancel: () { _isGridEnabled.value = false;  print("hand enable false");},
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
    width: 28,
    height: 28,
    fit: BoxFit.contain,
    ),
    ),
    ),
    ),
    const SizedBox(width: 16),
    Image.asset('assets/LogoDRD.png', height: MediaQuery.of(context).size.width * .22),
    ],
    ),
    ],
    );
  }}