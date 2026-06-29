import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sidebar exclusion zone', () {
    test('pointer down inside exclusion rect is ignored', () {
      final exclusionRects = <Rect>[
        const Rect.fromLTWH(16, 300, 360, 200),
      ];

      final insideEvent = PointerDownEvent(
        position: const Offset(100, 350),
        pointer: 1,
      );

      final outsideEvent = PointerDownEvent(
        position: const Offset(100, 100),
        pointer: 2,
      );

      // Inside exclusion zone → should be ignored
      bool insideShouldTrack = true;
      for (final rect in exclusionRects) {
        if (rect.contains(insideEvent.position)) {
          insideShouldTrack = false;
          break;
        }
      }
      expect(insideShouldTrack, isFalse);

      // Outside exclusion zone → should track normally
      bool outsideShouldTrack = true;
      for (final rect in exclusionRects) {
        if (rect.contains(outsideEvent.position)) {
          outsideShouldTrack = false;
          break;
        }
      }
      expect(outsideShouldTrack, isTrue);
    });

    test('empty exclusion list allows all pointers', () {
      final exclusionRects = <Rect>[];
      final event = PointerDownEvent(
        position: const Offset(100, 350),
        pointer: 1,
      );

      bool shouldTrack = true;
      for (final rect in exclusionRects) {
        if (rect.contains(event.position)) {
          shouldTrack = false;
          break;
        }
      }
      expect(shouldTrack, isTrue);
    });
  });
}
