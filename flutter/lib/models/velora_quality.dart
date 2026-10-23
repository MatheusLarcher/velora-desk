// Velora: "Auto" image quality for the technician's session window.
//
// Pure Dart on purpose (no Flutter, no bind) so the decision rules can be
// tested with an injected clock. The caller feeds every delay reading and
// applies the level this returns through sessionSetImageQuality. The server's
// own ABR (src/server/video_qos.rs) is untouched; this only picks the preset.

/// Menu value of the Auto entry. Never sent to the core.
const kVeloraQualityAuto = 'velora-auto';

// Same strings as kRemoteImageQuality{Best,Balanced,Low} in consts.dart, kept
// literal here so this file does not pull in Flutter.
const kVeloraQualityBest = 'best';
const kVeloraQualityBalanced = 'balanced';
const kVeloraQualityLow = 'low';

/// pt-BR label of a quality level, or null for anything else.
String? veloraQualityLabel(String? level) {
  switch (level) {
    case kVeloraQualityBest:
      return 'Alta';
    case kVeloraQualityBalanced:
      return 'Média';
    case kVeloraQualityLow:
      return 'Baixa';
    default:
      return null;
  }
}

/// Picks best/balanced/low from the measured delay, with hysteresis:
/// - below [goodBelowMs] is best, up to [badAboveMs] is balanced, above is low;
/// - goes down after [downReadings] consecutive readings at a worse level;
/// - goes up only after [upAfter] of consecutive readings at a better level;
/// - switches at most once every [minSwitchInterval].
/// The first valid reading sets the starting level right away; that does not
/// count as a switch for [minSwitchInterval].
class VeloraAutoQuality {
  static const goodBelowMs = 50;
  static const badAboveMs = 150;
  static const downReadings = 2;
  static const upAfter = Duration(seconds: 15);
  static const minSwitchInterval = Duration(seconds: 30);

  static const _levels = [
    kVeloraQualityBest,
    kVeloraQualityBalanced,
    kVeloraQualityLow,
  ];

  final DateTime Function() _now;

  VeloraAutoQuality({DateTime Function()? now}) : _now = now ?? DateTime.now;

  String? _current;
  DateTime? _lastSwitch;

  // Streak of readings worse than the current level, and the mildest of them.
  int _worseCount = 0;
  int _worseTarget = 0;

  // Start of the streak of readings better than the current level, and the
  // least improvement seen in it.
  DateTime? _betterSince;
  int _betterTarget = 0;

  /// Level in use, or null before the first reading.
  String? get current => _current;

  /// Level index for a delay: 0 = best, 1 = balanced, 2 = low.
  static int levelIndexFor(int delayMs) {
    if (delayMs < goodBelowMs) return 0;
    if (delayMs <= badAboveMs) return 1;
    return 2;
  }

  /// Forget everything; the next reading sets the level again.
  void reset() {
    _current = null;
    _lastSwitch = null;
    _clearStreaks();
  }

  /// Feeds one delay reading. Returns the new level when it should be applied,
  /// otherwise null. Negative readings are ignored.
  String? onDelay(int delayMs) {
    if (delayMs < 0) return null;
    final now = _now();
    final target = levelIndexFor(delayMs);
    final current = _current;
    if (current == null) {
      // Starting point, not a switch: it does not start the cooldown.
      _switchTo(target, now);
      _lastSwitch = null;
      return _current;
    }
    final cur = _levels.indexOf(current);
    if (target == cur) {
      _clearStreaks();
      return null;
    }
    final cooledDown = _lastSwitch == null ||
        now.difference(_lastSwitch!) >= minSwitchInterval;
    if (target > cur) {
      _betterSince = null;
      _worseTarget = _worseCount == 0 ? target : _min(_worseTarget, target);
      _worseCount++;
      if (_worseCount >= downReadings && cooledDown) {
        return _switchTo(_worseTarget, now);
      }
      return null;
    }
    _worseCount = 0;
    if (_betterSince == null) {
      _betterSince = now;
      _betterTarget = target;
    } else {
      _betterTarget = _max(_betterTarget, target);
    }
    if (now.difference(_betterSince!) >= upAfter && cooledDown) {
      return _switchTo(_betterTarget, now);
    }
    return null;
  }

  String _switchTo(int index, DateTime now) {
    _current = _levels[index];
    _lastSwitch = now;
    _clearStreaks();
    return _current!;
  }

  void _clearStreaks() {
    _worseCount = 0;
    _worseTarget = 0;
    _betterSince = null;
    _betterTarget = 0;
  }

  static int _min(int a, int b) => a < b ? a : b;
  static int _max(int a, int b) => a > b ? a : b;
}
