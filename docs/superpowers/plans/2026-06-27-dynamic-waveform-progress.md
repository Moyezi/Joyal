# Dynamic Waveform Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cover-color-linked magnetic waveform progress bar that flattens away from the user's finger while dragging and returns smoothly to playback shape after release.

**Architecture:** Extract cover palette resolution into a small shared visual helper consumed by `DynamicAlbumBackground` and `NowPlayingScreen`. Keep `WaveformProgress` self-contained for gesture state and animation, and isolate drag-height math in testable static helpers on the painter.

**Tech Stack:** Flutter, Dart, Material 3, `ColorScheme.fromImageProvider`, `cached_network_image`, `flutter_test`.

---

## File Structure

- Create `lib/widgets/album_visual_palette.dart`: shared palette value object and resolver for background colors plus waveform accent colors.
- Modify `lib/widgets/dynamic_album_background.dart`: use `AlbumVisualPalette.resolve` while preserving the widget API and disk cache behavior through the helper.
- Modify `lib/widgets/waveform_progress.dart`: add accent color inputs, drag morph animation, and painter-side magnetic flattening.
- Modify `lib/screens/now_playing_screen.dart`: resolve cover palette once for the player page and pass waveform colors into `WaveformProgress`.
- Create `test/album_visual_palette_test.dart`: verify palette fallback and derived waveform colors stay contrast-friendly.
- Create `test/waveform_progress_test.dart`: verify the drag morph height math flattens far bars and preserves local bars.

### Task 1: Shared Album Visual Palette

**Files:**
- Create: `lib/widgets/album_visual_palette.dart`
- Modify: `lib/widgets/dynamic_album_background.dart`
- Test: `test/album_visual_palette_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/album_visual_palette_test.dart`:

```dart
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

  test('fromScheme derives a darker waveform accent than the background top', () {
    const scheme = ColorScheme.light(
      primary: Color(0xFF6D7CFF),
      primaryContainer: Color(0xFFC9D0FF),
      secondaryContainer: Color(0xFFDDE2F8),
    );

    final palette = AlbumVisualPalette.fromScheme(scheme);

    expect(palette.top, isNot(AppTheme.background));
    expect(palette.bottom, isNot(AppTheme.background));
    expect(palette.waveformAccent.computeLuminance(), lessThan(palette.top.computeLuminance()));
    expect(palette.waveformAccentSoft.computeLuminance(), greaterThan(palette.waveformAccent.computeLuminance()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/album_visual_palette_test.dart`

Expected: FAIL because `lib/widgets/album_visual_palette.dart` does not exist.

- [ ] **Step 3: Add the palette helper**

