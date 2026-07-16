import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/screens/search_screen.dart';
import 'package:joyal_music/widgets/navigation/search_ripple_route.dart';

void main() {
  testWidgets('search route expands outward from the provided origin', (
    tester,
  ) async {
    const origin = Offset(360, 72);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  buildSearchRippleRoute<void>(
                    origin: origin,
                    builder: (_) => const Scaffold(body: Text('搜索页')),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    final clipPath = tester.widget<ClipPath>(find.byType(ClipPath).last);
    final clipSize = tester.getSize(find.byType(ClipPath).last);
    final farCorner = Offset(1, clipSize.height - 1);
    final earlyReveal = clipPath.clipper!.getClip(clipSize);
    expect(earlyReveal.contains(origin), isTrue);
    expect(earlyReveal.contains(farCorner), isFalse);

    await tester.pumpAndSettle();

    final settledClipPath = tester.widget<ClipPath>(find.byType(ClipPath).last);
    final settledReveal = settledClipPath.clipper!.getClip(
      tester.getSize(find.byType(ClipPath).last),
    );
    expect(settledReveal.contains(farCorner), isTrue);
    expect(find.text('搜索页'), findsOneWidget);
  });

  testWidgets('search screen waits for the user before focusing the field', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SearchScreen())),
    );
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
  });
}
