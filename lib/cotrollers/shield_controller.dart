import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/shield_data.dart';

enum Direction { none, left, right }

class _Limits {
  final int left, right;
  const _Limits(this.left, this.right);
}

class ShieldController {
  int currentShield;
  int selectionDistance;
  int groupSize;
  Direction selectionDirection;

  // == التخزين الأصلي ==
  final List<ShieldData> shields = [];

  // == تخزين إضافي حسب unitNumber (للرسم حتى لو ما وصلت الداتا) ==
  final Map<int?, ShieldData> shieldMap = {};

  String? connectionShieldName;

  VoidCallback? onUpdate;
  VoidCallback? onControlChanged;
  Timer? _clearTimer;

  ShieldController({
    required this.currentShield,
    required this.selectionDistance,
    required this.groupSize,
    required this.selectionDirection,
    required this.onUpdate,
  });

  // == قيم الشيلد الرئيسي ==
  bool get isReversed => shields.isNotEmpty && shields[0].faceOrientation == 1;

  int get maxGroupSize =>
      shields.isNotEmpty && shields[0].moveRange != null
          ? shields[0].moveRange!
          : 15;

  int get maxUpSelection =>
      shields.isNotEmpty && shields[0].maxUpSelection != null ? shields[0]
          .maxUpSelection! : 5;

  int get maxDownSelection =>
      shields.isNotEmpty && shields[0].maxDownSelection != null ? shields[0]
          .maxDownSelection! : 5;

  int get selectionStart => currentShield + selectionDistance;

  List<int> get selectedShields {
    if (groupSize == 0) return [];
    return List.generate(groupSize, (i) {
      return selectionDirection == Direction.right
          ? selectionStart + i
          : selectionStart - i;
    });
  }

  // == وظائف/فالف ==
  final List<int> valveFunctions = List<int>.filled(6, 0); // 6 خانات 16-بت
  int extraFunction = 0;

  bool get hasActiveValves =>
      valveFunctions.any((v) => v != 0) || (extraFunction != 0);

  int get selectionDistanceForMcu =>
      isReversed ? -selectionDistance : selectionDistance;

  int get selectionSizeForMcu {
    final hasAny = (groupSize > 0) || (selectionDistance != 0);
    if (!hasAny) return 0;
    return (groupSize > 0) ? groupSize : 1;
  }

  int get startDirectionForMcu {
    final hasAny = (groupSize > 0) || (selectionDistance != 0);
    if (!hasAny) return 0;
    final Direction physRight = isReversed ? Direction.left : Direction.right;
    if (selectionDirection == physRight) return 1;
    if (selectionDirection ==
        (physRight == Direction.right ? Direction.left : Direction.right)) {
      return 2;
    }
    return 0;
  }

  // == حدود حسب الانعكاس ==
  _Limits _limits() {
    final l = isReversed ? maxUpSelection : maxDownSelection;
    final r = isReversed ? maxDownSelection : maxUpSelection;
    return _Limits(l, r);
  }

  ({int minAllowed, int maxAllowed}) get allowedBounds {
    final lim = _limits();
    final minA = currentShield - lim.left;
    final maxA = currentShield + lim.right;
    return (minAllowed: (minA < 0 ? 0 : minA), maxAllowed: maxA);
  }

  ({int minIdx, int maxIdx}) _currentRange() {
    final start = selectionStart;
    if (groupSize <= 0) return (minIdx: start, maxIdx: start);
    if (selectionDirection == Direction.right) {
      return (minIdx: start, maxIdx: start + groupSize - 1);
    } else {
      return (minIdx: start - (groupSize - 1), maxIdx: start);
    }
  }

  bool _withinAllowed({required int minIdx, required int maxIdx}) {
    final b = allowedBounds;
    if (minIdx < b.minAllowed) return false;
    if (maxIdx > b.maxAllowed) return false;
    if (minIdx < 0) return false;
    return true;
  }

  // يولّد Placeholders لأي وحدات مطلوبة للرسم ولم تصل بياناتها بعد
  void _ensurePlaceholdersForRange(int minUnit, int maxUnit) {
    // لو ما عندك حدود مفعّلة، اشتغلي بالنطاق المطلوب كما هو
    int start = minUnit;
    int end   = maxUnit;

    // إن كان عندك allowedBounds جاهز، فيك تعملي قصّ ضمن الحدود:
    final b = allowedBounds;
    if (start < b.minAllowed) start = b.minAllowed;
    if (end   > b.maxAllowed) end   = b.maxAllowed;

    for (int u = start; u <= end; u++) {
      if (!shieldMap.containsKey(u)) {
        final placeholder = ShieldData.empty(unitNumber: u);
        shieldMap[u] = placeholder;

        // ضمّني ال-placeholder بليست shields بحيث الفهرس يطابق رقم الوحدة
        if (u < 0) continue;
        if (u < shields.length) {
          shields[u] = placeholder;
        } else {
          // كبّري اللست حتى توصلي للفهرس u ثم أضيفي
          while (shields.length < u) {
            shields.add(ShieldData.empty(unitNumber: shields.length));
          }
          shields.add(placeholder);
        }
      } else {
        // تأكدي أن قائمة shields فيها عنصر عند الفهرس u
        if (u >= shields.length) {
          while (shields.length < u) {
            shields.add(ShieldData.empty(unitNumber: shields.length));
          }
          shields.add(shieldMap[u]!);
        } else {
          shields[u] = shieldMap[u]!;
        }
      }
    }
  }

