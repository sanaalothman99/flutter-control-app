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
  int? moveDistanceLimit;
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

  int get moveDistanceSelection =>
     shields.isNotEmpty && shields[0].moveDistanceLimit != null
      ? shields[0].moveDistanceLimit!
     :5;

  int get selectionStart => currentShield + selectionDistance;
 /* int get selectionStart =>
      isReversed ? currentShield - selectionDistance
          : currentShield + selectionDistance;*/

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

  int get selectionDistanceForMcu {
    if (selectionDistance == 0 && groupSize == 0) return 0;

    // 🔹 تحديد فردي فقط
    if (groupSize == 0 && selectionDistance != 0) {
      int value = selectionDistance;

      // ✅ إذا الاتجاه معكوس (faceOrientation == 1)
      // فالقيم الأصغر على اليمين → لازم نعكس الإشارة
      if (isReversed) value = -value;

      // ✅ إذا الاتجاه Left، نخليها سالبة
      if (selectionDirection == Direction.left) value = -value;

      return value;
    }

    // 🔹 مجموعة محددة
    if (groupSize > 0) {
      final dist = selectionStart - currentShield;
      int value = dist;

      // نحافظ على الإشارة الأصلية حسب اتجاه التحديد
      if (selectionDirection == Direction.left) value = -value;

      // وإذا الاتجاه معكوس (faceOrientation == 1)، نعكسها كلها
      if (isReversed) value = -value;

      return value;
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
   // return 0x00;
    return (selectionDistance == 0) ? 0x0D : 0x0C;
  }

// ===== حدود السماحية (تصحيح بسيط للانعكاس) =====
  _Limits _limits() {
      if (isReversed){
        return _Limits(maxDownSelection, maxUpSelection);
      }
      // faceOrientation = 1 → الأرقام تصغر باتجاه اليمين
     else{ return _Limits(
        maxDownSelection,   // يسار بصرياً
        maxUpSelection, // يمين بصرياً
      );}

  }

  _Limits _limitsForMovement() => _limits();

  bool _withinStepLimits(int desired /* المسافة الجديدة من المركز */) {
    final lim = _limitsForMovement();
    if (desired > 0 && desired > lim.right) return false; // يمين فيزيائياً
    if (desired < 0 && -desired > lim.left) return false; // يسار فيزيائياً
    if (desired.abs() > 5) return false; // حد 5 خطوات
    return true;
  }

  ({int minAllowed, int maxAllowed}) get allowedBounds {
    final int up = maxUpSelection;
    final int down = maxDownSelection;

    int minA, maxA;

    if (isReversed) {
      // faceOrientation = 1 → الأرقام تصغر يميناً
      // يعني: اليمين = أصغر أرقام  →  currentShield - down
      //        اليسار = أكبر أرقام →  currentShield + up
      minA = currentShield - down;
      maxA = currentShield + up;
    } else {
      // faceOrientation = 0 → الأرقام تكبر يميناً
      // يعني: اليسار = currentShield - up
      //        اليمين = currentShield + down
      minA = currentShield - down;
      maxA = currentShield + up;
    }

    if (minA < 0) minA = 0;
    return (minAllowed: minA, maxAllowed: maxA);
  }
  /*({int minAllowed, int maxAllowed}) get allowedBounds {
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
 /* ({int minAllowed, int maxAllowed}) get allowedBounds {
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
  }*/

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
    return true;
  }


 /* bool _withinAllowed({required int minIdx, required int maxIdx}) {
    // المسافة من الشيلد الرئيسي
    final int distRight = maxIdx - currentShield;
    final int distLeft  = currentShield - minIdx;

    // حدود فيزيائية ثابتة
    final int maxRight = maxDownSelection ?? 5;
    final int maxLeft  = maxUpSelection ?? 5;

    // إذا الاتجاه معكوس (faceOrientation = 1): الأرقام تصغر يمين
    if (isReversed) {
      // يمين = تصغير رقم
      if (distLeft > maxRight) return false; // أبعد يمين مما يجب
      if (distRight > maxLeft) return false; // أبعد يسار مما يجب
    } else {
      // الاتجاه الطبيعي
      if (distRight > maxRight) return false;
      if (distLeft > maxLeft) return false;
    }

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

  void selectRight(int ignored) {
    userInteracted(() {}); _touch();

    final int step = _stepFor(Direction.right);
    final _Limits lim = _limits();

    // مجموعة؟ ازاحة كاملة
    if (groupSize > 0) {
      final r = _currentRange();
      final newMin = r.minIdx + step, newMax = r.maxIdx + step;
      if (!_withinAllowed(minIdx: newMin, maxIdx: newMax)) return;
      selectionDistance += step;
      _ensurePlaceholdersForRange(newMin, newMax);
      onUpdate?.call(); onControlChanged?.call(); return;
    }

    if (groupSize == 0 && selectionDistance == 0) selectionDirection = Direction.right;

    final int desired = selectionDistance + step;
    final bool goingOut = desired.abs() > selectionDistance.abs();

    // طبّق الحدود فقط إذا طالع لبرا
    if (goingOut) {
      if (desired.abs() > 5) return;
      if (desired > 0 && desired > lim.right) return;   // يمين فيزيائي
      if (desired < 0 && -desired > lim.left) return;   // يسار فيزيائي (نادر هون)
    }

    selectionDistance = desired;
    final int target = currentShield + desired;
    if (!_withinAllowed(minIdx: target, maxIdx: target)) return;

    _ensurePlaceholdersForRange(target, target);
    onUpdate?.call(); onControlChanged?.call();
  }

  void selectLeft() {
    userInteracted(() {}); _touch();

    final int step = _stepFor(Direction.left);
    final _Limits lim = _limits();

    if (groupSize > 0) {
      final r = _currentRange();
      final newMin = r.minIdx + step, newMax = r.maxIdx + step;
      if (!_withinAllowed(minIdx: newMin, maxIdx: newMax)) return;
      selectionDistance += step;
      _ensurePlaceholdersForRange(newMin, newMax);
      onUpdate?.call(); onControlChanged?.call(); return;
    }

    if (groupSize == 0 && selectionDistance == 0) selectionDirection = Direction.left;

    final int desired = selectionDistance + step;
    final bool goingOut = desired.abs() > selectionDistance.abs();

    if (goingOut) {
      if (desired.abs() > 5) return;
      if (desired < 0 && -desired > lim.left) return;   // يسار فيزيائي
      if (desired > 0 && desired > lim.right) return;   // يمين فيزيائي (نادر هون)
    }

    selectionDistance = desired;
    final int target = currentShield + desired;
    if (!_withinAllowed(minIdx: target, maxIdx: target)) return;

    _ensurePlaceholdersForRange(target, target);
    onUpdate?.call(); onControlChanged?.call();
  }
  void groupRight(int ignored, Function(int newTotal) onNewTotal) {
    userInteracted(() {}); _touch();

    final int stepR = _stepFor(Direction.right);
    final int moveRange = maxGroupSize;
    if (moveRange <= 0) return;

    final r = _currentRange();

    // أول مرّة: إنشاء مجموعة ناحية اليمين
    if (groupSize == 0) {
      selectionDirection = Direction.right;
      final firstNew = selectionStart + stepR;
      if (!_withinAllowed(minIdx: min(selectionStart, firstNew), maxIdx: max(selectionStart, firstNew))) return;

      selectionDistance = selectionStart - currentShield; // حافظ على الـ anchor
      groupSize = 1;
      _ensurePlaceholdersForRange(min(selectionStart, firstNew), max(selectionStart, firstNew));
      onNewTotal(allowedBounds.maxAllowed + 1);
      onUpdate?.call(); onControlChanged?.call();
      return;
    }

    if (groupSize >= moveRange) return;

    // ⬅️ توسعة دائمًا على الحافة اليمنى للنطاق الحالي
    final nextEdge = r.maxIdx + stepR;
    // تأكد من الحدود
    if (!_withinAllowed(minIdx: r.minIdx, maxIdx: nextEdge)) return;

    // لو الاتجاه الأصلي يسار، لازم نزيح نقطة البداية خطوة يمين لنضم عنصرًا من يمين
    if (selectionDirection == Direction.left) {
      selectionDistance += stepR; // تحريك الـ start ناحية اليمين الفيزيائي
    }
    groupSize++;
    final rr = _currentRange();
    _ensurePlaceholdersForRange(rr.minIdx, rr.maxIdx);
    onNewTotal(allowedBounds.maxAllowed + 1);
    onUpdate?.call(); onControlChanged?.call();
  }

  void groupLeft(Function(int newTotal, int shift) onNewTotal) {
    userInteracted(() {}); _touch();

    final int stepL = _stepFor(Direction.left);
    final int moveRange = maxGroupSize;
    if (moveRange <= 0) return;

    final r = _currentRange();

    // أول مرّة: إنشاء مجموعة ناحية اليسار
    if (groupSize == 0) {
      selectionDirection = Direction.left;
      final firstNew = selectionStart + stepL;
      if (!_withinAllowed(minIdx: min(selectionStart, firstNew), maxIdx: max(selectionStart, firstNew))) return;

      selectionDistance = selectionStart - currentShield; // حافظ على الـ anchor
      groupSize = 1;
      _ensurePlaceholdersForRange(min(selectionStart, firstNew), max(selectionStart, firstNew));
      onNewTotal(allowedBounds.maxAllowed + 1, 0);
      onUpdate?.call(); onControlChanged?.call();
      return;
    }

    if (groupSize >= moveRange) return;

    // ⬅️ توسعة دائمًا على الحافة اليسرى للنطاق الحالي
    final nextEdge = r.minIdx + stepL;
    if (!_withinAllowed(minIdx: nextEdge, maxIdx: r.maxIdx)) return;

    // لو الاتجاه الأصلي يمين، لازم نزيح نقطة البداية خطوة يسار لنضم عنصرًا من يسار
    if (selectionDirection == Direction.right) {
      selectionDistance += stepL; // تحريك الـ start ناحية اليسار الفيزيائي
    }
    groupSize++;
    final rr = _currentRange();
    _ensurePlaceholdersForRange(rr.minIdx, rr.maxIdx);
    onNewTotal(allowedBounds.maxAllowed + 1, 0);
    onUpdate?.call(); onControlChanged?.call();
  }
  // مساعد صغير: يحرّك selectionStart بمقدار دلتا اندكس
  void _shiftSelectionStart(int deltaIndex) {
    // selectionStart' = selectionStart + deltaIndex
    // => selectionDistance' = selectionDistance + (isReversed ? -deltaIndex : deltaIndex)
    selectionDistance += isReversed ? -deltaIndex : deltaIndex;
  }

  void removeFromRight() {
    _touch();
    if (groupSize <= 0) return;

    final int start = selectionStart;
    final int stepDir = stepFor(selectionDirection);
    final int end = start + stepDir * groupSize;

    // حدّد أي طرف هو "يمين بصريًا"
    // عند isReversed=false → اليمين = index الأكبر
    // عند isReversed=true  → اليمين = index الأصغر
    final int rightVisual = isReversed ? (start < end ? start : end)
        : (start > end ? start : end);

    // إذا كنا نحذف الطرف اليميني وهو نفسه الـ start → حرّك الـ start خطوة للداخل
    if (rightVisual == start) {
      selectionDistance += stepDir; // نقل نقطة البداية للداخل
      groupSize -= 1;
    } else {
      // الطرف البعيد عن start
      groupSize -= 1;
    }

    // ترتيب وحماية
    if (groupSize < 0) groupSize = 0;

    final r = _currentRange();
    _ensurePlaceholdersForRange(r.minIdx, r.maxIdx);
    onUpdate?.call();
    onControlChanged?.call();
  }

  void removeFromLeft() {
    _touch();
    if (groupSize <= 0) return;

    final int start = selectionStart;
    final int stepDir = stepFor(selectionDirection);
    final int end = start + stepDir * groupSize;

    // حدّد أي طرف هو "يسار بصريًا"
    // عند isReversed=false → اليسار = index الأصغر
    // عند isReversed=true  → اليسار = index الأكبر
    final int leftVisual = isReversed ? (start > end ? start : end)
        : (start < end ? start : end);

    // إذا كنا نحذف الطرف اليساري وهو نفسه الـ start → حرّك الـ start خطوة للداخل (بعكس اتجاه المجموعة)
    if (leftVisual == start) {
      selectionDistance += stepDir; // نقل نقطة البداية للداخل
      groupSize -= 1;
    } else {
      // الطرف البعيد عن start
      groupSize -= 1;
    }

    if (groupSize < 0) groupSize = 0;

    final r = _currentRange();
    _ensurePlaceholdersForRange(r.minIdx, r.maxIdx);
    onUpdate?.call();
    onControlChanged?.call();
  }
 /* void updateShieldData(int index, ShieldData newData) {
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
      while (shields.length <= index) {
        shields.add(ShieldData.empty(unitNumber: shields.length));
      }
      shields.add(newData);
    }

    // 2) إن كان الشيلد الرئيسي وما عنده unitNumber → استخرجي من اسم الجهاز
    int? unitNum = newData.unitNumber;

    // ✅ تعديل إضافي: تأكيد تعيين currentShield أول مرة فقط (حتى لو unitNumber != 0)
    if (index == 0 && currentShield == 0) {
      final guessed = (unitNum == null || unitNum == 0)
          ? _deviceUnitFromName()
          : unitNum;
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
          moveDistanceLimit: newData.moveDistanceLimit,
        );
        unitNum = guessed;
        currentShield = guessed; // ✅ يعين الشيلد الرئيسي مرة واحدة فقط
      }
    }

    // 3) خزّني بالماب على المفتاحين
    shieldMap[index] = newData;
    if (unitNum != null) {
      shieldMap[unitNum] = newData;
    }

    onUpdate?.call();
  }*/
  void updateShieldData(int index, ShieldData newData) {
    if (index < 0) return;

    // 🟢 لا تمنعي تحديث الشيلد الرئيسي/الحالي حتى لو نفس القيم
    final int key = newData.unitNumber ?? index;
    final bool isMainOrCurrent = (index == 0) || (key == currentShield);

    // إذا نفس الشيلد وصل بنفس القيم → لا تعيدي التحديث لتجنب flicker
    // ✳️ لكن اسمحي بالتحديث لو كان الشيلد الرئيسي/الحالي
    final existing = shieldMap[key];
    if (!isMainOrCurrent &&
        existing != null &&
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
      while (shields.length <= index) {
        shields.add(ShieldData.empty(unitNumber: shields.length));
      }
      shields.add(newData);
    }

    // 2) إن كان الشيلد الرئيسي وما عنده unitNumber → استخرجي من اسم الجهاز
    int? unitNum = newData.unitNumber;

    // ✅ تأكيد تعيين currentShield أول مرة فقط
    if (index == 0 && currentShield == 0) {
      final guessed = (unitNum == null || unitNum == 0)
          ? _deviceUnitFromName()
          : unitNum;
      if (guessed != null) {
        newData = newData.copyWith(unitNumber: guessed);
        unitNum = guessed;
        currentShield = guessed; // يعين الشيلد الرئيسي مرة واحدة فقط
      }
    }

    // 3) خزّني بالماب على المفتاحين
    shieldMap[index] = newData;
    if (unitNum != null) {
      shieldMap[unitNum] = newData;
    }
    print("🔁 Updating shield index=$index  pressures=(${newData.pressure1}, ${newData.pressure2})");
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
    for (int i = 0; i < 11; i++) {
      updateShieldData(
        i,
        ShieldData(
          unitNumber: i,
          pressure1: 100 + i,
          pressure2: 120 + i,
          ramStroke: 600 + i,
          sensor4: 0,
          sensor5: 0,
          sensor6: 0,
          faceOrientation: 1, // ✅ 1 = يمين أصغر / يسار أكبر (مطابق لحالتك الواقعية)
           // ✅ 1 = يمين أصغر / يسار أكبر (مطابق لحالتك الواقعية)
          maxDownSelection: 3, // الحد الأقصى يمين (down)
          maxUpSelection: 10,  // الحد الأقصى يسار (up)
          moveRange: 15,       // أقصى مدى للمجموعة
        ),
      );
    }

    // ✅ تعريف الوضع المبدئي
    currentShield = 4; // الشيلد الرئيسي للبداية
    selectionDirection = Direction.none;
    selectionDistance = 0;
    groupSize = 0;

    onUpdate?.call(); // تحديث الواجهة فوراً
    print("✅ Dummy data initialized: ${shields.length} shields total");
  }
}
