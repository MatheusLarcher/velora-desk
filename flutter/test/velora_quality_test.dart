import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/velora_quality.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clock the test moves by hand.
class _Clock {
  DateTime t = DateTime(2026, 1, 1);
  DateTime now() => t;
  void advance(Duration d) => t = t.add(d);
}

void main() {
  late _Clock clock;
  late VeloraAutoQuality auto;

  setUp(() {
    clock = _Clock();
    auto = VeloraAutoQuality(now: clock.now);
  });

  /// One reading per second, like the delay monitor.
  String? feed(int ms) {
    clock.advance(const Duration(seconds: 1));
    return auto.onDelay(ms);
  }

  test('levels match the core image quality values', () {
    expect(kVeloraQualityBest, kRemoteImageQualityBest);
    expect(kVeloraQualityBalanced, kRemoteImageQualityBalanced);
    expect(kVeloraQualityLow, kRemoteImageQualityLow);
    expect(veloraQualityLabel(kVeloraQualityBest), 'Alta');
    expect(veloraQualityLabel(kVeloraQualityBalanced), 'Média');
    expect(veloraQualityLabel(kVeloraQualityLow), 'Baixa');
    expect(veloraQualityLabel('custom'), isNull);
  });

  test('thresholds: <50 best, 50..150 balanced, >150 low', () {
    expect(VeloraAutoQuality.levelIndexFor(0), 0);
    expect(VeloraAutoQuality.levelIndexFor(49), 0);
    expect(VeloraAutoQuality.levelIndexFor(50), 1);
    expect(VeloraAutoQuality.levelIndexFor(150), 1);
    expect(VeloraAutoQuality.levelIndexFor(151), 2);
  });

  test('first reading sets the level; bad input is ignored', () {
    expect(auto.onDelay(-1), isNull);
    expect(auto.current, isNull);
    expect(feed(30), kVeloraQualityBest);
    expect(auto.current, kVeloraQualityBest);
  });

  test('goes down after 2 bad readings in a row', () {
    feed(30);
    expect(feed(200), isNull);
    expect(feed(200), kVeloraQualityLow);
    expect(auto.current, kVeloraQualityLow);
  });

  test('goes down to the mildest level of the bad streak', () {
    feed(30);
    expect(feed(200), isNull);
    expect(feed(80), kVeloraQualityBalanced);
  });

  test('does not go up before 15 s of good readings', () {
    feed(200); // starts at low
    // 14 s of good readings after the first one: still low.
    for (var i = 0; i < 15; i++) {
      expect(feed(30), isNull, reason: 'reading $i');
    }
    // Cooldown is not in the way: there was no switch yet.
    expect(feed(30), kVeloraQualityBest);
  });

  test('respects 30 s between switches', () {
    feed(30); // best, not a switch
    feed(200);
    expect(feed(200), kVeloraQualityLow); // switch at t=3 s
    // t=4..32 s good: past the 15 s rule, still inside the 30 s cooldown.
    for (var i = 0; i < 29; i++) {
      expect(feed(30), isNull, reason: 'reading $i');
    }
    expect(feed(30), kVeloraQualityBest); // t=33 s
  });

  test('a downgrade also waits for the cooldown', () {
    feed(100); // balanced, not a switch
    for (var i = 0; i < 15; i++) {
      expect(feed(30), isNull, reason: 'reading $i');
    }
    expect(feed(30), kVeloraQualityBest); // switch at t=17 s
    // t=18..46 s bad: 2 readings are enough, but the cooldown holds it.
    for (var i = 0; i < 29; i++) {
      expect(feed(200), isNull, reason: 'reading $i');
    }
    expect(feed(200), kVeloraQualityLow); // t=47 s
  });

  test('ignores oscillation', () {
    feed(30); // best
    // Alternating good/bad never makes 2 bad in a row.
    for (var i = 0; i < 40; i++) {
      expect(feed(i.isEven ? 200 : 30), isNull, reason: 'reading $i');
    }
    expect(auto.current, kVeloraQualityBest);

    auto.reset();
    feed(100); // balanced
    // Alternating balanced/best keeps resetting the 15 s window.
    for (var i = 0; i < 40; i++) {
      expect(feed(i.isEven ? 30 : 100), isNull, reason: 'reading $i');
    }
    expect(auto.current, kVeloraQualityBalanced);
  });

  test('reset forgets the level', () {
    feed(200);
    auto.reset();
    expect(auto.current, isNull);
    expect(feed(30), kVeloraQualityBest);
  });
}