  /// بيرجع بيانات شيلد جاهزة للعرض.
  /// إذا ما كانت موجودة، بيولّد Placeholder ويرجعها (ما بيخلّي الـ UI ينهار).
  ShieldData getOrCreateUnit(int unit) {
    _ensurePlaceholdersForRange(unit, unit);
    return shieldMap[unit]!;
  }

  /// بيرجع البيانات فقط إذا موجودة (بدون توليد جديد).
  ShieldData? tryGetUnit(int unit) => shieldMap[unit];

  /// وصول آمن للعناصر عند الرسم بالـ index
  ShieldData shieldsSafe(int index) {
    if (index < 0) return ShieldData.empty(unitNumber: 0);
    if (index >= shields.length) {
      _ensurePlaceholdersForRange(index, index);
    }
    return shields[index];
  }

  // == مؤقت إلغاء التحديد ==
  void _armIdleTimer() {
    _clearTimer?.cancel();
    if (hasActiveValves) return;
    _clearTimer = Timer(const Duration(seconds: 10), () {
      if (hasActiveValves) return;
      selectionDistance = 0;
      groupSize = 0;
      selectionDirection = Direction.none;
      onUpdate?.call();
      onControlChanged?.call();
    });
  }

  void _touch() => _armIdleTimer();

  // == اختيار يمين ==
  void selectRight(int ignoredTotalShields) {
    _touch();
    final lim = _limits();

    // حد خاص للتحديد الفردي: 5 فقط كحد أقصى
    const singleCap = 5;

    // تحريك مجموعة كاملة لليمين خطوة واحدة
    if (groupSize > 0) {
      final range = _currentRange();
      final newMin = range.minIdx + 1;
      final newMax = range.maxIdx + 1;
      if (_withinAllowed(minIdx: newMin, maxIdx: newMax)) {
        selectionDistance++;
        _ensurePlaceholdersForRange(newMin, newMax);
        onUpdate?.call();
        onControlChanged?.call();
      }
      return;
    }

    // تحديد فردي يمين ضمن min(حدود النظام، 5)
    if (selectionDirection == Direction.none ||
        selectionDirection == Direction.right) {
      final maxRight = lim.right < singleCap ? lim.right : singleCap;
      final desired = selectionDistance + 1;
      final clamped = desired > maxRight ? maxRight : desired;
      final target = currentShield + clamped;
      if (_withinAllowed(minIdx: target, maxIdx: target)) {
        selectionDirection = Direction.right;
        selectionDistance = clamped;
        _ensurePlaceholdersForRange(target, target);
        onUpdate?.call();
        onControlChanged?.call();
      }
    }
  }

// == اختيار يسار ==
  void selectLeft() {
    _touch();
    final lim = _limits();

    const singleCap = 5;

    // تحريك مجموعة كاملة لليسار خطوة واحدة
    if (groupSize > 0) {
      final range = _currentRange();
      final newMin = range.minIdx - 1;
      final newMax = range.maxIdx - 1;
      if (_withinAllowed(minIdx: newMin, maxIdx: newMax)) {
        selectionDistance--;
        _ensurePlaceholdersForRange(newMin, newMax);
        onUpdate?.call();
        onControlChanged?.call();
      }
      return;
    }

    // تحديد فردي يسار ضمن min(حدود النظام، 5)
    if (selectionDirection == Direction.none ||
        selectionDirection == Direction.left) {
      final maxLeft = lim.left < singleCap ? lim.left : singleCap;
      final desired = selectionDistance - 1;
      final clamped = desired < -maxLeft ? -maxLeft : desired;
      final target = currentShield + clamped;
      if (_withinAllowed(minIdx: target, maxIdx: target)) {
        selectionDirection = Direction.left;
        selectionDistance = clamped;
        _ensurePlaceholdersForRange(target, target);
        onUpdate?.call();
        onControlChanged?.call();
      }
    }
  }

