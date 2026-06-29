import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/utils/scroll_utils.dart';

void main() {
  testWidgets('centers an item in a 153-song fixed extent list', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 600,
              child: ListView.builder(
                controller: controller,
                itemExtent: 72,
                padding: const EdgeInsets.only(top: 124, bottom: 172),
                itemCount: 153,
                itemBuilder: (_, index) => Text('Song $index'),
              ),
            ),
          ),
        ),
      ),
    );

    final scroll = scrollIndexToCenter(
      controller: controller,
      index: 100,
      itemExtent: 72,
      leadingExtent: 124,
      duration: const Duration(milliseconds: 1),
    );
    await tester.pumpAndSettle();
    await scroll;

    final expected = 124 + 100 * 72 + 36 - 300;
    expect(controller.offset, closeTo(expected, 0.01));
  });
}
