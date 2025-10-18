import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import '../models/shield_data.dart';

enum Direction { none, left, right }

class _Limits {
  final int left, right;

  const _Limits(this.left, this.right);
}

class ShieldController {
  BuildContext? contextRef;
  int currentShield;
  int selectionDistance;
  int groupSize;
  Direction selectionDirection;
  int? startDirectionSign ;

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

  //int get selectionStart => currentShield + selectionDistance;
  int get selectionStart =>
      isReversed ? currentShield - selectionDistance
          : currentShield + selectionDistance;

      // ====== مساعد لاتجاهات الرقم مع الانعكاس ======
  int _stepFor(Direction dir) {
    if (dir == Direction.right) return isReversed ? -1 : 1;
    if (dir == Direction.left)  return isReversed ?  1 : -1;
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


 /*int get selectionDistanceForMcu {
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
  }*/
  int get selectionDistanceForMcu {
    // ما في تحديد إطلاقًا
    if (selectionDistance == 0 && groupSize == 0) return 0;

    // تحديد فردي فقط
    if (groupSize == 0 && selectionDistance != 0) {
      // موجبة أو سالبة حسب الاتجاه
      return (selectionDirection == Direction.left)
          ? -selectionDistance.abs()
          : selectionDistance.abs();
    }

    // مجموعة محددة
    if (groupSize > 0) {
      // المسافة بين الشيلد الرئيسي وبداية المجموعة (مع اتجاه)
      final dist = selectionStart - currentShield;
      return (selectionDirection == Direction.left)
          ? -dist.abs()
          : dist.abs();
    }

    return 0;
  }


  int get selectionSizeForMcu {
    // حجم المجموعة فقط (0 إن لم توجد)
    return (groupSize > 0) ? groupSize : 0;
  }


  int get startDirectionForMcu {
    final hasAny = (groupSize > 0) || (selectionDistance != 0);
    if (!hasAny) return 0x00;

    // 0x0D → يمين | 0x0C → يسار
    if (selectionDirection == Direction.right) return 0x0D;
    if (selectionDirection == Direction.left)  return 0x0C;
    return 0x00;
  }
// ===== حدود السماحية (تصحيح بسيط للانعكاس) =====
  _Limits _limits() {
    if (isReversed) {
      // faceOrientation = 1 → الأرقام تصغر باتجاه اليمين
      return _Limits(
        maxUpSelection,   // يسار بصرياً
        maxDownSelection, // يمين بصرياً
      );
    } else {
      // faceOrientation = 0 → الأرقام تكبر باتجاه اليمين
      return _Limits(
        maxDownSelection, // يسار بصرياً
        maxUpSelection,   // يمين بصرياً
      );
    }
  }
  /*({int minAllowed, int maxAllowed}) get allowedBounds {
    final lim = _limits();
    final minA = currentShield - lim.left;
    final maxA = currentShield + lim.right;
    return (minAllowed: minA < 0 ? 0 : minA, maxAllowed: maxA);
  }*/
 /* ({int minAllowed, int maxAllowed}) get allowedBounds {
    final lim = _limits();

    // ✅ الاتجاه المعكوس: الأرقام الأصغر على اليمين → نقلّب المنطق
    if (isReversed) {
      final minA = currentShield - lim.right; // أقصى ما يمكن نزولاً بالأرقام
      final maxA = currentShield + lim.left;  // أقصى ما يمكن صعوداً بالأرقام
      return (minAllowed: (minA < 0 ? 0 : minA), maxAllowed: maxA);
    } else {
      // الاتجاه الطبيعي
      final minA = currentShield - lim.left;
      final maxA = currentShield + lim.right;
      return (minAllowed: (minA < 0 ? 0 : minA), maxAllowed: maxA);
    }
  }*/
  ({int minAllowed, int maxAllowed}) get allowedBounds {
    if (shields.isEmpty) {
      return (minAllowed: 0, maxAllowed: 0);
    }

    final int upLimit   = shields[0].maxUpSelection ?? 5;
    final int downLimit = shields[0].maxDownSelection ?? 5;
    final bool reversed = isReversed;

    int minA, maxA;

    if (reversed) {
      // faceOrientation = 1 → الأرقام تصغر يمينًا (يعني اليمين = أصغر)
      // اليسار بصريًا = أرقام أكبر
      minA = currentShield - downLimit; // أقصى يمين بصريًا (أرقام أصغر)
      maxA = currentShield + upLimit;   // أقصى يسار بصريًا (أرقام أكبر)
    } else {
      // faceOrientation = 0 → الأرقام تكبر يمينًا
      minA = currentShield - upLimit;   // أقصى يسار بصريًا (أرقام أصغر)
      maxA = currentShield + downLimit; // أقصى يمين بصريًا (أرقام أكبر)
    }

    // 🧠 لا نقصي صفر نهائيًا إلا إذا فعلاً الاتجاه بيولد قيم سالبة
    if (minA < 0) minA = 0;

    return (minAllowed: minA, maxAllowed: maxA);
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
    if (minIdx < 1) return false; // ما في Shield رقم 0
    return true;
  }

  /*bool _withinAllowed({required int minIdx, required int maxIdx}) {
    final b = allowedBounds;
    if (minIdx < b.minAllowed) return false;
    if (maxIdx > b.maxAllowed) return false;
    if (minIdx < 0) return false;
    return true;
  }*/
  bool _checkSelectionAllowed(int size, int dist) {
    final int moveRange = shields.isNotEmpty && shields[0].moveRange != null
        ? shields[0].moveRange!
        : 15;
    const int moveDist = 5;

    // ✅ مطابق لمنطق iLimitUp / iLimitDown في كود C
    final int limitUp   = isReversed ? maxDownSelection : maxUpSelection;
    final int limitDown = isReversed ? maxUpSelection   : maxDownSelection;

    if (size > moveRange) return false;

    int start = dist;
    int end = start + size;

    if (end < 0 && -end > moveDist) return false;
    if (start > 0 && start > moveDist) return false;

    if (start < 0 && -start > limitDown) return false;
    if (end > 0 && end > limitUp) return false;

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
  void touch()=> _touch();
  void pauseIdleTimer() {
    _clearTimer?.cancel();
  }

  void resumeIdleTimer() {
    _armIdleTimer();
  }

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
// ===== تشكيل/توسيع مجموعة يمين (نفس منطق التحديد الفردي) =====
  void groupRight(int ignored, Function(int newTotal) onNewTotal) {
    userInteracted(() {});
    _touch();

    // منطق C: bHARechts = (faceOrientation == 1)
    final bool haRechts = (shields.isNotEmpty && shields[0].faceOrientation == 1);

    final int limitRight = haRechts ? maxDownSelection : maxUpSelection;   // +dist
    final int limitLeft  = haRechts ? maxUpSelection   : maxDownSelection; // -dist

    final int step = _stepFor(Direction.right);
    final int moveRange =
    shields.isNotEmpty && shields[0].moveRange != null
        ? shields[0].moveRange!
        : 15;
    if (moveRange <= 0) return;

    final int start = currentShield + (isReversed ? selectionDistance : selectionDistance);

    // أول مرة: إنشاء مجموعة جديدة
    if (groupSize == 0) {
      selectionDirection = Direction.right;
      final int firstNew = start + step;

      // تحقق من الحدود (مثل selectRight)
      final int dist = (firstNew - currentShield).abs();
      if (dist > limitRight) return;

      if (!_withinAllowed(minIdx: min(start, firstNew), maxIdx: max(start, firstNew))) return;

      selectionDistance = start - currentShield;
      groupSize = 1;

      _ensurePlaceholdersForRange(min(start, firstNew), max(start, firstNew));
      onNewTotal(allowedBounds.maxAllowed + 1);
      onUpdate?.call();
      onControlChanged?.call();
      return;
    }

    // توسعة المجموعة يمين
    if (selectionDirection != Direction.right) return;
    if (groupSize >= moveRange) return;

    final int nextEdge = start + step * (groupSize + 1);
    final int dist = (nextEdge - currentShield).abs();
    if (dist > limitRight) return;

    final r = _currentRange();
    final int newMin = min(r.minIdx, nextEdge);
    final int newMax = max(r.maxIdx, nextEdge);

    if (!_withinAllowed(minIdx: newMin, maxIdx: newMax)) return;

    groupSize++;
    _ensurePlaceholdersForRange(newMin, newMax);
    onNewTotal(allowedBounds.maxAllowed + 1);
    onUpdate?.call();
    onControlChanged?.call();
  }



// ===== تشكيل/توسيع مجموعة يسار (نفس منطق التحديد الفردي) =====
  void groupLeft(Function(int newTotal, int shift) onNewTotal) {
    userInteracted(() {});
    _touch();

    final bool haRechts = (shields.isNotEmpty && shields[0].faceOrientation == 1);

    final int limitUp   = haRechts ?maxUpSelection   : maxDownSelection;
    final int limitDown = haRechts ?  maxDownSelection : maxUpSelection;

    final int step = _stepFor(Direction.left);
    final int moveRange =
    shields.isNotEmpty && shields[0].moveRange != null
        ? shields[0].moveRange!
        : 15;
    if (moveRange <= 0) return;

    final int start = currentShield + (isReversed ? selectionDistance : selectionDistance);

    // أول مرة: إنشاء مجموعة
    if (groupSize == 0) {
      selectionDirection = Direction.left;
      final int firstNew = start + step;

      final int dist = (firstNew - currentShield).abs();
      if (dist > limitUp) return;

      if (!_withinAllowed(minIdx: min(start, firstNew), maxIdx: max(start, firstNew))) return;

      selectionDistance = start - currentShield;
      groupSize = 1;

      _ensurePlaceholdersForRange(min(start, firstNew), max(start, firstNew));
      onNewTotal(allowedBounds.maxAllowed + 1, 0);
      onUpdate?.call();
      onControlChanged?.call();
      return;
    }

    // توسعة المجموعة يسار
    if (selectionDirection != Direction.left) return;
    if (groupSize >= moveRange) return;

    final int nextEdge = start + step * (groupSize + 1);
    final int dist = (nextEdge - currentShield).abs();
    if (dist > limitUp) return;

    final r = _currentRange();
    final int newMin = min(r.minIdx, nextEdge);
    final int newMax = max(r.maxIdx, nextEdge);

    if (!_withinAllowed(minIdx: newMin, maxIdx: newMax)) return;

    groupSize++;
    _ensurePlaceholdersForRange(newMin, newMax);
    onNewTotal(allowedBounds.maxAllowed + 1, 0);
    onUpdate?.call();
    onControlChanged?.call();
  }
  /// ===== تحديد أو تحريك يمين =====
  void selectRight(int ignored) {
    userInteracted(() {});
    _touch();

    // منطق C: bHARechts = (faceOrientation == 1)
    final bool haRechts = (shields.isNotEmpty && shields[0].faceOrientation == 1);

    // حدود الاختيار
    final int limitRight = haRechts ? maxDownSelection : maxUpSelection;   // +dist
    final int limitLeft  = haRechts ? maxUpSelection   : maxDownSelection; // -dist

    const int inc = 1; // يمين دايمًا +1 على المسافة مثل Selection.c

    // --- إذا في مجموعة: حركها يمين ---
    if (groupSize > 0) {
      final nextDist = selectionDistance + inc;

      if (nextDist.abs() > 5) return;
      if (nextDist > 0 && nextDist > limitRight) return;
      if (nextDist < 0 && -nextDist > limitLeft) return;

      selectionDistance = nextDist;

      final r = _currentRange();
      final int delta = haRechts ? -inc : inc; // مع الانعكاس نعكس الإشارة
      final newMin = r.minIdx + delta;
      final newMax = r.maxIdx + delta;

      if (_withinAllowed(minIdx: newMin, maxIdx: newMax)) {
        _ensurePlaceholdersForRange(newMin, newMax);
        onUpdate?.call();
        onControlChanged?.call();
      }
      return;
    }

    // --- تحديد فردي يمين ---
    final desired = selectionDistance + inc;

    if (desired.abs() > 5) return;
    if (desired > 0 && desired > limitRight) return;
    if (desired < 0 && -desired > limitLeft) return;

    // ✅ الهدف بالرسم (لاحظ قلب الإشارة لما الانعكاس مفعّل)
    final int target = (isReversed)
        ? (currentShield - desired)
        : (currentShield + desired);

    if (!_withinAllowed(minIdx: target, maxIdx: target)) return;

    selectionDirection = Direction.right;
    selectionDistance = desired;

    _ensurePlaceholdersForRange(target, target);
    onUpdate?.call();
    onControlChanged?.call();
  }

  /// ===== تحديد أو تحريك يسار (منطق مطابق لـ C تمامًا) =====
  void selectLeft() {
    userInteracted(() {});
    _touch();

    final bool haRechts = (shields.isNotEmpty && shields[0].faceOrientation == 1);

    // حدود التحديد طبقاً لاتجاه الانعكاس
    final int limitUp   = haRechts ? maxDownSelection : maxUpSelection;
    final int limitDown = haRechts ? maxUpSelection   : maxDownSelection;

    const int inc = -1; // يسار = -1 دائماً في منطق الـ C

    // --- في حال وجود مجموعة ---
    if (groupSize > 0) {
      final nextDist = selectionDistance + inc;

      if (nextDist.abs() > 5) return; // لا تتجاوز ٥ خطوات
      if (nextDist > 0 && nextDist > limitUp) return;
      if (nextDist < 0 && -nextDist > limitDown) return;

      selectionDistance = nextDist;

      final r = _currentRange();
      final int delta = inc; // التحريك الفيزيائي بنفس الإشارة هنا
      final newMin = r.minIdx + delta;
      final newMax = r.maxIdx + delta;

      if (_withinAllowed(minIdx: newMin, maxIdx: newMax)) {
        _ensurePlaceholdersForRange(newMin, newMax);
        onUpdate?.call();
        onControlChanged?.call();
      }
      return;
    }

    // --- تحديد فردي يسار ---
    final desired = selectionDistance + inc;

    if (desired.abs() > 5) return;
    if (desired > 0 && desired > limitUp) return;
    if (desired < 0 && -desired > limitDown) return;

    // 🧠 الهدف الفعلي في الرسم
    final int target = (isReversed)
        ? (currentShield - desired)
        : (currentShield + desired);

    if (!_withinAllowed(minIdx: target, maxIdx: target)) return;

    selectionDirection = Direction.left;
    selectionDistance = desired;

    _ensurePlaceholdersForRange(target, target);
    onUpdate?.call();
    onControlChanged?.call();
  }



// 🔹 مساعد: يحرك selectionStart بمقدار delta (بوحدات الفهرس) بدون تغيير الاتجاه
  void _shiftSelectionStart(int deltaIndex) {
    // selectionStart = isReversed ? currentShield - selectionDistance : currentShield + selectionDistance
    // فإذا بدنا selectionStart' = selectionStart + deltaIndex:
    // selectionDistance' = selectionDistance + (isReversed ? -deltaIndex : deltaIndex)
    selectionDistance += isReversed ? -deltaIndex : deltaIndex;
  }

// ===== حذف من يمين بصريًا (دائمًا الطرف الأيمن بصريًا) =====
  void removeFromRight() {
    _touch();
    if (groupSize <= 0) return;

    // بصريًا: يمين = +1 إذا طبيعي، -1 إذا معكوس
    final int stepVisualRight = isReversed ? -1 : 1;
    final int stepVisualLeft  = -stepVisualRight; // يسار بصريًا

    // إذا بقي عنصر واحد → رجوع لتحديد فردي (بدون تغيير الاتجاه)
    if (groupSize == 1) {
      groupSize = 0;
      _ensurePlaceholdersForRange(highlightedUnit, highlightedUnit);
      onUpdate?.call();
      onControlChanged?.call();
      return;
    }

    // احسب أطراف النطاق الحالي
    final int start = selectionStart; // بداية المجموعة بالرسم
    final int stepDir = stepFor(selectionDirection); // لازم يكون بصري (+1 يمين، -1 يسار)
    final int last = start + stepDir * groupSize;

    final int minIdx = (start < last) ? start : last;
    final int maxIdx = (start > last) ? start : last;

    // الطرف الأيمن بصريًا: إذا معكوس → الأصغر، إذا طبيعي → الأكبر
    final int rightMost = isReversed ? minIdx : maxIdx;

    // إذا الطرف الأيمن هو بداية المجموعة → حرك البداية خطوة "للداخل" باتجاه اليسار البصري
    if (rightMost == start) {
      _shiftSelectionStart(stepVisualLeft);
    }

    // قلّص حجم المجموعة دائمًا
    groupSize--;

    final r = _currentRange();
    _ensurePlaceholdersForRange(r.minIdx, r.maxIdx);
    onUpdate?.call();
    onControlChanged?.call();
  }


// ===== حذف من يسار بصريًا (دائمًا الطرف الأيسر بصريًا) =====
  void removeFromLeft() {
    _touch();
    if (groupSize <= 0) return;

    final int stepVisualRight = isReversed ? -1 : 1;
    final int stepVisualLeft  = -stepVisualRight;

    if (groupSize == 1) {
      groupSize = 0;
      _ensurePlaceholdersForRange(highlightedUnit, highlightedUnit);
      onUpdate?.call();
      onControlChanged?.call();
      return;
    }

    final int start = selectionStart;
    final int stepDir = stepFor(selectionDirection); // بصري
    final int last = start + stepDir * groupSize;

    final int minIdx = (start < last) ? start : last;
    final int maxIdx = (start > last) ? start : last;

    // الطرف الأيسر بصريًا: إذا معكوس → الأكبر، إذا طبيعي → الأصغر
    final int leftMost = isReversed ? maxIdx : minIdx;

    // إذا الطرف الأيسر هو بداية المجموعة → حرك البداية خطوة "للداخل" باتجاه اليمين البصري
    if (leftMost == start) {
      _shiftSelectionStart(stepVisualRight);
    }

    groupSize--;

    final r = _currentRange();
    _ensurePlaceholdersForRange(r.minIdx, r.maxIdx);
    onUpdate?.call();
    onControlChanged?.call();
  }
  void updateShieldData(int index, ShieldData newData) {
   /* if (index < 0) return;

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

    onUpdate?.call();*/
    if (index < 0) return;

    // 🟢 إذا نفس الشيلد وصل بنفس القيم → لا تعيدي التحديث لتجنب flicker
    final existing = shieldMap[newData.unitNumber ?? index];
    if (existing != null &&
        existing.pressure1 == newData.pressure1 &&
        existing.pressure2 == newData.pressure2 &&
        existing.ramStroke == newData.ramStroke) {
      return; // لا داعي للتحديث لأنه نفس الداتا بالضبط
    }

    // 1) حافظي على لستة shields (لا تلمسيها)
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

    // 2) إن كان الشيلد الرئيسي وما عنده unitNumber → استخرجي من اسم الجهاز
    int? unitNum = newData.unitNumber;
    if (index == 0 && (unitNum == null || unitNum == 0)) {
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
        unitNum = guessed;
        currentShield = guessed;
      }
    }

    // 3) خزّني بالماب على المفتاحين
    shieldMap[index] = newData;
    if (unitNum != null) {
      shieldMap[unitNum] = newData;
    }

    onUpdate?.call();
  }

 // int get highlightedUnit => currentShield + selectionDistance;
  int get highlightedUnit => selectionStart;

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

    final totalSpan = (maxAllowed >= minAllowed)
        ? (maxAllowed - minAllowed + 1)
        : 0;
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
    _touch(); // 🟢 يمنع حذف التحديد أثناء الضغط على زر

    userInteracted(() {}); // يعيد المؤقت

    if (slot < 0 || slot >= 6) return;
    valveFunctions[slot] = code & 0xFFFF;
    _selectCurrentIfNone();
    onUpdate?.call();
    onControlChanged?.call();
  }

