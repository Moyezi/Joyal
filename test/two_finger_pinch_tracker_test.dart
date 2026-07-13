import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/utils/two_finger_pinch_tracker.dart';

void main() {
  test('reports outward and inward distance from the two-finger baseline', () {
    final tracker = TwoFingerPinchTracker();
    tracker.addPointer(1, const Offset(100, 100));
    tracker.addPointer(2, const Offset(200, 100));

    final outward = tracker.updatePointer(2, const Offset(240, 100));
    expect(outward?.scale, closeTo(1.4, 0.001));
    expect(outward?.distanceDelta, closeTo(40, 0.001));

    final inward = tracker.updatePointer(2, const Offset(160, 100));
    expect(inward?.scale, closeTo(0.6, 0.001));
    expect(inward?.distanceDelta, closeTo(-40, 0.001));
  });

  test('resets its baseline after either finger leaves', () {
    final tracker = TwoFingerPinchTracker();
    tracker.addPointer(1, const Offset(0, 0));
    tracker.addPointer(2, const Offset(100, 0));
    tracker.markTriggered();
    tracker.removePointer(2);

    expect(tracker.isTracking, isFalse);
    expect(tracker.hasTriggered, isFalse);

    tracker.addPointer(3, const Offset(200, 0));
    final progress = tracker.updatePointer(3, const Offset(250, 0));
    expect(progress?.distanceDelta, closeTo(50, 0.001));
  });
}
