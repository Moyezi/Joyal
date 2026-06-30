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

  test('readable waveform colors keep contrast in dark mode', () {
    const palette = AlbumVisualPalette(
      top: Color(0xFF121212),
      bottom: Color(0xFF121212),
      waveformAccent: Color(0xFF1C1C1C),
      waveformAccentSoft: Color(0xFF333333),
      waveformTrack: Color(0xFF151515),
    );

    expect(
      palette.waveformAccentFor(Brightness.dark).computeLuminance(),
      greaterThanOrEqualTo(0.34),
    );
    expect(
      palette.waveformTrackFor(Brightness.dark).computeLuminance(),
      greaterThanOrEqualTo(0.08),
    );
  });

  test('readable waveform colors keep contrast in light mode', () {
    const palette = AlbumVisualPalette(
      top: Color(0xFFFFFFFF),
      bottom: Color(0xFFFFFFFF),
      waveformAccent: Color(0xFFEDEDED),
      waveformAccentSoft: Color(0xFFF4F4F4),
      waveformTrack: Color(0xFFFAFAFA),
    );

    expect(
      palette.waveformAccentFor(Brightness.light).computeLuminance(),
      lessThanOrEqualTo(0.30),
    );
    expect(
      palette.waveformTrackFor(Brightness.light).computeLuminance(),
      lessThanOrEqualTo(0.76),
    );
  });
}
