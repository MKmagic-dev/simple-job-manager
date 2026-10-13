import 'package:flutter/material.dart';

import '../../../core/config/branding_config.dart';

/// One section of a role's home screen (sidebar entry + overview card).
class HomeSection {
  const HomeSection({
    required this.icon,
    required this.label,
    required this.builder,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final int badgeCount;
  final WidgetBuilder builder;
}

/// One large section card: an ink-black icon block (the brand's black +
/// neon green), the section name, a live one-line summary, and an arrow.
class HomeTile extends StatelessWidget {
  const HomeTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            border: Border.all(
              color: BrandingConfig.accentColor.withValues(alpha: 0.35),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Badge(
                label: Text('$badgeCount'),
                isLabelVisible: badgeCount > 0,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: BrandingConfig.accentColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 30,
                    color: BrandingConfig.onAccentColor,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
