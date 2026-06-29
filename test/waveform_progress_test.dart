import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/widgets/waveform_progress.dart';

void main() {
  group('activeHalfWidth', () {
    test('returns ~7% of bar count as fraction space radius', () {
      final halfWidth = WaveformGeometry.activeHalfWidth(72);
      expect(halfWidth, closeTo(0.07, 0.01));
    });

    test('scales proportionally with bar count', () {
      expect(
        WaveformGeometry.activeHalfWidth(36),
        closeTo(WaveformGeometry.activeHalfWidth(144), 0.005),
      );
    });
  });

  group('rippleHeight', () {
    test('center bar at phase=0 is mid-range (~28.2)', () {
      final h = WaveformGeometry.rippleHeight(
        barFraction: 0.5,
        centerFraction: 0.5,
        phase: 0,
        activeHalfWidth: 0.07,
        staticHeight: 12,
      );
      expect(h, greaterThanOrEqualTo(22.8));
      expect(h, lessThanOrEqualTo(33.6));
    });

    test('center bar at specific phase reaches minimum height', () {
      final h = WaveformGeometry.rippleHeight(
        barFraction: 0.5,
        centerFraction: 0.5,
        phase: pi / 2,
        activeHalfWidth: 0.07,
        staticHeight: 12,
      );
      expect(h, closeTo(22.8, 0.01));
    });

    test('bar outside active zone stays at static height', () {
      final h = WaveformGeometry.rippleHeight(
        barFraction: 0.8,
        centerFraction: 0.5,
        phase: 0,
        activeHalfWidth: 0.07,
        staticHeight: 12,
      );
      expect(h, closeTo(12, 0.01));
    });

    test('bar at edge of active zone is >= static height', () {
      final h = WaveformGeometry.rippleHeight(
        barFraction: 0.56,
        centerFraction: 0.5,
        phase: 0,
        activeHalfWidth: 0.07,
        staticHeight: 12,
      );
      expect(h, greaterThanOrEqualTo(12));
      expect(h, lessThanOrEqualTo(16));
    });

    test('height is symmetric around center', () {
      final left = WaveformGeometry.rippleHeight(
        barFraction: 0.45,
        centerFraction: 0.5,
        phase: 1.0,
        activeHalfWidth: 0.07,
        staticHeight: 12,
      );
      final right = WaveformGeometry.rippleHeight(
        barFraction: 0.55,
        centerFraction: 0.5,
        phase: 1.0,
        activeHalfWidth: 0.07,
        staticHeight: 12,
      );
      expect(left, closeTo(right, 0.001));
    });
  });

  group('morphedHeight (preserved for drag overlay)', () {
    test('drag morph keeps finger-local bars taller than far bars', () {
      final local = WaveformGeometry.morphedHeight(
        baseEnergy: 0.8,
        barFraction: 0.52,
        dragFraction: 0.5,
        dragIntensity: 1,
        maxHeight: 48,
      );
      final far = WaveformGeometry.morphedHeight(
        baseEnergy: 0.8,
        barFraction: 0.92,
        dragFraction: 0.5,
        dragIntensity: 1,
        maxHeight: 48,
      );
      expect(local, greaterThan(far * 2));
      expect(far, lessThan(18));
    });

    test('drag morph returns normal height when drag intensity is zero', () {
      final normal = WaveformGeometry.morphedHeight(
        baseEnergy: 0.64,
        barFraction: 0.9,
        dragFraction: 0.1,
        dragIntensity: 0,
        maxHeight: 50,
      );
      expect(normal, closeTo(32, 0.001));
    });
  });

  group('effectiveDragFraction', () {
    test('keeps settling fraction while intensity remains active', () {
      expect(
        WaveformGeometry.effectiveDragFraction(
          dragFraction: null,
          settlingDragFraction: 0.42,
          dragIntensity: 0.5,
        ),
        0.42,
      );
      expect(
        WaveformGeometry.effectiveDragFraction(
          dragFraction: null,
          settlingDragFraction: 0.42,
          dragIntensity: 0,
        ),
        isNull,
      );
    });

    test('clamps overshooting intensity in morphedHeight', () {
      final capped = WaveformGeometry.morphedHeight(
        baseEnergy: 0.8,
        barFraction: 0.5,
        dragFraction: 0.5,
        dragIntensity: 1,
        maxHeight: 48,
      );
      final overshooting = WaveformGeometry.morphedHeight(
        baseEnergy: 0.8,
        barFraction: 0.5,
        dragFraction: 0.5,
        dragIntensity: 1.5,
        maxHeight: 48,
      );
      expect(overshooting, closeTo(capped, 0.001));
    });
  });

  group('ripple coloring logic', () {
    test('active zone radius covers ~14% of total bars', () {
      final half = WaveformGeometry.activeHalfWidth(72);
      expect(half * 2, closeTo(0.14, 0.01));
    });

    test('bar at center is in active zone', () {
      final h = WaveformGeometry.rippleHeight(
        barFraction: 0.5,
        centerFraction: 0.5,
        phase: 0,
        activeHalfWidth: 0.07,
        staticHeight: 12,
      );
      // Should be elevated above static (12) because it's in active zone
      expect(h, greaterThan(12));
    });

    test('bar at 0.58 is outside active zone when center is 0.5', () {
      final h = WaveformGeometry.rippleHeight(
        barFraction: 0.58,
        centerFraction: 0.5,
        phase: 0,
        activeHalfWidth: 0.07,
        staticHeight: 12,
      );
      expect(h, closeTo(12, 0.01));
    });
  });
}