Create `lib/widgets/album_visual_palette.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/app_cache_service.dart';

class AlbumVisualPalette {
  final Color top;
  final Color bottom;
  final Color waveformAccent;
  final Color waveformAccentSoft;
  final Color waveformTrack;

  const AlbumVisualPalette({
    required this.top,
    required this.bottom,
    required this.waveformAccent,
    required this.waveformAccentSoft,
    required this.waveformTrack,
  });

  static const fallback = AlbumVisualPalette(
    top: AppTheme.background,
    bottom: AppTheme.background,
    waveformAccent: AppTheme.waveformPlayed,
    waveformAccentSoft: Color(0xFF5F6368),
    waveformTrack: AppTheme.waveformUnplayed,
  );

  static final Map<String, Future<AlbumVisualPalette>> _memoryCache = {};
  static Future<Map<String, dynamic>>? _diskCache;

  static AlbumVisualPalette fromScheme(ColorScheme scheme) {
    final top = Color.lerp(scheme.primaryContainer, Colors.white, 0.28)!;
    final bottom = Color.lerp(scheme.secondaryContainer, Colors.white, 0.58)!;
    final accent = Color.lerp(scheme.primary, AppTheme.primaryText, 0.24)!;
    final accentSoft = Color.lerp(accent, Colors.white, 0.52)!;
    final track = Color.lerp(AppTheme.waveformUnplayed, top, 0.16)!;
    return AlbumVisualPalette(
      top: top,
      bottom: bottom,
      waveformAccent: accent,
      waveformAccentSoft: accentSoft,
      waveformTrack: track,
    );
  }

  static Future<AlbumVisualPalette> resolve({
    required String coverArtId,
    required String coverUrl,
  }) async {
    if (coverArtId.isEmpty || coverUrl.isEmpty) return fallback;

    final diskCache = await (_diskCache ??= AppCacheService.instance
        .readJson('visual_palettes')
        .then((value) => value ?? <String, dynamic>{}));
    final saved = diskCache[coverArtId];
    if (saved is Map) {
      final top = saved['top'];
      final bottom = saved['bottom'];
      final accent = saved['waveformAccent'];
      final accentSoft = saved['waveformAccentSoft'];
      final track = saved['waveformTrack'];
      if (top is num &&
          bottom is num &&
          accent is num &&
          accentSoft is num &&
          track is num) {
        return AlbumVisualPalette(
          top: Color(top.toInt()),
          bottom: Color(bottom.toInt()),
          waveformAccent: Color(accent.toInt()),
          waveformAccentSoft: Color(accentSoft.toInt()),
          waveformTrack: Color(track.toInt()),
        );
      }
    }

    try {
      final palette = await _memoryCache.putIfAbsent(
        coverArtId,
        () async {
          final scheme = await ColorScheme.fromImageProvider(
            provider: CachedNetworkImageProvider(
              coverUrl,
              cacheKey: coverArtId,
              maxWidth: 112,
              maxHeight: 112,
            ),
            brightness: Brightness.light,
            dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
          );
          return fromScheme(scheme);
        },
      );

      diskCache[coverArtId] = {
        'top': palette.top.toARGB32(),
        'bottom': palette.bottom.toARGB32(),
        'waveformAccent': palette.waveformAccent.toARGB32(),
        'waveformAccentSoft': palette.waveformAccentSoft.toARGB32(),
        'waveformTrack': palette.waveformTrack.toARGB32(),
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };
      if (diskCache.length > 100) {
        final oldest = diskCache.entries.reduce((a, b) {
          final aTime = (a.value as Map?)?['savedAt'] as num? ?? 0;
          final bTime = (b.value as Map?)?['savedAt'] as num? ?? 0;
          return aTime <= bTime ? a : b;
        });
        diskCache.remove(oldest.key);
      }
      await AppCacheService.instance.writeJson('visual_palettes', diskCache);
      return palette;
    } catch (_) {
      _memoryCache.remove(coverArtId);
      return fallback;
    }
  }
}
```

- [ ] **Step 4: Update dynamic background to use the helper**

Modify `lib/widgets/dynamic_album_background.dart` so it imports `album_visual_palette.dart`, removes the local cache fields, and sets `_top`/`_bottom` from the resolved palette:

```dart
import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'album_visual_palette.dart';
```

In `_DynamicAlbumBackgroundState`, replace the static cache fields with:

```dart
Color _top = AppTheme.background;
Color _bottom = AppTheme.background;
```

Replace `_loadPalette()` with:

```dart
Future<void> _loadPalette() async {
  final requestedId = widget.coverArtId;
  final palette = await AlbumVisualPalette.resolve(
    coverArtId: widget.coverArtId,
    coverUrl: widget.coverUrl,
  );
  if (!mounted || widget.coverArtId != requestedId) return;
  setState(() {
    _top = palette.top;
    _bottom = palette.bottom;
  });
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/album_visual_palette_test.dart`

Expected: PASS.

### Task 2: Magnetic Waveform Drag Morph

