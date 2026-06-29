import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/config/theme.dart';
import 'package:joyal_music/widgets/album_visual_palette.dart';

void main() {
  test('fallback palette uses existing neutral app colors', () {
    final palette = AlbumVisualPalette.fallback;

    expect(palette.top, AppTheme.background);
    expect(palette.bottom, AppTheme.background);
    expect(palette.waveformAccent, AppTheme.waveformPlayed);
    expect(palette.waveformTrack, AppTheme.waveformUnplayed);
  });

  test(
    'fromScheme derives a darker waveform accent than the background top',
    () {
      const scheme = ColorScheme.light(
        primary: Color(0xFF6D7CFF),
        primaryContainer: Color(0xFFC9D0FF),
        secondaryContainer: Color(0xFFDDE2F8),
      );

      final palette = AlbumVisualPalette.fromScheme(scheme, Brightness.light);

      expect(palette.top, isNot(AppTheme.background));
      expect(palette.bottom, isNot(AppTheme.background));
      expect(
        palette.waveformAccent.computeLuminance(),
        lessThan(palette.top.computeLuminance()),
      );
      expect(
        palette.waveformAccentSoft.computeLuminance(),
        greaterThan(palette.waveformAccent.computeLuminance()),
      );
    },
  );
}
