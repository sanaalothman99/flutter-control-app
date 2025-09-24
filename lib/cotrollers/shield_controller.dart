
import 'dart:async';
import 'package:flutter/foundation.dart';
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

  final List<ShieldData> shields = [];
  final Map<int?, ShieldData> shieldMap = {};

  String? connectionShieldName;
  String? lastRxHex;
  String? lastTxHex;
  VoidCallback? onUpdate;
  VoidCallback? onControlChanged;
  Timer? _clearTimer;
  Timer? _inactivityTimer;

  ShieldController({
    required this.currentShield,
    required this.selectionDistance,
    required this.groupSize,
    required this.selectionDirection,
    required this.onUpdate,
  });

  // ========= قيم الشيلد الرئيسي =========
  bool get isReversed => shields.isNotEmpty && shields[0].faceOrientation == 1;
  final Duration inactivityTimeout = const Duration(seconds: 30);
  final ValueNotifier<int> inactivitySecondsLeft = ValueNotifier(30);

  int? _deviceUnitFromName() {
    final name = connectionShieldName;
    if (name == null || name.isEmpty) return null;
    final m = RegExp(r'(\d{3})$').firstMatch(name);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  int get maxGroupSize =>
      shields.isNotEmpty && shields[0].moveRange != null
          ? shields[0].moveRange!
          : 15;

  int get maxUpSelection =>
      shields.isNotEmpty && shields[0].maxUpSelection != null
          ? shields[0].maxUpSelection!
          : 5;

  int get maxDownSelection =>
      shields.isNotEmpty && shields[0].maxDownSelection != null
          ? shields[0].maxDownSelection!
          : 5;

  int get selectionStart => currentShield + selectionDistance;

  // ====== مساعد لاتجاهات الرقم مع الانعكاس ======
  int _stepFor(Direction dir) {
    if (dir == Direction.right) return isReversed ? -1 : 1;
    if (dir == Direction.left) return isReversed ? 1 : -1;
    return 0;
  }

  int stepFor(Direction dir) => _stepFor(dir);

  // ✅ selectedShields
  List<int> get selectedShields {
    if (groupSize == 0 && selectionDistance == 0) {
      return [currentShield];
    }
    if (groupSize == 0 && selectionDistance != 0) {
      return [highlightedUnit];
    }
    if (groupSize > 0) {
      final step = _stepFor(selectionDirection);
      // رجّع selectionStart نفسه + بقية المجموعة
      return List.generate(groupSize + 1, (i) => selectionStart + step * i);
    }
    return [];
  }

  // ========= وظائف/فالف =========
  final List<int> valveFunctions = List<int>.filled(6, 0);
  int extraFunction = 0;

  bool get hasActiveValves =>
      valveFunctions.any((v) => v != 0) || (extraFunction != 0);

  int get selectionDistanceForMcu {
    /* if (selectionDistance == 0 && groupSize == 0) return 0;
    if (selectionDistance != 0 && groupSize == 0)
      return selectionDistance.abs();
    return (groupSize > 0) ? groupSize : 0;*/
    if (selectionDistance == 0 && groupSize == 0) return 0;
    if (selectionDistance != 0 && groupSize == 0) {
      // تحديد فردي
      return selectionDistance.abs();
    }
    if (groupSize > 0) {
      // مجموعة: distance ثابت = المسافة بين currentShield و selectionStart
      return (selectionStart - currentShield).abs();
    }
    return 0;
  }

  int get selectionSizeForMcu {
    if (groupSize == 0 && selectionDistance == 0) return 0;
    if (groupSize > 0) return groupSize;
    return 0;
  }

  int get startDirectionForMcu {
    final hasAny = (groupSize > 0) || (selectionDistance != 0);
    if (!hasAny) return 0x00;

    if (selectionDirection == Direction.right) return 0x0D;
    if (selectionDirection == Direction.left) return 0x0C;
    return 0x00;
  }

  // حدود حسب الانعكاس
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

    final step = _stepFor(selectionDirection);
    final firstAdded = start + step; // أول عنصر مُضاف
    final lastAdded = start + step * groupSize; // آخر عنصر مُضاف

    int a = firstAdded < lastAdded ? firstAdded : lastAdded;
    int b = firstAdded > lastAdded ? firstAdded : lastAdded;

    // خلي النطاق يشمل نقطة البداية أيضاً
    if (start < a) a = start;
    if (start > b) b = start;

    return (minIdx: a, maxIdx: b);
  }

  bool _withinAllowed({required int minIdx, required int maxIdx}) {
    final b = allowedBounds;
    if (minIdx < b.minAllowed) return false;
    if (maxIdx > b.maxAllowed) return false;
    if (minIdx < 0) return false;
    return true;
  }

  void _ensurePlaceholdersForRange(int minUnit, int maxUnit) {
    int start = minUnit;
    int end = maxUnit;

    final b = allowedBounds;
    if (start < b.minAllowed) start = b.minAllowed;
    if (end > b.maxAllowed) end = b.maxAllowed;

    for (int u = start; u <= end; u++) {
      if (!shieldMap.containsKey(u)) {
        final placeholder = ShieldData.empty(unitNumber: u);
        shieldMap[u] = placeholder;
        if (u < 0) continue;
        if (u < shields.length) {
          shields[u] = placeholder;
        } else {
          while (shields.length < u) {
            shields.add(ShieldData.empty(unitNumber: shields.length));
          }
          shields.add(placeholder);
        }
      } else {
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

  void _selectCurrentIfNone() {
    final hasAny = valveFunctions.any((v) => v != 0) || (extraFunction != 0);
    if (hasAny && (groupSize == 0 && selectionDistance == 0)) {
      selectionDistance = 0;
      groupSize = 0;
      selectionDirection = Direction.none;
    }
  }

  ShieldData getOrCreateUnit(int unit) {
    _ensurePlaceholdersForRange(unit, unit);
    return shieldMap[unit]!;
  }

  ShieldData? tryGetUnit(int unit) {
    final byKey = shieldMap[unit];
    if (byKey != null) return byKey;

    // إذا المفتاح مجرد index
    if (unit >= 0 && unit < shields.length) {
      return shields[unit];
    }

    return null;
  }

  ShieldData shieldsSafe(int index) {
    if (index < 0) return ShieldData.empty(unitNumber: 0);
    if (index >= shields.length) {
      _ensurePlaceholdersForRange(index, index);
    }
    return shields[index];
  }

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

  void resetInactivityTimer(VoidCallback onTimeout) {
    _inactivityTimer?.cancel();
    inactivitySecondsLeft.value = inactivityTimeout.inSeconds;

    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      inactivitySecondsLeft.value--;

      if (inactivitySecondsLeft.value <= 0) {
        t.cancel();
        onTimeout();
      }
    });
  }

  void cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    inactivitySecondsLeft.value = inactivityTimeout.inSeconds;
  }

  void userInteracted(VoidCallback onTimeout) {
    resetInactivityTimer(onTimeout);
  }

// ===== تحكم الاختيارات =====
  void selectRight(int ignored) {
    userInteracted(() {
      // إذا مرّت 30 ثانية بلا أي تفاعل، رجعي المستخدم لصفحة ConnectionScreen
    });
    _touch();


    if (groupSize > 0) {
      // 🔹 نقل المجموعة كلها خطوة يمين
      final range = _currentRange();
      final step = _stepFor(Direction.right);
      final newMin = range.minIdx + step;
      final newMax = range.maxIdx + step;

      // ✅ مسموح خمس خطوات كحد أقصى
      final maxShift = 5;
      final shiftFromCenter = (selectionDistance + step).abs();
      if (shiftFromCenter > maxShift) return;

      if (_withinAllowed(minIdx: newMin, maxIdx: newMax)) {
        selectionDistance += step;
        _ensurePlaceholdersForRange(newMin, newMax);
        onUpdate?.call();
        onControlChanged?.call();
      }
      return;
    }

    // 🔹 تحديد فردي لليمين
    final step = _stepFor(Direction.right);
    final desired = selectionDistance + step;
    final target = currentShield + desired;

    final maxShift = 5;
    if (desired.abs() > maxShift) return;

    if (_withinAllowed(minIdx: target, maxIdx: target)) {
      selectionDirection = Direction.right;
      selectionDistance = desired;
      _ensurePlaceholdersForRange(target, target);
      onUpdate?.call();
      onControlChanged?.call();
    }
  }

// ===== التحديد يسار فردي أو نقل مجموعة يسار =====
  void selectLeft() {
    userInteracted(() {
      // إذا مرّت 30 ثانية بلا أي تفاعل، رجعي المستخدم لصفحة ConnectionScreen
    });
    _touch();

    if (groupSize > 0) {
      final range = _currentRange();
      final step = _stepFor(Direction.left);
      final newMin = range.minIdx + step;
      final newMax = range.maxIdx + step;

      final maxShift = 5;
      final shiftFromCenter = (selectionDistance + step).abs();
      if (shiftFromCenter > maxShift) return;

      if (_withinAllowed(minIdx: newMin, maxIdx: newMax)) {
        selectionDistance += step;
        _ensurePlaceholdersForRange(newMin, newMax);
        onUpdate?.call();
        onControlChanged?.call();
      }
      return;
    }

    final step = _stepFor(Direction.left);
    final desired = selectionDistance + step;
    final target = currentShield + desired;

    final maxShift = 5;
    if (desired.abs() > maxShift) return;

    if (_withinAllowed(minIdx: target, maxIdx: target)) {
      selectionDirection = Direction.left;
      selectionDistance = desired;
      _ensurePlaceholdersForRange(target, target);
      onUpdate?.call();
      onControlChanged?.call();
    }
  }

// ===== تشكيل/توسيع مجموعة يمين =====
  void groupRight(int ignored, Function(int newTotal) onNewTotal) {
    userInteracted(() {
      // إذا مرّت 30 ثانية بلا أي تفاعل، رجعي المستخدم لصفحة ConnectionScreen
    });
    _touch();
    final step = _stepFor(Direction.right);
    final start = selectionStart;

    // 🟢 حدد الحد الأقصى (إما moveRange أو 15)
    final maxRange = shields.isNotEmpty
        ? ((shields[0].moveRange != null && shields[0].moveRange != 0)
        ? shields[0].moveRange!
        : 15)
        : 15;

    // أول مرة (تشكيل مجموعة)
    if (groupSize == 0) {
      if (maxRange <= 0) return; // إذا أصلاً ما مسموح

      selectionDirection = Direction.right;
      final firstNew = start + step;

      if (!_withinAllowed(minIdx: start, maxIdx: firstNew)) return;

      groupSize = 1;
      _ensurePlaceholdersForRange(
        (start < firstNew ? start : firstNew),
        (start > firstNew ? start : firstNew),
      );
      onNewTotal(allowedBounds.maxAllowed + 1);
      onUpdate?.call();
      onControlChanged?.call();
      return;
    }

    if (selectionDirection != Direction.right) return;

    // 🟢 منع التوسيع إذا وصلنا للحد
    if (groupSize >= maxRange) return;

    // توسعة
    final nextEdge = start + step * (groupSize + 1);
    final r = _currentRange();
    final newMin = (nextEdge < r.minIdx) ? nextEdge : r.minIdx;
    final newMax = (nextEdge > r.maxIdx) ? nextEdge : r.maxIdx;

    if (_withinAllowed(minIdx: newMin, maxIdx: newMax)) {
      groupSize++;
      _ensurePlaceholdersForRange(newMin, newMax);
      onNewTotal(allowedBounds.maxAllowed + 1);
      onUpdate?.call();
      onControlChanged?.call();
    }
  }

