import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../cotrollers/shield_controller.dart';
import '../models/shield_data.dart';

// ===== Helpers (للطباعة) =====
String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

class BluetoothService {
  final ShieldController shieldController;
  final String deviceName;
  final void Function(List<int>) onDataReceived;

  BluetoothDevice? _device;

  // RX (notify) — مستشعرات
  static final Guid serviceUUID        = Guid("0000fe50-cc7a-482a-984a-7f2ed5b3e58f");
  static final Guid characteristicUUID = Guid("0000fe52-8e22-4541-9d4c-21edea82ed19");

  // TX (control write) — (fe70 service)
  static final Guid controlServiceUUID = Guid("0000fe70-cc7a-482a-984a-7f2ed5b3e58f");
  static final List<Guid> controlCharUUIDs = [
    Guid("0000fe72-8e22-4541-9d4c-21edea82ed19"), // WRITE
    Guid("0000fe71-8e22-4541-9d4c-21edea82ed19"), // WNR
    Guid("0000fe73-8e22-4541-9d4c-21edea82ed19"), // WNR
  ];

  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription<List<int>>? _subscription;

  // تتبُّع الاتصال
  bool _isConnected = false;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  // عدّاد تلغرام
  int _txCounter = 0;

  // جدولة الإرسال
  Timer? _fastTxTimer;   // 200ms أثناء النشاط
  Timer? _txTimer;       // 20s هارتبيت
  DateTime _lastUserActivity = DateTime.now();
  Timer? _idleWatchdog;
  static const Duration _idleTimeout = Duration(seconds: 30);

  void _bumpActivity() => _lastUserActivity = DateTime.now();

 /* void _startIdleWatchdog() {
    _idleWatchdog?.cancel();
    _idleWatchdog = Timer.periodic(const Duration(seconds: 1), (_) async {
      final idleFor = DateTime.now().difference(_lastUserActivity);
      final hasActive = shieldController.valveFunctions.any((v) => v != 0) ||
          (shieldController.extraFunction != 0);
      if (!hasActive && idleFor >= _idleTimeout) {
        try { await disconnect(); } catch (_) {}
      }
    });
  }*/

  /*void _stopIdleWatchdog() {
    _idleWatchdog?.cancel();
    _idleWatchdog = null;
  }*/

  int? _uniteFormDeviceName(String? name){
    if(name==null) return null;
    final m= RegExp(r'(\d{3})$').firstMatch(name.trim());
    return m!=null ? int.parse(m.group((1))!): null;
  }

  BluetoothService({
    required this.shieldController,
    required this.deviceName,
    required this.onDataReceived,
  });

  // ================== CONNECT ==================
  Future<void> connect(BluetoothDevice device) async {
    _device = device;

    // أوقف أي scan/محاولة سابقة
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    try { await device.disconnect(); } catch (_) {}

    // محاولة اتصال (مع انتظار حالة connected)
    Future<void> tryOnce() async {
    //  print('🔌 Connecting to ${device.platformName} (${device.remoteId.str}) ...');
      await _device!.connect(autoConnect: false, timeout: const Duration(seconds: 30));
      await _device!.connectionState.firstWhere(
            (s) => s == BluetoothConnectionState.connected,
      );
    }

    try {
      await tryOnce();
    } on FlutterBluePlusException catch (e) {
      print('❌ Connect error 1: $e');
      await Future.delayed(const Duration(seconds: 2));
      await tryOnce();
    }

    // تتبّع حالة الاتصال
    _connSub?.cancel();
    _connSub = _device!.connectionState.listen((s) {
      _isConnected = (s == BluetoothConnectionState.connected);
    });
    _isConnected = true;

    print('✅ Connected.');
    shieldController.connectionShieldName = deviceName;
    final u= _uniteFormDeviceName(deviceName);
    if(u!= null){
      shieldController.currentShield =u;}
    shieldController.onUpdate?.call(); // يحدث الـ AppBar فورًا

    // اكتشاف الخدمات
    print('🔍 Discovering services...');
    await Future.delayed(const Duration(milliseconds: 400));
    final services = await _device!.discoverServices();

    // ====== RX ======
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
      throw Exception('RX notify characteristic (FE52/FE51) not found');
    }

    await _rxCharacteristic!.setNotifyValue(true);
   // print('✅ RX notifications enabled on ${_rxCharacteristic!.uuid}');

    await _subscription?.cancel();
    _subscription = _rxCharacteristic!.value.listen((data) {
    //  print('📥 RX (${data.length} bytes) [${_rxCharacteristic!.uuid}]: ${_hex(data)}');
      onDataReceived(data);
      _onDataReceived(data);
    });

// =============== TX (Write/WriteWithoutResponse) ===============
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
            preferWnr ??= c;                 // أول WNR
          }
          if (c.properties.write && isFe72) {
            preferWrite ??= c;               // أول WRITE
          }
        }
      }
    }