  void clearValveSlot(int slot) {
    _touch();
    userInteracted(() {});
    if (slot < 0 || slot >= 6) return;
    valveFunctions[slot] = 0;
    onUpdate?.call();
    onControlChanged?.call();
  }

  void clearValveFunctions() {
    _touch();
    userInteracted(() {});
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

  void dispose() {
    _clearTimer?.cancel();
    _inactivityTimer?.cancel();
  }

  // ✅ دمي داتا للتجريب
  void initDummyDataForTest() {
    // توليد 50 شيلد للتجريب
    for (int i = 0; i < 50; i++) {
      updateShieldData(
        i,
        ShieldData(
          unitNumber: i,
          pressure1: 100 + i,
          pressure2: 120 + i,
          ramStroke: 300 + i,
          sensor4: 0,
          sensor5: 0,
          sensor6: 0,
          faceOrientation: 1, // ✅ 1 = يمين أصغر / يسار أكبر (مطابق لحالتك الواقعية)
           // ✅ 1 = يمين أصغر / يسار أكبر (مطابق لحالتك الواقعية)
          maxDownSelection: 5, // الحد الأقصى يمين (down)
          maxUpSelection: 97,  // الحد الأقصى يسار (up)
          moveRange: 15,       // أقصى مدى للمجموعة
        ),
      );
    }

    // ✅ تعريف الوضع المبدئي
    currentShield = 6; // الشيلد الرئيسي للبداية
    selectionDirection = Direction.none;
    selectionDistance = 0;
    groupSize = 0;

    onUpdate?.call(); // تحديث الواجهة فوراً
    print("✅ Dummy data initialized: ${shields.length} shields total");
  }
}