// ===== تشكيل/توسيع مجموعة يسار =====
  void groupLeft(Function(int newTotal, int shift) onNewTotal) {
    userInteracted(() {
      // إذا مرّت 30 ثانية بلا أي تفاعل، رجعي المستخدم لصفحة ConnectionScreen
    });
    _touch();
    final step = _stepFor(Direction.left);
    final start = selectionStart;

    // 🟢 حدد الحد الأقصى (إما moveRange أو 15)
    final maxRange = shields.isNotEmpty
        ? ((shields[0].moveRange != null && shields[0].moveRange != 0)
        ? shields[0].moveRange!
        : 15)
        : 15;

    if (groupSize == 0) {
      if (maxRange <= 0) return;

      selectionDirection = Direction.left;
      final firstNew = start + step;

      if (!_withinAllowed(minIdx: firstNew, maxIdx: start)) return;

      groupSize = 1;
      _ensurePlaceholdersForRange(
        (firstNew < start ? firstNew : start),
        (firstNew > start ? firstNew : start),
      );
      onNewTotal(allowedBounds.maxAllowed + 1, 0);
      onUpdate?.call();
      onControlChanged?.call();
      return;
    }

    if (selectionDirection != Direction.left) return;

    if (groupSize >= maxRange) return;

    final nextEdge = start + step * (groupSize + 1);
    final r = _currentRange();
    final newMin = (nextEdge < r.minIdx) ? nextEdge : r.minIdx;
    final newMax = (nextEdge > r.maxIdx) ? nextEdge : r.maxIdx;

    if (_withinAllowed(minIdx: newMin, maxIdx: newMax)) {
      groupSize++;
      _ensurePlaceholdersForRange(newMin, newMax);
      onNewTotal(allowedBounds.maxAllowed + 1, 0);
      onUpdate?.call();
      onControlChanged?.call();
    }
  }

