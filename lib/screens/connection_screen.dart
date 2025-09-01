import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../cotrollers/shield_controller.dart';
import '../services/bluetooth_services.dart' as custom;
import 'ControlScreen.dart';

const bool FILTER_DRD_ONLY = true;
const String DRD_PREFIX = 'DRD_';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final Map<String, BluetoothDevice> _devices = {};
  late ShieldController _controller;
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();

    _controller = ShieldController(
      currentShield: 5,
      selectionDistance: 0,
      groupSize: 0,
      selectionDirection: Direction.none,
      onUpdate: () => setState(() {}),
    );
   // _controller.initDummyData();
    _controller.clearData();
    _initBluetoothAndScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _initBluetoothAndScan() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final isOn = await FlutterBluePlus.isOn;
    if (!isOn && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth is turned off')),
      );
      return;
    }

    _startScan();
  }

  void _startScan() {
    _devices.clear();
    setState(() => _scanning = true);

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final d = r.device;
        final name = _deviceName(d);
        final ok = FILTER_DRD_ONLY
            ? (name.isNotEmpty && name.startsWith(DRD_PREFIX))
            : name.isNotEmpty;
        if (ok) {
          _devices[d.remoteId.str] = d;
        }
      }
      if (mounted) setState(() {});
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 6)).whenComplete(() {
      if (mounted) setState(() => _scanning = false);
    });
  }

  Future<void> _refresh() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _startScan();
  }

  Future<void> _connect(BluetoothDevice device) async {
    // مهم: أوقفي المسح قبل الاتصال
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    final bestName= _deviceName(device);
    _controller.connectionShieldName=bestName;
    _controller.onUpdate?.call();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final service = custom.BluetoothService(
      shieldController: _controller,
      deviceName: bestName,
      onDataReceived: (data) {
        print("RX: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");}
    );

    try {
      await service.connect(device);
      if (!mounted) return;
      Navigator.of(context).pop();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ControlScreen(
            controller: _controller,
            bluetoothService: service,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }

  }

  String _deviceName(BluetoothDevice d) {
    final name = d.platformName.isNotEmpty
        ? d.platformName
        : (d.localName.isNotEmpty == true ? d.localName : d.advName);
    return name ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final devices = _devices.values.toList()
      ..sort((a, b) => _deviceName(a).compareTo(_deviceName(b)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection'),
        backgroundColor: const Color(0xFF1976D2),
      ),
      backgroundColor: const Color(0xFFF0F4FF),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            Row(
              children: [
                Text(
                  _scanning ? 'Searching for devices…' : 'Scan complete',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                if (_scanning)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (devices.isEmpty)
              Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('No devices found'),
                  subtitle: Text(FILTER_DRD_ONLY
                      ? 'Filtering is ON ($DRD_PREFIX…). Try turning it off in code or move closer.'
                      : 'Make sure Bluetooth is on and devices are advertising.'),
                  trailing: TextButton(onPressed: _refresh, child: const Text('Rescan')),
                ),
              )
            else
              ...devices.map((d) {
                final name = _deviceName(d);
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.developer_board, color: Colors.blue),
                    title: Text(name.isEmpty ? '(Unnamed)' : name),
                    subtitle: Text(d.remoteId.str),
                    trailing: const Icon(Icons.bluetooth),
                    onTap: () => _connect(d),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }}