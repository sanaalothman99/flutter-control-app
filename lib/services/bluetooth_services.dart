import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../cotrollers/shield_controller.dart';
import '../models/shield_data.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

class BluetoothService {
  final ShieldController shieldController;
  final String deviceName;
  final void Function(List<int>) onDataReceived;


  BluetoothDevice? _device;

  // RX notify
  static final Guid serviceUUID = Guid("0000fe50-cc7a-482a-984a-7f2ed5b3e58f");
  static final Guid characteristicUUID = Guid(
      "0000fe52-8e22-4541-9d4c-21edea82ed19");

  // TX control
  static final Guid controlServiceUUID = Guid(
      "0000fe70-cc7a-482a-984a-7f2ed5b3e58f");
  static final List<Guid> controlCharUUIDs = [
    Guid("0000fe72-8e22-4541-9d4c-21edea82ed19"), // WRITE
    Guid("0000fe71-8e22-4541-9d4c-21edea82ed19"), // WNR
    Guid("0000fe73-8e22-4541-9d4c-21edea82ed19"), // WNR
  ];

  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription<List<int>>? _subscription;

  bool _isConnected = false;

  bool get isConnected => _isConnected;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  int _txCounter = 0;
  Timer? _fastTxTimer;
  Timer? _txTimer;

  int? _uniteFormDeviceName(String? name) {
    if (name == null) return null;
    final m = RegExp(r'(\d{3})$').firstMatch(name.trim());
    return m != null ? int.parse(m.group(1)!) : null;
  }

  BluetoothService({
    required this.shieldController,
    required this.deviceName,
    required this.onDataReceived,
  });

  // ================== CONNECT ==================
  Future<void> connect(BluetoothDevice device) async {
    _device = device;

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
   /* try {
      await device.disconnect();
    } catch (_) {}*/

    Future<void> tryOnce() async {
      print("🔌 Trying connect to ${device.platformName} ...");
      await _device!.connect(
          autoConnect: false, timeout: const Duration(seconds: 30));
      await _device!.connectionState.firstWhere(
            (s) => s == BluetoothConnectionState.connected,
      );
      print("✅ Connected to ${device.platformName}");
    }

    try {
      await tryOnce();
    } on FlutterBluePlusException catch (e) {
      print("⚠️ First connect failed: $e, retrying...");
      await Future.delayed(const Duration(seconds: 2));
      await tryOnce();
    }

    _connSub?.cancel();
    _connSub = _device!.connectionState.listen((s) {
      _isConnected = (s == BluetoothConnectionState.connected);
      print("🔄 Connection state changed: $s");
    });
    _isConnected = true;

    shieldController.connectionShieldName = deviceName;
   /* final u = _uniteFormDeviceName(deviceName);
    if (u != null) {
      shieldController.currentShield = u;
    }*/
    shieldController.currentShield = 0;

    // اجبار اختيار افتراضي
    shieldController
      ..selectionDistance = 0
      ..groupSize = 0
      ..selectionDirection = Direction.none;
    shieldController.onUpdate?.call();

    // ===== Discover services =====
    print("🔍 Discovering services...");
    final services = await _device!.discoverServices();

    for (final s in services) {
      print("📡 Service: ${s.uuid}");
      for (final c in s.characteristics) {
        print("   ↳ Char: ${c.uuid} "
            "props=[read=${c.properties.read}, "
            "write=${c.properties.write}, "
            "wnr=${c.properties.writeWithoutResponse}, "
            "notify=${c.properties.notify}]");
      }
    }

    // ===== RX =====
    _rxCharacteristic = null;
    for (final s in services) {
      final su = s.uuid.str.toLowerCase();
      if (su.startsWith('0000fe50')) {
        for (final c in s.characteristics) {
          final cu = c.uuid.str.toLowerCase();
          final isFe52 = cu.startsWith('0000fe52');
          final isFe51 = cu.startsWith('0000fe51');
          if ((isFe52 || isFe51) && c.properties.notify) {
            if (_rxCharacteristic == null || isFe52) {
              _rxCharacteristic = c;
            }
          }
        }
      }
    }
    if (_rxCharacteristic == null) {
      throw Exception('❌ RX notify characteristic (FE52/FE51) not found');
    }
    await _rxCharacteristic!.setNotifyValue(true);
   // print("✅ RX selected: ${_rxCharacteristic!.uuid}");

    await _subscription?.cancel();
    _subscription = _rxCharacteristic!.value.listen((data) {
    //  print("📥 RX: ${data.length} bytes [${_rxCharacteristic!.uuid}]");
     // print("📥 RX: ${data.length} bytes -> ${data.map((b) =>b.toRadixString(16).padLeft(2,'0')).join(' ')}");
      onDataReceived(data);
      _onDataReceived(data);
    });

    // ===== TX =====
    _txCharacteristic = null;
    BluetoothCharacteristic? preferWnr;
    BluetoothCharacteristic? preferWrite;

    for (final s in services) {
      final su = s.uuid.str.toLowerCase();
      if (su.startsWith('0000fe70')) {
        for (final c in s.characteristics) {
          final cu = c.uuid.str.toLowerCase();
          final isFe72 = cu.startsWith('0000fe72'); // write
          final isFe71 = cu.startsWith('0000fe71'); // wnr
          final isFe73 = cu.startsWith('0000fe73'); // wnr

          if (c.properties.writeWithoutResponse && (isFe71 || isFe73)) {
            preferWnr ??= c;
          }
          if (c.properties.write && isFe72) {
            preferWrite ??= c;
          }
        }
      }
    }

    _txCharacteristic = preferWnr ?? preferWrite;
    if (_txCharacteristic == null) {
      throw Exception('❌ TX characteristic (FE71/FE73/FE72) not found');
    }
    print('✅ TX selected: ${_txCharacteristic!.uuid} '
        '[write=${_txCharacteristic!.properties.write}, '
        'wnr=${_txCharacteristic!.properties.writeWithoutResponse}]');

    // اربطي تغيّر التحكم وابدئي heartbeat
    shieldController.onControlChanged = _onControlChanged;
    _startHeartbeat();
    await sendControlNow();
  }