**Files:**
- Modify: `lib/widgets/waveform_progress.dart`
- Test: `test/waveform_progress_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/waveform_progress_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/widgets/waveform_progress.dart';

void main() {
  test('drag morph keeps finger-local bars taller than far bars', () {
    final local = WaveformGeometry.morphedHeight(
      baseEnergy: 0.8,
      barFraction: 0.52,
      dragFraction: 0.5,
      dragIntensity: 1,
      maxHeight: 48,
    );
    final far = WaveformGeometry.morphedHeight(
      baseEnergy: 0.8,
      barFraction: 0.92,
      dragFraction: 0.5,
      dragIntensity: 1,
      maxHeight: 48,
    );

    expect(local, greaterThan(far * 2));
    expect(far, lessThan(18));
  });

  test('drag morph returns normal height when drag intensity is zero', () {
    final normal = WaveformGeometry.morphedHeight(
      baseEnergy: 0.64,
      barFraction: 0.9,
      dragFraction: 0.1,
      dragIntensity: 0,
      maxHeight: 50,
    );

    expect(normal, closeTo(32, 0.001));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/waveform_progress_test.dart`

Expected: FAIL because `WaveformGeometry` does not exist.

- [ ] **Step 3: Add public geometry helper and widget inputs**

Modify `lib/widgets/waveform_progress.dart`.

Add optional color fields to `WaveformProgress`:

```dart
final Color playedColor;
final Color playedGlowColor;
final Color unplayedColor;
```

Add constructor defaults:

```dart
this.playedColor = AppTheme.waveformPlayed,
this.playedGlowColor = const Color(0xFF5F6368),
this.unplayedColor = AppTheme.waveformUnplayed,
```

Add the testable helper above `_WaveformPainter`:

```dart
class WaveformGeometry {
  WaveformGeometry._();

  static double morphedHeight({
    required double baseEnergy,
    required double barFraction,
    required double? dragFraction,
    required double dragIntensity,
    required double maxHeight,
    double pulseScale = 1,
  }) {
    final normalHeight = baseEnergy * maxHeight * pulseScale;
    if (dragFraction == null || dragIntensity <= 0) {
      return normalHeight.clamp(3.0, maxHeight);
    }

    final distance = (barFraction - dragFraction).abs();
    final localInfluence = (1 - distance / 0.18).clamp(0.0, 1.0);
    final easedInfluence = Curves.easeOutCubic.transform(localInfluence);
    final flattenedHeight = maxHeight * (0.18 + baseEnergy * 0.1);
    final magneticHeight = normalHeight * (1 + easedInfluence * 0.22);
    final dragHeight = flattenedHeight +
        (magneticHeight - flattenedHeight) * easedInfluence;
    return (normalHeight + (dragHeight - normalHeight) * dragIntensity)
        .clamp(3.0, maxHeight);
  }
}
```

- [ ] **Step 4: Add drag intensity animation**

In `_WaveformProgressState`, add:

```dart
late final AnimationController _dragMorphController;
late final Animation<double> _dragMorph;
```

Initialize after `_pulseController`:

```dart
_dragMorphController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 220),
  reverseDuration: const Duration(milliseconds: 340),
);
_dragMorph = CurvedAnimation(
  parent: _dragMorphController,
  curve: Curves.easeOutCubic,
  reverseCurve: Curves.elasticOut,
);
```

In `_updateDrag`, before `setState`, call:

```dart
_dragMorphController.forward();
```

Add helper:

```dart
void _releaseDragMorph() {
  _dragMorphController.reverse();
}
```

Call `_releaseDragMorph()` when drag is cancelled and after committed seek clears `_dragFraction`.

Dispose:

```dart
_dragMorphController.dispose();
```

- [ ] **Step 5: Pass drag state and colors into painter**

Change `AnimatedBuilder` to listen to both controllers:

```dart
animation: Listenable.merge([_pulseController, _dragMorphController]),
```

Pass these painter arguments:

```dart
playedColor: widget.playedColor,
playedGlowColor: widget.playedGlowColor,
unplayedColor: widget.unplayedColor,
dragFraction: _dragFraction,
dragIntensity: _dragMorph.value,
```

Update `_WaveformPainter` constructor and fields to accept those values.

