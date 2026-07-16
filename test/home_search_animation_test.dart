import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyal_music/app.dart';
import 'package:joyal_music/screens/search_screen.dart';

void main() {
  testWidgets('HomeScreen has search icons in both search bar and top bar', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: JoyalMusicApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Large search bar should be visible initially.
    expect(find.text('搜索歌曲、专辑或艺人'), findsOneWidget);

    // At least two search icons: one in big search bar, one in top bar.
    expect(find.byIcon(Icons.search_rounded), findsAtLeast(2));
  });

  testWidgets('large home search opens the anchored search screen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: JoyalMusicApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final searchInkWell = find.ancestor(
      of: find.text('搜索歌曲、专辑或艺人'),
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(searchInkWell).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byType(ClipPath), findsAtLeast(1));

    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);
  });
}