  void _onControlChanged() {
    if (!_isConnected) return;

   /* final hasAny = shieldController.valveFunctions.any((v) => v != 0) ||
        shieldController.extraFunction != 0;*/
   /*  if (shieldController.selectionSizeForMcu == 0 &&
    (shieldController.valveFunctions.any((v) => v != 0) ||
    shieldController.extraFunction != 0)) {
    shieldController.groupSize = 0;
    shieldController.selectionDistance = 0;
    shieldController.selectionDirection = Direction.none;
    }*/
    // لا تغيّر selectionDistance/groupSize هون
    sendControlNow();
    final hasAny = shieldController.valveFunctions.any((v) => v != 0) ||
        shieldController.extraFunction != 0;
    if (hasAny) {
      _startFastLoop();
      _stopHeartbeat();
    } else {
      _stopFastLoop();
      _startHeartbeat();
    }
  }

  // ================== SEND ==================
  Future<void> sendControlNow() async {
    if (_txCharacteristic == null) {
      print("⚠️ TX char is null, skip send");
      return;
    }

    final Uint8List payload = shieldController.buildControlPayload(
        _txCounter++);

    final hex = payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join( ' ');
      shieldController.lastTxHex= hex;
      shieldController.onUpdate?.call();
     final btns = payload.sublist(5, 17)
        .map((b)=>b.toRadixString(16).padLeft(2,'0')).join(' ');
    print("📤 TX (${payload.length} bytes)  "
        "[${_txCharacteristic!.uuid}] "
        "mode=${_txCharacteristic!.properties.writeWithoutResponse ? 'WNR' : 'WRITE'}\n"
        "   full = $hex\n"
        "   btns = $btns   cnt=${payload[18]}  last=${payload[19]}  "
        "size=${payload[2]}  dist=${payload[3]}  dir=${payload[4]}");
    // طباعة كل البايتات بالهيكس مع الفهرس
    final hexBytes = List.generate(
      payload.length,
          (i) => "[${i.toString().padLeft(2, '0')}] ${payload[i].toRadixString(
          16).padLeft(2, '0')}",
    ).join('  ');

    print("📤 TX Payload (${payload.length} bytes):\n$hexBytes");

    final bool canNoRsp = _txCharacteristic!.properties.writeWithoutResponse;

    try {
      await _txCharacteristic!.write(payload, withoutResponse: canNoRsp);
    } catch (e) {
      print("❌ TX Error: $e");
      try {
        await _txCharacteristic!.write(payload, withoutResponse: !canNoRsp);
        print("✅ TX retried with ${!canNoRsp ? 'WNR' : 'WRITE'} and succeeded");
      } catch (e2) {
        print("❌ TX Fallback Error: $e2");
      }
    }
  }


  // Loops
  void _startFastLoop() {
    if (_fastTxTimer != null) return;
    _fastTxTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      sendControlNow();
    });
    print("⚡ Fast loop started (200ms)");
  }

  void _stopFastLoop() {
    _fastTxTimer?.cancel();
    _fastTxTimer = null;
    print("🛑 Fast loop stopped");
  }

  void _startHeartbeat() {
    _txTimer?.cancel();
    _txTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => sendControlNow());
    print("💓 Heartbeat started (20s)");
  }

  void _stopHeartbeat() {
    _txTimer?.cancel();
    _txTimer = null;
    print("🛑 Heartbeat stopped");
  }

  // ================== RX PARSE ==================
  void _onDataReceived(List<int> data) {
    const int mainLen = 19;
    const int addLen = 8;
    if (data.length < mainLen) return;

    try {
      final main = ShieldData.fromBytes(data, 0);
      shieldController.updateShieldData(0, main);

      final int extras = data.length - mainLen;
      final int nAdds = extras ~/ addLen;
      final int leftover = extras % addLen;

      for (int i = 0; i < nAdds; i++) {
        final int offset = mainLen + i * addLen;
        final s = ShieldData.fromBytes(data, offset);
        shieldController.updateShieldData(1 + i, s);
      }

      if (leftover > 0) {
        final start = mainLen + nAdds * addLen;
        final tail = data.sublist(start);
        final tailHex = _hex(tail);
        print("ℹ️ RX tail [$leftover byte(s)]: $tailHex");
      }
      shieldController.lastRxHex=_hex(data);
      shieldController.onUpdate?.call();
    } catch (e, st) {
      print("❌ RX parse error: $e");
      print(st);
    }
  }

  // ================== DISCONNECT ==================
  Future<void> disconnect() async {
    _stopFastLoop();
    _stopHeartbeat();
    shieldController.onControlChanged = null;

    await _subscription?.cancel();
    _subscription = null;

    try {
      await _device?.disconnect();
      print("✅ Disconnected successfully");
    } catch (e) {
      print("❌ Disconnect Error: $e");
    }

    _isConnected = false;
    await _connSub?.cancel();
    _connSub = null;

    _device = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;

    shieldController.clearData();
  }

  }