// فضّل WNR، وإذا ما وجدت خُذ WRITE
    _txCharacteristic = preferWnr ?? preferWrite;

    if (_txCharacteristic == null) {
      throw Exception('TX characteristic (FE71/FE73/FE72) not found');
    }
    print('✅ TX selected: ${_txCharacteristic!.uuid} '
        '[write=${_txCharacteristic!.properties.write}, '
        'wnr=${_txCharacteristic!.properties.writeWithoutResponse}]');

    // اربطي تغيّر التحكم وابدئي heartbeat
    shieldController.onControlChanged = _onControlChanged;
    _startHeartbeat();
    await sendControlNow();

    _bumpActivity();
   // _startIdleWatchdog();
  }

  // يُستدعى كل ما تغيّر شيء بالتحكم
  void _onControlChanged() {
    // لو غير متصل لا تعملي أي شيء
    if (!_isConnected) return;

    _bumpActivity();
    sendControlNow();

    final hasActive = shieldController.valveFunctions.any((v) => v != 0) ||
        (shieldController.extraFunction != 0);

    if (hasActive) {
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

    final Uint8List payload = shieldController.buildControlPayload(_txCounter++);

    // طباعة مرتّبة
    final hex = payload.map((b)=>b.toRadixString(16).padLeft(2,'0')).join(' ');
    final btns = payload.sublist(5, 17) // [5..16]
        .map((b)=>b.toRadixString(16).padLeft(2,'0')).join(' ');
    print("📤 TX (${payload.length} bytes)  "
        "[${_txCharacteristic!.uuid}] "
        "mode=${_txCharacteristic!.properties.writeWithoutResponse ? 'WNR' : 'WRITE'}\n"
        "   full = $hex\n"
        "   btns = $btns   cnt=${payload[18]}  last=${payload[19]}  "
        "size=${payload[2]}  dist=${payload[3]}  dir=${payload[4]}");

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

  // ================== RX PARSE ==================
  void _onDataReceived(List<int> data) {

    // اطبع هِكس كامل للباكيت
    final rxHex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  //  print("📥 RX Raw (${data.length} bytes): $rxHex");

    // أطوال الإطارات حسب المواصفة
    const int mainLen = 19; // الشيلد الرئيسي
    const int addLen  = 8;  // كل شيلد إضافي

    if (data.length < mainLen) {
    //  print("⚠️ RX too short: ${data.length} bytes (need >= $mainLen)");
      return;
    }

    try {
      // --- الشيلد الرئيسي ---
      final main = ShieldData.fromBytes(data, 0);
      shieldController.updateShieldData(0, main);

     /* print("🛡️ Shield[0]  "
          "P1=${main.pressure1}  P2=${main.pressure2}  RAM=${main.ramStroke}  "
          "face=${main.faceOrientation}  maxDn=${main.maxDownSelection}  maxUp=${main.maxUpSelection}  "
          "moveRange=${main.moveRange}");*/

      // --- احسب عدد الإضافيين والبايتات المتبقية (tail) ---
      final int extras   = data.length - mainLen; // كل ما بعد الـ 19
      final int nAdds    = extras ~/ addLen;      // عدد الإطارات الإضافية الكاملة
      final int leftover = extras %  addLen;      // بايتات متبقية (CRC/حشو ...)

      // --- شيلدات إضافية ---
      for (int i = 0; i < nAdds; i++) {
        final int offset = mainLen + i * addLen;
        final s = ShieldData.fromBytes(data, offset);
        shieldController.updateShieldData(1 + i, s);

     /*  print("🛡️ Shield[${1 + i}]  "
            "P1=${s.pressure1}  P2=${s.pressure2}  RAM=${s.ramStroke}  "
            "face=${s.faceOrientation}  maxDn=${s.maxDownSelection}  maxUp=${s.maxUpSelection}");*/
      }

      // --- tail (إن وُجد) فقط للطباعة/المعرفة، نتجاهله في التحليل ---
      if (leftover > 0) {
        final start = mainLen + nAdds * addLen;
        final tail  = data.sublist(start);
        final tailHex = tail.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        print("ℹ️ RX tail [$leftover byte(s)]: $tailHex");
      }

      // ✅ حدّث الواجهة
      shieldController.onUpdate?.call();

    } catch (e, st) {
      // أي خطأ في parsing ما يوقف التطبيق
      print("❌ RX parse error: $e");
      print(st);
    }
  }

  // ================== DISCONNECT ==================
  Future<void> disconnect() async {
    print("🔌 Disconnect called");

    // وقّفي كل شيء أولاً
    _stopFastLoop();
    _stopHeartbeat();
   // _stopIdleWatchdog();

    // افصلي callbacks حتى ما يعيد تشغيل الإرسال بعد المسح
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
  }}