  // == مجموعة يمين ==
  void groupRight(int ignoredTotalShields, Function(int newTotal) onNewTotal) {
    _touch();
    final lim = _limits();
    final maxSize = 1 + lim.right;
    final start = selectionStart;

    if (groupSize == 0) {
      if (maxSize < 2) return;
      if (!_withinAllowed(minIdx: start, maxIdx: start + 1)) return;
      selectionDirection = Direction.right;
      groupSize = 2;
      _ensurePlaceholdersForRange(start, start + 1);
      onNewTotal(allowedBounds.maxAllowed + 1);
      onUpdate?.call();
      onControlChanged?.call();
      return;
    }

    if (selectionDirection != Direction.right) return;
    if (groupSize >= maxSize) return;

    final newMax = selectionStart + groupSize;
    if (_withinAllowed(minIdx: selectionStart, maxIdx: newMax)) {
      groupSize++;
      _ensurePlaceholdersForRange(selectionStart, newMax);
      onNewTotal(allowedBounds.maxAllowed + 1);
      onUpdate?.call();
      onControlChanged?.call();
    }
  }

  // == مجموعة يسار ==
  void groupLeft(Function(int newTotal, int shift) onNewTotal) {
    _touch();
    final lim = _limits();
    final maxSize = 1 + lim.left;
    final start = selectionStart;

    if (groupSize == 0) {
      if (maxSize < 2) return;
      if (!_withinAllowed(minIdx: start - 1, maxIdx: start)) return;
      selectionDirection = Direction.left;
      groupSize = 2;
      _ensurePlaceholdersForRange(start - 1, start);
      onNewTotal(allowedBounds.maxAllowed + 1, 0);
      onUpdate?.call();
      onControlChanged?.call();
      return;
    }

    if (selectionDirection != Direction.left) return;
    if (groupSize >= maxSize) return;

    final newMin = selectionStart - groupSize;
    if (_withinAllowed(minIdx: newMin, maxIdx: selectionStart)) {
      groupSize++;
      _ensurePlaceholdersForRange(newMin, selectionStart);
      onNewTotal(allowedBounds.maxAllowed + 1, 0);
      onUpdate?.call();
      onControlChanged?.call();
    }
  }

  // == حذف من اليمين ==
  void removeFromRight() {
    _touch();
    if (groupSize <= 1) return;

    if (selectionDirection == Direction.right) {
      groupSize--;
    } else if (selectionDirection == Direction.left) {
      selectionDistance += isReversed ? 1 : -1;
      groupSize--;
    }
    onUpdate?.call();
    onControlChanged?.call();
  }

  // == حذف من اليسار ==
  void removeFromLeft() {
    _touch();
    if (groupSize <= 1) return;

    if (selectionDirection == Direction.left) {
      groupSize--;
    } else if (selectionDirection == Direction.right) {
      selectionDistance += isReversed ? -1 : 1;
      groupSize--;
    }
    onUpdate?.call();
    onControlChanged?.call();
  }

  // == تحديث بيانات الشيلد (من البلوتوث) ==
  void updateShieldData(int index, ShieldData newData) {
    if (index < 0) return;

    if (index < shields.length) {
      shields[index] = newData;
    } else if (index == shields.length) {
      shields.add(newData);
    } else {
      debugPrint("⚠️ Skipped update: Index $index too far (shields.len=${shields.length})");
      return;
    }

    // 🔧 استخدم index كمفتاح إذا unitNumber = null
    final key = newData.unitNumber ?? index;
    shieldMap[key] = newData;

    // (اختياري) طباعات تشخيص
  /*  print("🔄 updateShieldData[$index]");
    print("   unitNumber   = ${newData.unitNumber}");
    print("   pressure1    = ${newData.pressure1}");
    print("   pressure2    = ${newData.pressure2}");
    print("   ramStroke    = ${newData.ramStroke}");
    print("   shields.len  = ${shields.length}");
    print("   map.len      = ${shieldMap.length}");
    print("   map.keys     = ${shieldMap.keys.join(', ')}");*/

    onUpdate?.call();
  }

  // == أدوات للـ UI ==
  bool hasData(int unitNumber) => shieldMap.containsKey(unitNumber);

  ShieldData? dataFor(int unitNumber) => shieldMap[unitNumber];

  int get highlightedUnit => currentShield + selectionDistance;

  ({int min, int max}) get groupRange {
    if (groupSize <= 0) return (min: highlightedUnit, max: highlightedUnit);
    final start = selectionStart;
    final end = selectionDirection == Direction.right
        ? start + groupSize - 1
        : start - groupSize + 1;
    final mn = start < end ? start : end;
    final mx = start > end ? start : end;
    return (min: mn, max: mx);
  }

