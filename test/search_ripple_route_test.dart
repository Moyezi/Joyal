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

  testWidgets('home search curtain grows vertically from the source capsule', (
    tester,
  ) async {
    const sourceRect = Rect.fromLTWH(24, 150, 352, 54);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  buildSearchCurtainRoute<void>(
                    sourceRect: sourceRect,
                    builder: (_, animation) => SearchScreen(
                      transitionAnimation: animation,
                      sourceRect: sourceRect,
                    ),
                  ),
                ),
                child: const Text('展开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('展开'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final initialClip = tester.widget<ClipPath>(find.byType(ClipPath).last);
    final initialPath = initialClip.clipper!.getClip(
      tester.getSize(find.byType(ClipPath).last),
    );
    expect(initialPath.contains(sourceRect.center), isTrue);
    expect(initialPath.contains(const Offset(24, 20)), isFalse);
    expect(initialPath.contains(const Offset(24, 700)), isFalse);

    await tester.pump(const Duration(milliseconds: 310));
    final middleClip = tester.widget<ClipPath>(find.byType(ClipPath).last);
    final middlePath = middleClip.clipper!.getClip(
      tester.getSize(find.byType(ClipPath).last),
    );
    expect(middlePath.contains(const Offset(200, 20)), isTrue);
    expect(middlePath.contains(const Offset(200, 700)), isFalse);

    await tester.pumpAndSettle();
    final settledClip = tester.widget<ClipPath>(find.byType(ClipPath).last);
    final settledSize = tester.getSize(find.byType(ClipPath).last);
    final settledPath = settledClip.clipper!.getClip(settledSize);
    expect(settledPath.contains(const Offset(1, 1)), isTrue);
    expect(
      settledPath.contains(
        Offset(settledSize.width - 1, settledSize.height - 1),
      ),
      isTrue,
    );
    expect(find.byTooltip('返回'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final fieldOpacity = tester
        .widgetList<Opacity>(
          find.ancestor(
            of: find.byType(TextField),
            matching: find.byType(Opacity),
          ),
        )
        .map((widget) => widget.opacity);
    expect(fieldOpacity.any((opacity) => opacity < .05), isTrue);

    await tester.pump(const Duration(milliseconds: 240));
    expect(
      tester.getTopLeft(find.byType(TextField)).dy,
      greaterThan(sourceRect.top),
    );

    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
  });
}
