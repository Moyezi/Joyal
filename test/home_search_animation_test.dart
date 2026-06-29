import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyal_music/app.dart';

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
}