  /// لائحة الوحدات المعروضة (واجهة بتطلب 11 بشكل عام)
  List<int> getVisibleUnits({int desiredCount = 11}) {
    final b = allowedBounds;
    final minAllowed = b.minAllowed;
    final maxAllowed = b.maxAllowed;

    final totalSpan = (maxAllowed >= minAllowed)
        ? (maxAllowed - minAllowed + 1)
        : 0;
    if (totalSpan <= 0) return const [];

    final win = totalSpan < desiredCount ? totalSpan : desiredCount;

    int start = currentShield - (win ~/ 2);
    if (start < minAllowed) start = minAllowed;
    if (start + win - 1 > maxAllowed) start = maxAllowed - win + 1;

    final base = List<int>.generate(win, (i) => start + i);
    return isReversed ? base.reversed.toList() : base;
  }

  // == إدارة الفالف (كما هي) ==
  void setValveFunction(int slot, int code) {
    if (slot < 0 || slot >= 6) return;
    valveFunctions[slot] = code & 0xFFFF;
    print("🔘 setValveFunction(slot=$slot, code=0x${code.toRadixString(16)})");
    onUpdate?.call();
    onControlChanged?.call();  // هذا يستدعي sendControlNow داخل BluetoothService
    //_armIdleTimer();
  }

  void clearValveSlot(int slot) {
    if (slot < 0 || slot >= 6) return;
    valveFunctions[slot] = 0;
    print("🔘 clearValveSlot(slot=$slot)");
    onUpdate?.call();
    onControlChanged?.call();
    //_armIdleTimer();
  }

  void clearValveFunctions() {
    for (int i = 0; i < valveFunctions.length; i++) {
      valveFunctions[i] = 0;
    }
    onUpdate?.call();
    onControlChanged?.call();
    //_armIdleTimer();
  }

  void setExtraFunction(int code) {
    extraFunction = code & 0xFF;
    onUpdate?.call();
    onControlChanged?.call();
  //  _armIdleTimer();
  }

  // == بايلود التحكم 20 بايت ==
  Uint8List buildControlPayload(int counter) {
    final p = Uint8List(20);
    p[0] = 0;
    p[1] = 0;
    p[2] = selectionSizeForMcu & 0xFF;
    p[3] = (selectionDistanceForMcu & 0xFF);
    p[4] = startDirectionForMcu & 0xFF;

    for (int i = 0; i < 6; i++) {
      final v = (i < valveFunctions.length) ? valveFunctions[i] : 0;
      p[5 + i * 2] = (v & 0xFF);           // LSB
      p[6 + i * 2] = ((v >> 8) & 0xFF);    // MSB
    }

    // ✅ طباعة حقل الأزرار [5..16]
    final view = List<int>.generate(12, (k) => p[5 + k]);
    print('buttons[5..16] = ${view.map((b)=>b.toRadixString(16).padLeft(2,"0")).join(" ")}  '
        'activeSlots=${valveFunctions.where((v)=>v!=0).length}');

    p[17] = (extraFunction & 0xFF);
    p[18] = (counter & 0xFF);
    p[19] = 0;
    return p;

  }

  void generateShield(int index) {
    if (index < 0) return;
    // إذا الشيلد موجود مسبقاً ما نعيد إضافته
    if (index < shields.length) return;

    // نكمل إضافة عناصر فاضية حتى نوصل للـ index المطلوب
    while (shields.length <= index) {
      shields.add(ShieldData(
        unitNumber: shields.length,
        pressure1: 0,
        pressure2: 0,
        ramStroke: 0,
        faceOrientation: isReversed ? 1 : 0,
        maxUpSelection: 0,
        maxDownSelection: 0,
      ));
    }
  }

  // == Reset ==
  void reset() {
    _clearTimer?.cancel();
    selectionDistance = 0;
    groupSize = 0;
    selectionDirection = Direction.none;
    onUpdate?.call();
    onControlChanged?.call();
  }

  // يمسح كل الداتا والاختيارات ويحدّث الواجهة
  void clearData() {
    shields.clear();
    shieldMap.clear();
    connectionShieldName = null;

    // نرجع الحالة الافتراضية للاختيار
    selectionDistance = 0;
    groupSize = 0;
    selectionDirection = Direction.none;

    // بلّغي الواجهة
    onUpdate?.call();
    onControlChanged?.call();
  }

  // == بيانات وهمية للاختبار ==
  void initDummyData() {
    // عدّلي العدد اللي بدك ياه
    for (int i = 0; i < 20; i++) {
      updateShieldData(
        i,
        ShieldData(
          unitNumber: i,
          pressure1: 30 + i,
          pressure2: 50 + i,
          ramStroke: 60 + i,
          sensor4: 0,
          sensor5: 0,
          sensor6: 0,
          faceOrientation: 0,
          maxDownSelection: 2,
          maxUpSelection: 13,
          // مثال: 13 يمين
          moveRange: 30,
        ),
      );
    }
  }
}