import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../cotrollers/shield_controller.dart';
import '../models/shield_data.dart';

class BluetoothService {
  final ShieldController shieldController;
  final String deviceName;
  final void Function(List<int>) onDataReceived;

  BluetoothDevice? _device;

  // RX (notify) — مستشعرات
  static final Guid serviceUUID        = Guid("0000fe50-cc7a-482a-984a-7f2ed5b3e58f");
  static final Guid characteristicUUID = Guid("0000fe52-8e22-4541-9d4c-21edea82ed19");

  // TX (control write) — أوامر التحكم (fe70 service)
  static final Guid controlServiceUUID = Guid("0000fe70-cc7a-482a-984a-7f2ed5b3e58f");
  static final List<Guid> controlCharUUIDs = [
    Guid("0000fe72-8e22-4541-9d4c-21edea82ed19"), // WRITE (مفضّل إن توفّر)
    Guid("0000fe71-8e22-4541-9d4c-21edea82ed19"), // WRITE NO RESPONSE
    Guid("0000fe73-8e22-4541-9d4c-21edea82ed19"), // WRITE NO RESPONSE
  ];

  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription<List<int>>? _subscription;

  // عدّاد التلغرام للأوامر
  int _txCounter = 0;

  // جدولة الإرسال
  Timer? _fastTxTimer;   // 200ms أثناء وجود وظائف فعّالة
  Timer? _txTimer;       // 20 ثانية هارتبيت
  DateTime _lastUserActivity=DateTime.now();
  Timer? _idleWatchdog;
  static const Duration _idleTimeout =Duration(seconds: 30);
  void _bumpActivity(){
    _lastUserActivity=DateTime.now();
  }
  void _startIdleWatchdog(){
    _idleWatchdog?.cancel();
    _idleWatchdog=Timer.periodic(const Duration(seconds: 1), (_) async{
      final idleFor=DateTime.now().difference(_lastUserActivity);
      //donot cut the connection when is valv buttons activ
      final hasActive=shieldController.valveFunctions.any((v)=> v!=0)||(shieldController.extraFunction!=0);
      if(!hasActive && idleFor >= _idleTimeout){
        try{await disconnect();} catch(_){}
      }
    });
  }
  void _stopIdleWatchdog(){
    _idleWatchdog?.cancel();
    _idleWatchdog=null;
  }

  BluetoothService({
    required this.shieldController,
    required this.deviceName,
    required this.onDataReceived,
  });

  // اتصال + اكتشاف خدمات/خصائص
  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    await _device!.connect();

    shieldController.connectionShieldName = deviceName;

    final services = await _device!.discoverServices();
    for (final s in services) {
      // إشعارات الحساسات (RX)
      if (s.uuid == serviceUUID) {
        for (final c in s.characteristics) {
          if (c.uuid == characteristicUUID && c.properties.notify) {
            _rxCharacteristic = c;
            await c.setNotifyValue(true);
            _subscription = c.value.listen((data) {
              onDataReceived(data);
              _onDataReceived(data);
            });
          }
        }
      }

      // أوامر التحكم (TX)
      if (s.uuid == controlServiceUUID) {
        for (final c in s.characteristics) {
          if (controlCharUUIDs.contains(c.uuid) &&
              (c.properties.write || c.properties.writeWithoutResponse)) {
            _txCharacteristic ??= c; // أول واحدة مناسبة نلقاها
          }
        }
      }
    }

    // وصّلي تغيّر التحكم بالمرسِل
    shieldController.onControlChanged = _onControlChanged;

    // ابدأي بهارتبيت مبدئي (بدون أوامر)
    _startHeartbeat();

    // إرسال أولي
    await sendControlNow();
    //
    _bumpActivity();
    _startIdleWatchdog();
  }

  // يُستدعى كل ما تغيّر شيء في التحكم (أسهم/مجموعة/فالف/إكسترا)
  void _onControlChanged() {
    _bumpActivity();
    // إرسال فوري على كل تغيير
    sendControlNow();

    final hasActive = shieldController.valveFunctions.any((v) => v != 0) ||
        (shieldController.extraFunction != 0);

    if (hasActive) {
      // أوامر فعّالة → 200ms loop
      _startFastLoop();
      _stopHeartbeat();
    } else {
      // لا أوامر فعّالة → ارجعي للهارتبيت 20 ثانية
      _stopFastLoop();
      _startHeartbeat();
    }
  }

  // إرسال فوري لحالة التحكم الحالية
  Future<void> sendControlNow() async {
    if (_txCharacteristic == null) return;

    final Uint8List payload = shieldController.buildControlPayload(_txCounter++);
    final bool canNoRsp = _txCharacteristic!.properties.writeWithoutResponse;

    try {
      await _txCharacteristic!.write(
        payload,
        withoutResponse: canNoRsp, // إن متاحة، نستخدم بدون رد
      );
    } catch (_) {
      // احتياطي: جرّبي بطريقة أخرى إذا حصل خطأ
      try {
        await _txCharacteristic!.write(payload, withoutResponse: false);
      } catch (_) {}
    }
  }

  // 200ms أثناء الضغط/الأوامر الفعّالة
  void _startFastLoop() {
    if (_fastTxTimer != null) return;
    _fastTxTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      sendControlNow();
    });
  }

  void _stopFastLoop() {
    _fastTxTimer?.cancel();
    _fastTxTimer = null;
  }

  // 20 ثانية هارتبيت عند الخمول
  void _startHeartbeat() {
    _txTimer?.cancel();
    _txTimer = Timer.periodic(const Duration(seconds: 20), (_) => sendControlNow());
  }

  void _stopHeartbeat() {
    _txTimer?.cancel();
    _txTimer = null;
  }

  // تحليل بيانات RX: الرئيسي 19 بايت + كل إضافي 8 بايت
  void _onDataReceived(List<int> data) {
    if (data.length < 19) return;

    // الشيلد الرئيسي: index = 0 (أول 19 بايت)
    final main = ShieldData.fromBytes(data, 0);
    shieldController.updateShieldData(0, main);

    // شيلدات إضافية: كل 8 بايت بعد ذلك
    const addSize = 8;
    int offset = 19;
    int index = 1;
    while (offset + addSize <= data.length) {
      final s = ShieldData.fromBytes(data, offset);
      shieldController.updateShieldData(index, s);
      offset += addSize;
      index++;
    }

    // تحديث الواجهة
    shieldController.onUpdate?.call();
  }

  Future<void> disconnect() async {
    _stopFastLoop();
    _stopHeartbeat();
    _stopIdleWatchdog();

    await _subscription?.cancel();
    _subscription = null;

    try {
      await _device?.disconnect();
    } catch (_) {}

    _device = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
  }}