/*class BluetoothService {
  final ShieldController shieldController;
  final String deviceName;
  final void Function(List<int>) onDataReceived;

  // 👇 جديد
  final bool demoMode;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription<List<int>>? _subscription;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  int _txCounter = 0;
  Timer? _fastTxTimer;
  Timer? _txTimer;

  BluetoothService({
    required this.shieldController,
    required this.deviceName,
    required this.onDataReceived,
    this.demoMode = false, // 👈 افتراضي false
  });

  // 🧪 وضع تجريبي: لا بلوتوث إطلاقًا
  Future<void> enterDemoMode() async {
    _isConnected = true;
    _txCounter = 0;
    shieldController.initDummyDataForTest();
    shieldController.onControlChanged = _onControlChanged;
    _startHeartbeat(); // اختياري
    print("🧪 DEMO MODE: connected (fake), dummy data loaded.");
  }

  // ================== CONNECT ==================
  Future<void> connect(BluetoothDevice device) async {
    if (demoMode) {
      await enterDemoMode();
      return; // ✅ لا تكمّلي اكتشاف خدمات
    }

    _device = device;
    // ... بقية كود الاتصال الحقيقي تبعِك بدون تغيير ...
  }

  void _onControlChanged() {
    if (!_isConnected) return;

    final hasAny = shieldController.valveFunctions.any((v) => v != 0) ||
        shieldController.extraFunction != 0;

    sendControlNow();

    if (hasAny) {
      _startFastLoop();
      _stopHeartbeat();
    } else {
      _stopFastLoop();
      _startHeartbeat();
    }
  }

  // ================== SEND ==================
  Future<void> sendControlNow() async {
    final payload = shieldController.buildControlPayload(_txCounter++);

    if (demoMode) {
      // 👇 جرّب وطبع بس
      final hex = payload.map((b) => b.toRadixString(16).padLeft(2,'0')).join(' ');
      final btns = payload.sublist(5, 17).map((b)=>b.toRadixString(16).padLeft(2,'0')).join(' ');
      print("📤 DEMO TX (${payload.length} bytes):");
      print("   full = $hex");
      print("   btns = $btns   cnt=${payload[18]}  last=${payload[19]}  "
          "size=${payload[2]}  dist=${payload[3]}  dir=${payload[4]}");
      return;
    }

    // --- وضع حقيقي (بدون تعديل) ---
    if (_txCharacteristic == null) {
      print("⚠️ TX char is null, skip send");
      return;
    }
    final bool canNoRsp = _txCharacteristic!.properties.writeWithoutResponse;
    try {
      await _txCharacteristic!.write(payload, withoutResponse: canNoRsp);
    } catch (e) {
      print("❌ TX Error: $e");
      try {
        await _txCharacteristic!.write(payload, withoutResponse: !canNoRsp);
        print("✅ TX retried with ${!canNoRsp ? 'WNR' : 'WRITE'} and succeeded");
      } catch (e2) {
        print("❌ TX Fallback Error: $e2");
      }
    }
  }

  // نفس تايمراتك:
  void _startFastLoop() {
    if (_fastTxTimer != null) return;
    _fastTxTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      sendControlNow();
    });
    print("⚡ Fast loop started (200ms)");
  }

  void _stopFastLoop() {
    _fastTxTimer?.cancel();
    _fastTxTimer = null;
    print("🛑 Fast loop stopped");
  }

  void _startHeartbeat() {
    _txTimer?.cancel();
    _txTimer = Timer.periodic(const Duration(seconds: 20), (_) => sendControlNow());
    print("💓 Heartbeat started (20s)");
  }

  void _stopHeartbeat() {
    _txTimer?.cancel();
    _txTimer = null;
    print("🛑 Heartbeat stopped");
  }
  Future<void> disconnect() async {
    _stopFastLoop();
    _stopHeartbeat();
    shieldController.onControlChanged = null;

    await _subscription?.cancel();
    _subscription = null;

    try {
      await _device?.disconnect();
      print("✅ Disconnected successfully");
    } catch (e) {
      print("❌ Disconnect Error: $e");
    }

    _isConnected = false;
    await _connSub?.cancel();
    _connSub = null;

    _device = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;

    shieldController.clearData();
  }
}*/
