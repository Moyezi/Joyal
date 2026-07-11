import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import 'cache_management_screen.dart';
import 'download_manager_screen.dart';
import 'music_classification_screen.dart';
import 'personalization_screen.dart';
import 'settings_screen.dart';

class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SettingsHubCardData(
        icon: Icons.dns_outlined,
        title: '服务器连接',
        subtitle: '配置连接并同步曲库',
        accentColor: const Color(0xFF5182D8),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
      ),
      _SettingsHubCardData(
        icon: Icons.tune_rounded,
        title: '个性化设置',
        subtitle: '背景、玻璃与播放外观',
        accentColor: const Color(0xFFAA6BC7),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PersonalizationScreen()),
        ),
      ),
      _SettingsHubCardData(
        icon: Icons.auto_awesome_rounded,
        title: '智能分类',
        subtitle: '整理流派、情绪和场景',
        accentColor: const Color(0xFFE09A57),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MusicClassificationScreen()),
        ),
      ),
      _SettingsHubCardData(
        icon: Icons.download_for_offline_outlined,
        title: '下载管理',
        subtitle: '管理离线音乐',
        accentColor: const Color(0xFF5FA99A),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DownloadManagerScreen()),
        ),
      ),
      _SettingsHubCardData(
        icon: Icons.storage_rounded,
        title: '缓存管理',
        subtitle: '清理缓存与设置策略',
        accentColor: const Color(0xFF7893B8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CacheManagementScreen()),
        ),
      ),
      _SettingsHubCardData(
        icon: Icons.info_outline_rounded,
        title: '关于 Joyal',
        subtitle: '版本 1.0.1',
        accentColor: const Color(0xFF9A8C76),
        onTap: () => showAboutDialog(
          context: context,
          applicationName: 'Joyal',
          applicationVersion: '1.0.1',
          applicationLegalese: '© 2026 Joyal',
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppTheme.spacingMD,
          crossAxisSpacing: AppTheme.spacingMD,
          childAspectRatio: 0.92,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) => _SettingsHubCard(data: cards[index]),
      ),
    );
  }
}

class _SettingsHubCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _SettingsHubCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });
}

class _SettingsHubCard extends StatefulWidget {
  final _SettingsHubCardData data;

  const _SettingsHubCard({required this.data});

  @override
  State<_SettingsHubCard> createState() => _SettingsHubCardState();
}

class _SettingsHubCardState extends State<_SettingsHubCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = context.surfaceColor;
    final gradientStart = Color.lerp(
      surface,
      data.accentColor,
      isDark ? 0.27 : 0.12,
    )!;
    final gradientEnd = Color.lerp(
      surface,
      data.accentColor,
      isDark ? 0.13 : 0.04,
    )!;
    final borderColor = data.accentColor.withValues(
      alpha: _pressed ? (isDark ? 0.42 : 0.28) : (isDark ? 0.25 : 0.16),
    );

    return AnimatedScale(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      scale: _pressed ? 1.025 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _pressed ? 0.18 : 0.11),
              blurRadius: _pressed ? 30 : 22,
              offset: Offset(0, _pressed ? 14 : 10),
            ),
            BoxShadow(
              color: data.accentColor.withValues(alpha: _pressed ? 0.16 : 0.09),
              blurRadius: _pressed ? 26 : 18,
              offset: const Offset(12, 14),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradientStart, gradientEnd],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: InkWell(
              onTap: data.onTap,
              onHighlightChanged: (pressed) {
                if (_pressed != pressed) setState(() => _pressed = pressed);
              },
              child: Stack(
                children: [
                  Positioned(
                    right: _pressed ? -24 : -32,
                    bottom: _pressed ? -24 : -34,
                    child: _SettingsAmbientLight(
                      color: data.accentColor,
                      opacity: _pressed ? 0.72 : 0.48,
                      size: _pressed ? 126 : 106,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _SettingsCardMotif(
                      color: data.accentColor,
                      pressed: _pressed,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SettingsIconBadge(
                          icon: data.icon,
                          accentColor: data.accentColor,
                        ),
                        const Spacer(),
                        Text(
                          data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTitleMedium.copyWith(
                            color: context.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          data.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textBodySmall.copyWith(
                            color: context.secondaryColor,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsAmbientLight extends StatelessWidget {
  final Color color;
  final double opacity;
  final double size;

  const _SettingsAmbientLight({
    required this.color,
    required this.opacity,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * 0.3),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.5, 1],
          ),
        ),
      ),
    );
  }
}

class _SettingsIconBadge extends StatelessWidget {
  final IconData icon;
  final Color accentColor;

  const _SettingsIconBadge({required this.icon, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark
                ? 0.12
                : 0.34,
          ),
          width: 0.8,
        ),
      ),
      child: Icon(icon, color: context.primaryColor, size: 20),
    );
  }
}

class _SettingsCardMotif extends StatelessWidget {
  final Color color;
  final bool pressed;

  const _SettingsCardMotif({required this.color, required this.pressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            top: pressed ? 0 : 5,
            right: pressed ? 0 : 5,
            child: Transform.rotate(
              angle: pressed ? 0.15 : 0.1,
              child: _SettingsMotifTile(
                color: color.withValues(alpha: 0.44),
                size: 34,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            top: pressed ? 20 : 17,
            right: pressed ? 25 : 19,
            child: Transform.rotate(
              angle: pressed ? -0.18 : -0.11,
              child: _SettingsMotifTile(color: color, size: 38),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsMotifTile extends StatelessWidget {
  final Color color;
  final double size;

  const _SettingsMotifTile({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: color.a * 0.18 + 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.24),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
    );
  }
}
