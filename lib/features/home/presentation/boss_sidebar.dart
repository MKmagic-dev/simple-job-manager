import 'package:flutter/material.dart';

import '../../../core/config/branding_config.dart';
import '../../../core/theme/app_theme.dart';

class BossSidebarDestination {
  const BossSidebarDestination({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final int badgeCount;
}

/// The permanent left-hand navigation column shown on wide (desktop/web)
/// screens — the boss's screens (team, projects, schedule, …) render in the
/// pane to its right instead of replacing the whole page, so this stays on
/// screen while the user moves between sections. See BossHomeScreen, which
/// falls back to the tile-grid dashboard + normal page navigation on narrow
/// (phone) screens where a fixed sidebar wouldn't fit.
class BossSidebar extends StatelessWidget {
  const BossSidebar({
    super.key,
    required this.userName,
    required this.signOutLabel,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAccountTap,
    required this.onSignOutTap,
  });

  final String userName;
  final String signOutLabel;
  final List<BossSidebarDestination> destinations;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAccountTap;
  final VoidCallback onSignOutTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppTheme.ink,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      BrandingConfig.logoAssetPath,
                      width: 36,
                      height: 36,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      BrandingConfig.appName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    _SidebarItem(
                      destination: destinations[i],
                      selected: selectedIndex == i,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            _SidebarActionItem(
              icon: Icons.account_circle_outlined,
              label: userName,
              onTap: onAccountTap,
            ),
            _SidebarActionItem(
              icon: Icons.logout,
              label: signOutLabel,
              onTap: onSignOutTap,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final BossSidebarDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = BrandingConfig.accentColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  size: 20,
                  color: selected ? accent : Colors.white70,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    destination.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (destination.badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${destination.badgeCount}',
                      style: TextStyle(
                        color: BrandingConfig.onAccentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarActionItem extends StatelessWidget {
  const _SidebarActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
