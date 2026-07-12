import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/providers/lyrics_personalization_provider.dart';

void main() {
  test('legacy justify alignment migrates to right alignment', () {
    expect(
      LyricsAlignmentMode.fromStorageValue('justify'),
      LyricsAlignmentMode.right,
    );
  });

  test('lyrics stage mode restores available stages', () {
    expect(
      LyricsStageMode.fromStorageValue('flowing_light'),
      LyricsStageMode.flowingLight,
    );
    expect(
      LyricsStageMode.fromStorageValue('default_scroll'),
      LyricsStageMode.defaultScroll,
    );
  });

  test('unfinished and unknown lyrics stages fall back to default', () {
    expect(
      LyricsStageMode.fromStorageValue('floating_name'),
      LyricsStageMode.defaultScroll,
    );
    expect(
      LyricsStageMode.fromStorageValue('chorus'),
      LyricsStageMode.defaultScroll,
    );
    expect(
      LyricsStageMode.fromStorageValue('future_stage'),
      LyricsStageMode.defaultScroll,
    );
  });
}
