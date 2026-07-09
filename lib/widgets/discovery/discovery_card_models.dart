import 'package:flutter/material.dart';

import '../../models/song.dart';

class DiscoveryCardData {
  final String title;
  final String subtitle;
  final DiscoveryCardStyle style;
  final List<Song> songs;

  const DiscoveryCardData({
    required this.title,
    required this.subtitle,
    required this.style,
    required this.songs,
  });
}

class DiscoveryScenario {
  final String title;
  final String subtitle;
  final List<String> tags;
  final DiscoveryCardStyle style;

  const DiscoveryScenario({
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.style,
  });

  static const presets = [
    DiscoveryScenario(
      title: '深夜独处',
      subtitle: '平静、忧郁与低能量的夜色',
      tags: ['深夜', '独处', '平静', '忧郁', '孤独'],
      style: DiscoveryCardStyle.midnight,
    ),
    DiscoveryScenario(
      title: '清晨轻听',
      subtitle: '清晨、轻松和一点治愈',
      tags: ['清晨', '轻松', '治愈', '温柔'],
      style: DiscoveryCardStyle.morning,
    ),
    DiscoveryScenario(
      title: '专注模式',
      subtitle: '学习、工作和低干扰旋律',
      tags: ['学习', '工作', '阅读', '纯音乐', '轻音乐'],
      style: DiscoveryCardStyle.focus,
    ),
    DiscoveryScenario(
      title: '路上听',
      subtitle: '驾驶、通勤与旅行的流动感',
      tags: ['驾驶', '通勤', '旅行', '欧美流行'],
      style: DiscoveryCardStyle.drive,
    ),
    DiscoveryScenario(
      title: '柔软回温',
      subtitle: '放松、浪漫和温柔情绪',
      tags: ['放松', '浪漫', '温柔', '治愈', 'R&B'],
      style: DiscoveryCardStyle.soft,
    ),
    DiscoveryScenario(
      title: '能量上升',
      subtitle: '跑步、健身和热血节拍',
      tags: ['跑步', '健身', '热血', '舞曲', '电子'],
      style: DiscoveryCardStyle.energy,
    ),
  ];
}

class DiscoveryCardStyle {
  final IconData icon;
  final List<Color> gradientColors;
  final Color accentColor;
  final Color glowColor;

  const DiscoveryCardStyle({
    required this.icon,
    required this.gradientColors,
    required this.accentColor,
    required this.glowColor,
  });

  static const midnight = DiscoveryCardStyle(
    icon: Icons.nightlight_round,
    gradientColors: [Color(0xFF252936), Color(0xFF171923), Color(0xFF2A2434)],
    accentColor: Color(0xFF94A3FF),
    glowColor: Color(0xFF756BFF),
  );

  static const morning = DiscoveryCardStyle(
    icon: Icons.wb_twilight_rounded,
    gradientColors: [Color(0xFFF1F4F7), Color(0xFFE9EEF4), Color(0xFFDCE8EF)],
    accentColor: Color(0xFF6CA6C9),
    glowColor: Color(0xFF8EC5D8),
  );

  static const focus = DiscoveryCardStyle(
    icon: Icons.center_focus_strong_rounded,
    gradientColors: [Color(0xFF242B2F), Color(0xFF182023), Color(0xFF263238)],
    accentColor: Color(0xFF91B7B0),
    glowColor: Color(0xFF5AAE9D),
  );

  static const drive = DiscoveryCardStyle(
    icon: Icons.route_rounded,
    gradientColors: [Color(0xFFEEF0F5), Color(0xFFE4E7EF), Color(0xFFDADDE8)],
    accentColor: Color(0xFF7E8DB8),
    glowColor: Color(0xFF8E9DDB),
  );

  static const soft = DiscoveryCardStyle(
    icon: Icons.favorite_border_rounded,
    gradientColors: [Color(0xFF28252E), Color(0xFF1B1A22), Color(0xFF312938)],
    accentColor: Color(0xFFD6A8C9),
    glowColor: Color(0xFFD985C0),
  );

  static const energy = DiscoveryCardStyle(
    icon: Icons.bolt_rounded,
    gradientColors: [Color(0xFF272B32), Color(0xFF191D23), Color(0xFF322D25)],
    accentColor: Color(0xFFF0C77A),
    glowColor: Color(0xFFF1A54B),
  );

  static const forgotten = DiscoveryCardStyle(
    icon: Icons.history_rounded,
    gradientColors: [Color(0xFFF5F5F6), Color(0xFFEAECEF), Color(0xFFE1E3E8)],
    accentColor: Color(0xFF8E96A6),
    glowColor: Color(0xFFB1B8C8),
  );

  static const roam = DiscoveryCardStyle(
    icon: Icons.shuffle_rounded,
    gradientColors: [Color(0xFF232932), Color(0xFF171B22), Color(0xFF1F2A32)],
    accentColor: Color(0xFF8CC7D0),
    glowColor: Color(0xFF5EC7D5),
  );

  bool get isLight =>
      gradientColors.first.computeLuminance() > 0.55 ||
      gradientColors.last.computeLuminance() > 0.55;
}
