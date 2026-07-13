import 'package:flutter/widgets.dart';

/// Tracks the distance between the first two active pointers without joining
/// Flutter's gesture arena. This lets a two-finger shortcut coexist with the
/// shell's one-finger drawer and the canvas' one-finger pan gesture.
class TwoFingerPinchTracker {
  final Map<int, Offset> _positions = <int, Offset>{};
  double? _startDistance;
  bool _triggered = false;

  int get pointerCount => _positions.length;
  bool get isTracking => _positions.length == 2;
  bool get hasTriggered => _triggered;

  void addPointer(int pointer, Offset position) {
    if (_positions.containsKey(pointer) || _positions.length >= 2) return;
    _positions[pointer] = position;
    if (_positions.length == 2) {
      _startDistance = _distance;
      _triggered = false;
    }
  }

  PinchProgress? updatePointer(int pointer, Offset position) {
    if (!_positions.containsKey(pointer)) return null;
    _positions[pointer] = position;
    final startDistance = _startDistance;
    if (_positions.length != 2 || startDistance == null || startDistance <= 0) {
      return null;
    }

    final distance = _distance;
    return PinchProgress(
      scale: distance / startDistance,
      distanceDelta: distance - startDistance,
    );
  }

  void markTriggered() {
    _triggered = true;
  }

  void removePointer(int pointer) {
    _positions.remove(pointer);
    if (_positions.length < 2) {
      _startDistance = null;
      _triggered = false;
    }
  }

  void reset() {
    _positions.clear();
    _startDistance = null;
    _triggered = false;
  }

  double get _distance {
    final points = _positions.values.take(2).toList(growable: false);
    return (points[0] - points[1]).distance;
  }
}

class PinchProgress {
  final double scale;
  final double distanceDelta;

  const PinchProgress({required this.scale, required this.distanceDelta});
}
