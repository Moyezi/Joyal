import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/widgets/lyrics_stage/lyrics_stage_shell.dart';

void main() {
  testWidgets('lyrics header starts fading after five visible seconds', (
    tester,
  ) async {
    Widget build(Duration? visibleDuration) {
      return MaterialApp(
        home: Scaffold(
          body: LyricsStageHeader(
            title: '歌曲名',
            artist: '歌手',
            foreground: Colors.white,
            visibleDuration: visibleDuration,
            padding: EdgeInsets.zero,
          ),
        ),
      );
    }

    await tester.pumpWidget(build(null));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );

    await tester.pumpWidget(build(const Duration(seconds: 5)));
    await tester.pump(const Duration(milliseconds: 4999));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );

    await tester.pump(const Duration(milliseconds: 1));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    await tester.pumpWidget(build(null));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
  });
}
