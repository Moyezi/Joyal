import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/providers/lyrics_personalization_provider.dart';

void main() {
  test('AI lyrics color defaults off and can be copied on', () {
    const defaults = LyricsPersonalizationState(isLoading: false);

    expect(defaults.aiColorEnabled, isFalse);
    expect(defaults.copyWith(aiColorEnabled: true).aiColorEnabled, isTrue);
  });

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
    expect(
      LyricsStageMode.fromStorageValue('floating_name'),
      LyricsStageMode.floatingName,
    );
  });

  test('unfinished and unknown lyrics stages fall back to default', () {
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
