import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'config/theme.dart';
import 'models/song.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/library_provider.dart';
import 'providers/player_provider.dart';
import 'screens/home_screen.dart';
import 'screens/hotlist_screen.dart';
import 'screens/library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/personalization_screen.dart';
import 'screens/settings_hub_screen.dart';
import 'services/android_media_bridge.dart';
import 'services/lyrics_service.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/home_sidebar.dart';
import 'widgets/mini_player.dart';

/// The root widget of the application.
class JoyalMusicApp extends ConsumerWidget {
  const JoyalMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authProvider, (prev, next) {
      if (next.isConnected && prev?.isConnected != true) {
        // Let providers depending on auth finish rebuilding before refreshing.
        Future.microtask(() => ref.read(libraryProvider.notifier).initialize());
      }
    });

    return MaterialApp(
      title: 'Joyal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlayStyle = isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const MainShell(),
    );
  }
}

/// The primary navigation shell:
/// - Bottom tab bar (Home / Library / Favorites)
/// - Tab content via a pre-mounted sliding stack
/// - Home sidebar drawer and floating [MiniPlayer] above the bottom nav
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with TickerProviderStateMixin {
  int _currentTab = 0;
  int? _previousTab;
  int _tabDirection = 0;
  AndroidMediaBridge? _androidMediaBridge;
  final ValueNotifier<int> _libraryTabRequest = ValueNotifier<int>(0);
  final GlobalKey _bottomNavKey = GlobalKey();

  static const double _drawerWidthFactor = 0.70;
  static const double _drawerOpenThreshold = 0.35;
  static const double _drawerMinScale = 0.94;
  static const double _drawerFlingVelocity = 420;
  static const Duration _tabSwitchDuration = Duration(milliseconds: 260);
  static const Duration _tapCloseDuration = Duration(milliseconds: 220);

  bool _isDraggingDrawer = false;
  bool _isMiniPlayerCollapsed = false;
  double _drawerAccumulatedDx = 0;
  double _drawerAccumulatedDy = 0;
  bool _drawerTrackingAccepted = false;
  bool _suppressNextDrawerTap = false;
  late final AnimationController _drawerController;
  late final AnimationController _tabTransitionController;
  double _lastDrawerWidth = 0;
  String? _lastLyricsPrefetchSongId;
  final Set<String> _lyricsPrefetchInFlight = {};
  final List<_VelocitySample> _velocitySamples = [];
  final List<Rect> _drawerExclusionRects = [];

  void _registerDrawerExclusion(Rect rect) {
    _drawerExclusionRects.clear();
    _drawerExclusionRects.add(rect);
  }

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    _tabTransitionController =
        AnimationController(
          vsync: this,
          duration: _tabSwitchDuration,
          value: 1.0,
        )..addStatusListener((status) {
          if (status != AnimationStatus.completed || !mounted) return;
          if (_previousTab == null) return;
          setState(() {
            _previousTab = null;
            _tabDirection = 0;
          });
        });
    _androidMediaBridge = AndroidMediaBridge(
      resolveCoverArtPath: (state) async {
        final song = state.currentSong;
        final api = ref.read(subsonicApiProvider);
        if (song == null || api == null || song.coverArt.isEmpty) {
          return null;
        }
        final file = await DefaultCacheManager().getSingleFile(
          api.getCoverArtUrl(song.coverArt),
          key: song.coverArt,
        );
        return file.path;
      },
      onControlAction: (action) async {
        final notifier = ref.read(playerProvider.notifier);
        switch (action) {
          case 'togglePlayPause':
            await notifier.togglePlayPause();
          case 'next':
            await notifier.next();
          case 'previous':
            await notifier.previous();
        }
      },
    );
    _screens = [
      HomeScreen(
        onExclusionZoneChanged: _registerDrawerExclusion,
        onShowAllAlbums: _openLibraryAlbums,
      ),
      LibraryScreen(tabRequest: _libraryTabRequest),
      const HotlistScreen(),
    ];
  }

  void _onTabChanged(int index) {
    _selectTab(index);
  }

  void _selectTab(int index, {bool haptic = false}) {
    final nextIndex = index.clamp(0, _screens.length - 1);
    if (nextIndex == _currentTab) return;

    if (haptic) {
      HapticFeedback.selectionClick();
    }
    _tabTransitionController.stop();
    setState(() {
      _previousTab = _currentTab;
      _tabDirection = nextIndex > _currentTab ? 1 : -1;
      _currentTab = nextIndex;
    });
    _tabTransitionController.forward(from: 0.0);
  }

  int? _tabIndexAtGlobalPosition(Offset globalPosition) {
    final context = _bottomNavKey.currentContext;
    if (context == null) return null;
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox || renderBox.size.width <= 0) return null;

    final localX = renderBox.globalToLocal(globalPosition).dx;
    final clampedX = localX.clamp(0.0, renderBox.size.width - 0.1);
    return (clampedX / renderBox.size.width * _screens.length).floor().clamp(
      0,
      _screens.length - 1,
    );
  }

  void _handleBottomNavDragUpdate(DragUpdateDetails details) {
    final index = _tabIndexAtGlobalPosition(details.globalPosition);
    if (index == null || index == _currentTab) return;
    _closeDrawer();
    _selectTab(index, haptic: true);
  }

  void _openLibraryAlbums() {
    _closeDrawer();
    _selectTab(1);
    _libraryTabRequest.value = -1;
    _libraryTabRequest.value = 1;
  }

  bool get _isDrawerOpen => _drawerController.value > 0.001;

  void _setDrawerProgress(double value) {
    if (!mounted) return;
    _drawerController.stop();
    _drawerController.value = value.clamp(0.0, 1.0);
  }

  void _closeDrawer() {
    if (!mounted) return;
    _drawerController.animateTo(
      0.0,
      duration: _tapCloseDuration,
      curve: Curves.easeIn,
    );
  }

  void _resetDrawerPointerTracking() {
    _drawerAccumulatedDx = 0;
    _drawerAccumulatedDy = 0;
    _drawerTrackingAccepted = false;
    _isDraggingDrawer = false;
  }

  void _recordVelocitySample(double deltaDx, Duration timestamp) {
    _velocitySamples.add(
      _VelocitySample(timestamp: timestamp, deltaDx: deltaDx),
    );
    while (_velocitySamples.length > 5) {
      _velocitySamples.removeAt(0);
    }
  }

  double _estimateVelocity() {
    if (_velocitySamples.length < 2) return 0.0;
    double totalDx = 0.0;
    double totalDt = 0.0;
    for (int i = 1; i < _velocitySamples.length; i++) {
      totalDx += _velocitySamples[i].deltaDx;
      totalDt +=
          (_velocitySamples[i].timestamp - _velocitySamples[i - 1].timestamp)
              .inMicroseconds /
          1000000.0;
    }
    if (totalDt <= 0.0) return 0.0;
    return totalDx / totalDt;
  }

  void _snapAfterRelease([double? releaseVelocity]) {
    final progress = _drawerController.value;
    final pixelVelocity = releaseVelocity ?? _estimateVelocity();
    final progressVelocity = _lastDrawerWidth > 0
        ? (pixelVelocity / _lastDrawerWidth).abs()
        : 0.0;
    _velocitySamples.clear();

    if (pixelVelocity >= _drawerFlingVelocity ||
        (pixelVelocity.abs() < _drawerFlingVelocity &&
            progress >= _drawerOpenThreshold)) {
      final remaining = 1 - progress;
      final speed = progressVelocity.clamp(0.5, 8.0);
      final durationMs = (remaining / speed * 1000).clamp(120.0, 220.0).toInt();
      _drawerController.animateTo(
        1.0,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeOut,
      );
      return;
    }

    final remaining = progress;
    final speed = progressVelocity.clamp(0.5, 8.0);
    final durationMs = (remaining / speed * 1000).clamp(120.0, 220.0).toInt();
    _drawerController.animateTo(
      0.0,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOut,
    );
  }

  void _openSettingsHub() {
    _closeDrawer();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsHubScreen()));
  }

  void _openPersonalization() {
    _closeDrawer();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PersonalizationScreen()));
  }

  bool _shouldAllowDrawerPointer(PointerDownEvent event, double drawerWidth) {
    if (drawerWidth <= 0) return false;
    if (_isDraggingDrawer) return false;
    if (_isInBottomDockArea(event.position)) return false;

    final canStartClosed = _currentTab == 0 && !_isDrawerOpen;
    final canTrackOpen = _isDrawerOpen;
    if (!canStartClosed && !canTrackOpen) return false;

    if (canStartClosed) {
      for (final rect in _drawerExclusionRects) {
        if (rect.contains(event.position)) return false;
      }
    }

    return true;
  }

  bool _isInBottomDockArea(Offset globalPosition) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return false;

    final hasSong = ref.read(playerProvider).hasSong;
    final miniPlayerHeight = hasSong ? 104.0 : 0.0;
    final bottomNavHeight = 76.0 + mediaQuery.padding.bottom;
    final dockTop = mediaQuery.size.height - bottomNavHeight - miniPlayerHeight;
    return globalPosition.dy >= dockTop;
  }

  void _collapseMiniPlayer() {
    if (_isMiniPlayerCollapsed) return;
    setState(() => _isMiniPlayerCollapsed = true);
  }

  void _expandMiniPlayer() {
    if (!_isMiniPlayerCollapsed) return;
    setState(() => _isMiniPlayerCollapsed = false);
  }

  void _handleDrawerDragStart(DragStartDetails details) {
    _drawerAccumulatedDx = 0;
    _drawerAccumulatedDy = 0;
    _velocitySamples.clear();
    _drawerTrackingAccepted = true;
    _isDraggingDrawer = true;
  }

  void _handleDrawerDragUpdate(DragUpdateDetails details, double drawerWidth) {
    if (!_isDraggingDrawer || drawerWidth <= 0) {
      return;
    }

    final delta = details.delta;
    _drawerAccumulatedDx += delta.dx;
    _drawerAccumulatedDy += delta.dy;

    if (!_isDrawerOpen && delta.dx <= 0) return;
    _setDrawerProgress(_drawerController.value + delta.dx / drawerWidth);
    _recordVelocitySample(delta.dx, details.sourceTimeStamp ?? Duration.zero);
  }

  void _handleDrawerDragEnd(DragEndDetails details) {
    if (!_isDraggingDrawer) return;
    if (_drawerTrackingAccepted) {
      _suppressNextDrawerTap =
          _drawerAccumulatedDx.abs() > 4 || _drawerAccumulatedDy.abs() > 4;
      _snapAfterRelease(details.primaryVelocity);
    }
    _resetDrawerPointerTracking();
  }

  void _handleDrawerDragCancel() {
    if (!_isDraggingDrawer) return;
    if (_drawerTrackingAccepted) {
      _snapAfterRelease();
    }
    _resetDrawerPointerTracking();
  }

  void _handleDrawerPreviewTap() {
    if (_suppressNextDrawerTap) {
      _suppressNextDrawerTap = false;
      return;
    }
    _closeDrawer();
  }

  void _openNowPlaying() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NowPlayingScreen(),
        transitionDuration: const Duration(milliseconds: 640),
        reverseTransitionDuration: const Duration(milliseconds: 480),
      ),
    );
  }

  void _prefetchLyrics(PlaybackState state) {
    final song = state.currentSong;
    final api = ref.read(subsonicApiProvider);
    if (song == null || api == null) return;
    if (_lastLyricsPrefetchSongId == song.id) return;
    _lastLyricsPrefetchSongId = song.id;

    final songs = <String, Song>{song.id: song};
    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= 0 && nextIndex < state.playlist.length) {
      final nextSong = state.playlist[nextIndex];
      songs[nextSong.id] = nextSong;
    }

    final service = LyricsService(api: api, dio: ref.read(dioProvider));
    for (final entry in songs.entries) {
      if (!_lyricsPrefetchInFlight.add(entry.key)) continue;
      unawaited(
        service
            .fetch(entry.value)
            .then<void>((_) {}, onError: (_) {})
            .whenComplete(() {
              _lyricsPrefetchInFlight.remove(entry.key);
            }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlaybackState>(playerProvider, (previous, next) {
      unawaited(_androidMediaBridge?.sync(next));
      if (!next.hasSong && _isMiniPlayerCollapsed && mounted) {
        setState(() => _isMiniPlayerCollapsed = false);
      }
      if (previous?.currentSong?.id != next.currentSong?.id) {
        _prefetchLyrics(next);
      }
    });

    final isStartingUp =
        ref.watch(authProvider.select((state) => state.isLoading)) ||
        ref.watch(playerProvider.select((state) => state.isRestoringSession));

    return LayoutBuilder(
      builder: (context, constraints) {
        final drawerWidth = constraints.maxWidth * _drawerWidthFactor;
        _lastDrawerWidth = drawerWidth;
        return Scaffold(
          body: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: {
              _DrawerHorizontalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _DrawerHorizontalDragGestureRecognizer
                  >(() => _DrawerHorizontalDragGestureRecognizer(), (
                    recognizer,
                  ) {
                    recognizer.shouldAcceptPointer = (event) =>
                        _shouldAllowDrawerPointer(event, drawerWidth);
                    recognizer.onStart = _handleDrawerDragStart;
                    recognizer.onUpdate = (details) =>
                        _handleDrawerDragUpdate(details, drawerWidth);
                    recognizer.onEnd = _handleDrawerDragEnd;
                    recognizer.onCancel = _handleDrawerDragCancel;
                  }),
            },
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: drawerWidth,
                  child: RepaintBoundary(
                    child: HomeSidebar(
                      onSettingsTap: _openSettingsHub,
                      onPersonalizationTap: _openPersonalization,
                    ),
                  ),
                ),
                _buildTransformedShell(drawerWidth: drawerWidth),
                _StartupMask(isVisible: isStartingUp),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransformedShell({required double drawerWidth}) {
    return AnimatedBuilder(
      animation: _drawerController,
      child: _buildShellContent(),
      builder: (context, child) {
        final progress = _drawerController.value;
        final scale = 1 - ((1 - _drawerMinScale) * progress);
        final previewBorderRadius = BorderRadius.circular(28 * progress);
        final shouldClipPreview = progress > 0.001;
        final preview = Stack(
          children: [
            RepaintBoundary(child: child!),
            if (progress > 0)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleDrawerPreviewTap,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.10 * progress),
                      borderRadius: previewBorderRadius,
                    ),
                  ),
                ),
              ),
          ],
        );

        return Transform.translate(
          offset: Offset(drawerWidth * progress, 0),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.centerLeft,
            child: shouldClipPreview
                ? Material(
                    type: MaterialType.transparency,
                    shape: RoundedRectangleBorder(
                      borderRadius: previewBorderRadius,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: preview,
                  )
                : preview,
          ),
        );
      },
    );
  }

  Widget _buildShellContent() {
    return Stack(
      children: [
        Positioned.fill(child: _buildSlidingTabs()),
        Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MiniPlayer(
                  isCollapsed: _isMiniPlayerCollapsed,
                  onTap: _openNowPlaying,
                  onCollapseRequested: _collapseMiniPlayer,
                  onExpandRequested: _expandMiniPlayer,
                ),
                GestureDetector(
                  key: _bottomNavKey,
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: _handleBottomNavDragUpdate,
                  child: AppBottomNav(
                    currentIndex: _currentTab,
                    onTabChanged: (index) {
                      _closeDrawer();
                      _onTabChanged(index);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlidingTabs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ClipRect(
          child: AnimatedBuilder(
            animation: _tabTransitionController,
            builder: (context, _) {
              final progress = Curves.easeOutCubic.transform(
                _tabTransitionController.value,
              );
              return Stack(
                children: [
                  for (var index = 0; index < _screens.length; index++)
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(_tabOffset(index, progress) * width, 0),
                        child: ExcludeSemantics(
                          excluding:
                              index != _currentTab && index != _previousTab,
                          child: TickerMode(
                            enabled:
                                index == _currentTab || index == _previousTab,
                            child: IgnorePointer(
                              ignoring:
                                  index != _currentTab ||
                                  _tabTransitionController.isAnimating,
                              child: RepaintBoundary(child: _screens[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  double _tabOffset(int index, double progress) {
    final previous = _previousTab;
    if (previous == null || _tabDirection == 0) {
      return (index - _currentTab).toDouble();
    }
    if (index == _currentTab) {
      return _tabDirection * (1 - progress);
    }
    if (index == previous) {
      return -_tabDirection * progress;
    }
    return (index - _currentTab).toDouble();
  }

  @override
  void dispose() {
    _androidMediaBridge?.dispose();
    _drawerController.dispose();
    _tabTransitionController.dispose();
    _libraryTabRequest.dispose();
    super.dispose();
  }
}

class _StartupMask extends StatelessWidget {
  final bool isVisible;

  const _StartupMask({required this.isVisible});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedOpacity(
        opacity: isVisible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _VelocitySample {
  final Duration timestamp;
  final double deltaDx;
  const _VelocitySample({required this.timestamp, required this.deltaDx});
}

class _DrawerHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  bool Function(PointerDownEvent event)? shouldAcceptPointer;

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (event is! PointerDownEvent) return false;
    return (shouldAcceptPointer?.call(event) ?? false) &&
        super.isPointerAllowed(event);
  }
}