/*void removeFromRight() {
    userInteracted(() {
      // إذا مرّت 30 ثانية بلا أي تفاعل، رجعي المستخدم لصفحة ConnectionScreen
    });
    _touch();
    if (groupSize <= 1) return; // ما منسمح يصير صفر

    if (selectionDirection == Direction.right) {
      // احذف من نهاية اليمين
      groupSize--;
    } else if (selectionDirection == Direction.left) {
      // احذف من البداية (يعني نحرك start خطوة)
      selectionDistance += _stepFor(Direction.right);
      groupSize--;
    }

    onUpdate?.call();
    onControlChanged?.call();
  }

  void removeFromLeft() {
   userInteracted(() {
      // إذا مرّت 30 ثانية بلا أي تفاعل، رجعي المستخدم لصفحة ConnectionScreen
    });
    _touch();
    if (groupSize <= 1) return;

    if (selectionDirection == Direction.left) {
      // احذف من نهاية اليسار
      groupSize--;
    } else if (selectionDirection == Direction.right) {
      // احذف من البداية (يعني نحرك start خطوة)
      selectionDistance += _stepFor(Direction.right);
      groupSize--;
    }

    onUpdate?.call();
    onControlChanged?.call();
  }*/
  void removeFromRight() {
    _touch();

    // ✅ إذا المجموعة = 1 (فعلياً عنصرين: الرئيسي + 1) → خفّضها للصفر
    if (groupSize == 1) {
      groupSize = 0;
      onUpdate?.call();
      onControlChanged?.call();
      return;
    }

    if (groupSize > 1) {
      if (selectionDirection == Direction.right) {
        groupSize--;
      } else if (selectionDirection == Direction.left) {
        selectionDistance += _stepFor(Direction.left);
        groupSize--;
      }
      onUpdate?.call();
      onControlChanged?.call();
    }
  }

  void removeFromLeft() {
    _touch();

    if (groupSize == 1) {
      groupSize = 0;
      onUpdate?.call();
      onControlChanged?.call();
      return;
    }

    if (groupSize > 1) {
      if (selectionDirection == Direction.left) {
        groupSize--;
      } else if (selectionDirection == Direction.right) {
        selectionDistance += _stepFor(Direction.right);
        groupSize--;
      }
      onUpdate?.call();
      onControlChanged?.call();
    }
}

  void updateShieldData(int index, ShieldData newData) {
   /* if (index < 0) return;
    if (index < shields.length) {
      shields[index] = newData;
    } else if (index == shields.length) {
      shields.add(newData);
    }
    // ✅ تمييز بين الرئيسي والإضافي
    final key = (index == 0) ? 0 : newData.unitNumber ?? index;
    shieldMap[key] = newData;
    onUpdate?.call();*/
   /* if (index < 0) return;

    // 🟢 إذا الشيلد رئيسي وما عندو unitNumber → جيب الرقم من اسم الجهاز
    if (index == 0 && newData.unitNumber == null) {
      final guessed = _deviceUnitFromName();
      if (guessed != null) {
        newData = ShieldData(
          unitNumber: guessed,
          pressure1: newData.pressure1,
          pressure2: newData.pressure2,
          ramStroke: newData.ramStroke,
          sensor4: newData.sensor4,
          sensor5: newData.sensor5,
          sensor6: newData.sensor6,
          faceOrientation: newData.faceOrientation,
          maxDownSelection: newData.maxDownSelection,
          maxUpSelection: newData.maxUpSelection,
          moveRange: newData.moveRange,
        );
        currentShield = guessed; // ✅ هي الأهم: خلي currentShield = unitNumber
      }
    }

    final key = newData.unitNumber ?? index;
    shieldMap[key] = newData;

    onUpdate?.call();*/
     if (index < 0) return;

    // 1) حافظ على لستة shields (لا تلمسها)
    if (index < shields.length) {
      shields[index] = newData;
    } else if (index == shields.length) {
      shields.add(newData);
    } else {
      // إن صار قفزة غير متوقعة، كبّري اللستة بمكانات فاضية لحد index
      while (shields.length < index) {
        shields.add(ShieldData.empty(unitNumber: shields.length));
      }
      shields.add(newData);
    }

    // 2) إن كان الشيلد الرئيسي وما عنده unitNumber → استخرجو من اسم الجهاز
    int? unitNum = newData.unitNumber;
    if (index == 0 && (unitNum == null || unitNum == 0)) {
      final guessed = _deviceUnitFromName();
      if (guessed != null) {
        // بنينا نسخة جديدة بنفس القيم لكن مع unitNumber
        newData = ShieldData(
          unitNumber: guessed,
          pressure1: newData.pressure1,
          pressure2: newData.pressure2,
          ramStroke: newData.ramStroke,
          sensor4: newData.sensor4,
          sensor5: newData.sensor5,
          sensor6: newData.sensor6,
          faceOrientation: newData.faceOrientation,
          maxDownSelection: newData.maxDownSelection,
          maxUpSelection: newData.maxUpSelection,
          moveRange: newData.moveRange,
        );
        unitNum = guessed;

        // خليه هو currentShield بوحدة حقيقية (مهم للسنترة بالرسم)
        currentShield = guessed;
      }
    }

    // 3) خزّن بالماب على المفتاحين:
    //    - على index دائمًا
    shieldMap[index] = newData;
    //    - وعلى unitNum إذا موجود
    if (unitNum != null) {
      shieldMap[unitNum] = newData;
    }

    onUpdate?.call();

  }

  int get highlightedUnit => currentShield + selectionDistance;

  ({int min, int max}) get groupRange {
    if (groupSize == 0 && selectionDistance == 0) {
      return (min: currentShield, max: currentShield);
    }
    if (groupSize == 0 && selectionDistance != 0) {
      return (min: highlightedUnit, max: highlightedUnit);
    }
    final start = selectionStart;
    final step = _stepFor(selectionDirection);
    final last = start + step * groupSize;
    final minV = start < last ? start : last;
    final maxV = start > last ? start : last;
    return (min: minV, max: maxV);
  }
  List<int> getVisibleUnits({int desiredCount = 11}) {
    final b = allowedBounds;
    final minAllowed = b.minAllowed;
    final maxAllowed = b.maxAllowed;

    final totalSpan =
    (maxAllowed >= minAllowed) ? (maxAllowed - minAllowed + 1) : 0;
    if (totalSpan <= 0) return const [];

    final win = totalSpan < desiredCount ? totalSpan : desiredCount;

    int start = currentShield - (win ~/ 2);
    if (start < minAllowed) start = minAllowed;
    if (start + win - 1 > maxAllowed) start = maxAllowed - win + 1;

    final base = List<int>.generate(win, (i) => start + i);

    // يضل بهالشكل، اتجاه العرض بيتحكم فيه Row.textDirection
    return base;
  }

  // ====== دوال الفالف ======
  int findSlotByCode(int code) {
    for (int i = 0; i < valveFunctions.length; i++) {
      if (valveFunctions[i] == (code & 0xFFFF)) return i;
    }
    return -1;
  }

  int firstFreeSlot() {
    for (int i = 0; i < valveFunctions.length; i++) {
      if (valveFunctions[i] == 0) return i;
    }
    return -1;
  }
  void setValveFunction(int slot, int code) {
   userInteracted(() {
      // إذا مرّت 30 ثانية بلا أي تفاعل، رجعي المستخدم لصفحة ConnectionScreen
    });
    if (slot < 0 || slot >= 6) return;
    valveFunctions[slot] = code & 0xFFFF;
    _selectCurrentIfNone();
    onUpdate?.call();
    onControlChanged?.call();
  }

  void clearValveSlot(int slot) {
    userInteracted(() {
      // إذا مرّت 30 ثانية بلا أي تفاعل، رجعي المستخدم لصفحة ConnectionScreen
    });
    if (slot < 0 || slot >= 6) return;
    valveFunctions[slot] = 0;
    onUpdate?.call();
    onControlChanged?.call();
  }

  void clearValveFunctions() {
    userInteracted(() {
      // إذا مرّت 30 ثانية بلا أي تفاعل، رجعي المستخدم لصفحة ConnectionScreen
    });
    for (int i = 0; i < valveFunctions.length; i++) {
      valveFunctions[i] = 0;
    }
    onUpdate?.call();
    onControlChanged?.call();
  }

  void setExtraFunction(int code) {
    userInteracted(() {
      // إذا مرّت 30 ثانية بلا أي تفاعل، رجعي المستخدم لصفحة ConnectionScreen
    });
    extraFunction = code & 0xFF;
    _selectCurrentIfNone();
    onUpdate?.call();
    onControlChanged?.call();
  }

  // ====== بايلود ======
  Uint8List buildControlPayload(int counter) {
    final p = Uint8List(20);
    p[0] = 0;
    p[1] = 0;
    p[2] = (selectionSizeForMcu & 0xFF);
    p[3] = (selectionDistanceForMcu & 0xFF);
    p[4] = (startDirectionForMcu & 0xFF);
    p[5] = 0xFF;
    for (int i = 0; i < 6; i++) {
      final v = (i < valveFunctions.length) ? valveFunctions[i] : 0;
      p[6 + i * 2] = (v & 0xFF);
      p[7 + i * 2] = ((v >> 8) & 0xFF);
    }
    p[17] = (extraFunction & 0xFF);
    p[18] = 0;
    p[19] = (counter & 0xFF);
    return p;
  }

  void reset() {
    _clearTimer?.cancel();
    selectionDistance = 0;
    groupSize = 0;
    selectionDirection = Direction.none;
    onUpdate?.call();
    onControlChanged?.call();
  }

  void clearData() {
    shields.clear();
    shieldMap.clear();
    connectionShieldName = null;
    reset();
  }
  void dispose(){
    _clearTimer?.cancel();
   _inactivityTimer?.cancel();
  }

  // ✅ دمي داتا للتجريب
  void initDummyDataForTest() {
    for (int i = 0; i < 50; i++) {
      updateShieldData(
        i,
        ShieldData(
          unitNumber: i,
          pressure1: 100 + i,
          pressure2: 150 + i,
          ramStroke: 300 + i,
          sensor4: 0,
          sensor5: 0,
          sensor6: 0,
          faceOrientation:0, // جرّب 0 و 1
          maxDownSelection: 15,
          maxUpSelection: 15,
          moveRange: 15,
        ),
      );
    }
  }
}