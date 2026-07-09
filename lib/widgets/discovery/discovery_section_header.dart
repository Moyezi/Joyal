import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../config/theme_context.dart';

class DiscoverySectionHeader extends StatelessWidget {
  final String title;

  const DiscoverySectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        AppTheme.spacingLG,
        AppTheme.spacingMD,
        AppTheme.spacingSM,
      ),
      child: Text(title, style: context.textTitleLarge),
    );
  }
}
