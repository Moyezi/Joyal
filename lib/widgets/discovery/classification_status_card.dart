import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../config/theme_context.dart';

class ClassificationStatusCard extends StatelessWidget {
  final String statusText;
  final String detailText;
  final double progress;
  final VoidCallback onTap;

  const ClassificationStatusCard({
    super.key,
    required this.statusText,
    required this.detailText,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        AppTheme.spacingLG,
        AppTheme.spacingMD,
        0,
      ),
      child: Material(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.backgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: context.primaryColor,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusText, style: context.textTitleMedium),
                      const SizedBox(height: 3),
                      Text(
                        detailText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textBodySmall,
                      ),
                      if (progress > 0 && progress < 1) ...[
                        const SizedBox(height: AppTheme.spacingSM),
                        LinearProgressIndicator(value: progress),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