- [ ] **Step 6: Use magnetic height and gradient-like color blending in paint**

Inside `_WaveformPainter.paint`, replace fixed paints and height calculation with:

```dart
final barFraction = waveformData.length == 1
    ? 0.0
    : i / (waveformData.length - 1);
final isActive = i == activeIndex;
final energyPulse = isActive ? 1 + pulse * waveformData[i] * 0.18 : 1.0;
final height = WaveformGeometry.morphedHeight(
  baseEnergy: waveformData[i],
  barFraction: barFraction,
  dragFraction: dragFraction,
  dragIntensity: dragIntensity,
  maxHeight: size.height,
  pulseScale: energyPulse,
);
final playedBlend = progress <= 0
    ? 0.0
    : (barFraction / progress).clamp(0.0, 1.0);
final color = i <= activeIndex
    ? Color.lerp(playedColor, playedGlowColor, playedBlend * 0.45)!
    : unplayedColor;
final paint = Paint()..color = color;
```

Use `height` and `paint` in `canvas.drawRRect`.

Update `shouldRepaint` to include `dragFraction`, `dragIntensity`, and colors.

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/waveform_progress_test.dart`

Expected: PASS.

### Task 3: Now Playing Palette Wiring

**Files:**
- Modify: `lib/screens/now_playing_screen.dart`

- [ ] **Step 1: Add import and local palette state**

Import:

```dart
import '../widgets/album_visual_palette.dart';
```

In `_NowPlayingScreenState`, add:

```dart
AlbumVisualPalette _visualPalette = AlbumVisualPalette.fallback;
String? _paletteCoverArtId;
```

- [ ] **Step 2: Add palette loading method**

Add method in `_NowPlayingScreenState`:

```dart
void _syncVisualPalette(Song? song) {
  final coverArtId = song?.coverArt ?? '';
  if (_paletteCoverArtId == coverArtId) return;
  _paletteCoverArtId = coverArtId;
  final coverUrl = _coverUrl(ref, song);
  AlbumVisualPalette.resolve(coverArtId: coverArtId, coverUrl: coverUrl).then((
    palette,
  ) {
    if (!mounted || _paletteCoverArtId != coverArtId) return;
    setState(() => _visualPalette = palette);
  });
}
```

- [ ] **Step 3: Call palette sync from build**

In `build`, after reading `song`, add:

```dart
_syncVisualPalette(song);
```

- [ ] **Step 4: Pass colors into WaveformProgress**

In `_playerContent`, update `WaveformProgress`:

```dart
playedColor: _visualPalette.waveformAccent,
playedGlowColor: _visualPalette.waveformAccentSoft,
unplayedColor: _visualPalette.waveformTrack,
```

### Task 4: Full Verification

**Files:**
- Verify: `lib/widgets/album_visual_palette.dart`
- Verify: `lib/widgets/dynamic_album_background.dart`
- Verify: `lib/widgets/waveform_progress.dart`
- Verify: `lib/screens/now_playing_screen.dart`
- Verify: `test/album_visual_palette_test.dart`
- Verify: `test/waveform_progress_test.dart`

- [ ] **Step 1: Run targeted tests**

Run: `flutter test test/album_visual_palette_test.dart test/waveform_progress_test.dart`

Expected: Both test files PASS.

- [ ] **Step 2: Run static analysis**

Run: `dart analyze lib test`

Expected: No new analyzer errors from the changed files.

- [ ] **Step 3: Build arm64 release APK for review**

Run: `flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`

Expected: APK generated at `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

---

## Self-Review

- Spec coverage: palette sharing, cover-derived waveform color, drag flattening, local finger amplification, animated enter/exit, seek preservation, and fallback colors are covered.
- Placeholder scan: no `TBD`, `TODO`, or undefined behavior remains.
- Type consistency: `AlbumVisualPalette`, `WaveformGeometry`, `_syncVisualPalette`, and waveform color fields are named consistently across tasks.

