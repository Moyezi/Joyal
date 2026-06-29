import 'package:flutter/material.dart';

Future<void> scrollIndexToCenter({
  required ScrollController controller,
  required int index,
  required double itemExtent,
  double leadingExtent = 0,
  Duration duration = const Duration(milliseconds: 420),
}) async {
  if (!controller.hasClients || index < 0) return;
  final position = controller.position;
  final itemCenter = leadingExtent + index * itemExtent + itemExtent / 2;
  final target = (itemCenter - position.viewportDimension / 2).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  await controller.animateTo(
    target,
    duration: duration,
    curve: Curves.easeOutCubic,
  );
}
