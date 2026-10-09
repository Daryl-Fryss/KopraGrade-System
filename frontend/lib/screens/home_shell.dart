import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/app_user.dart';
import '../providers/home_providers.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'upload_screen.dart';

class _NavItem {
  const _NavItem({
    required this.tab,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selectedIcon,
  });
  final HomeTab tab;
  final String label; // short name for the navigation
  final String title; // page title
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;
}

List<_NavItem> _itemsFor(AppUser user) => [
      const _NavItem(
        tab: HomeTab.dashboard,
        label: 'Dashboard',
        title: 'Dashboard',
        subtitle: 'Copra Drying Quality Classification Using Image Processing',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
      ),
      if (user.isFarmer)
        const _NavItem(
          tab: HomeTab.classify,
          label: 'Classify',
          title: 'Classify Copra',
          subtitle: 'Scan or upload a photo to check how well the copra is dried.',
          icon: Icons.center_focus_strong_outlined,
          selectedIcon: Icons.center_focus_strong_rounded,
        ),
      _NavItem(
        tab: HomeTab.history,
        label: 'History',
        title: user.isBuyer ? 'Classification History (all farmers)' : 'Classification History',
        subtitle: 'Every classification saved by the system.',
        icon: Icons.history_rounded,
        selectedIcon: Icons.history_rounded,
      ),
      const _NavItem(
        tab: HomeTab.profile,
        label: 'Profile',
        title: 'Profile',
        subtitle: 'Your account details.',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];

Widget _pageFor(HomeTab tab) {
  switch (tab) {
    case HomeTab.dashboard:
      return const DashboardScreen();
    case HomeTab.classify:
      return const UploadScreen();
    case HomeTab.history:
      return const HistoryScreen();
    case HomeTab.profile:
      return const ProfileScreen();
  }
}

/// Main screen after login. Wide screens (laptop / desktop web) get a forest-green sidebar;
/// phones get a header and a bottom navigation bar.
/// Farmers get Dashboard / Classify / History / Profile, buyers get Dashboard / History / Profile.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final items = _itemsFor(user);
    final requested = ref.watch(homeTabProvider);
    final current = items.firstWhere((i) => i.tab == requested, orElse: () => items.first);
    // Only the open tab is built, so each tab reloads its data every time it is opened.
    final page = KeyedSubtree(key: ValueKey(current.tab), child: _pageFor(current.tab));

    void select(HomeTab tab) => ref.read(homeTabProvider.notifier).state = tab;

    if (isWideScreen(context)) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(user: user, items: items, current: current.tab, onSelect: select),
            Expanded(
              child: Column(
                children: [
                  _PageHeader(title: current.title, subtitle: current.subtitle),
                  Expanded(child: page),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final index = items.indexOf(current);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const BrandMark(onDark: true, size: 32, showName: false),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                current.tab == HomeTab.dashboard ? 'KopraGrade' : current.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(top: false, child: page),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => select(items[i].tab),
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.user, required this.items, required this.current, required this.onSelect});
  final AppUser user;
  final List<_NavItem> items;
  final HomeTab current;
  final ValueChanged<HomeTab> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 264,
      color: KopraColors.forest,
      child: SafeArea(
        // Scrolls instead of overflowing on short windows (for example a phone held sideways).
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight > 40 ? box.maxHeight - 40 : 0.0),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: BrandMark(onDark: true, size: 44, subtitle: 'Copra drying quality'),
                    ),
                    const SizedBox(height: 32),
                    for (final item in items) ...[
                      _SidebarItem(item: item, selected: item.tab == current, onTap: () => onSelect(item.tab)),
                      const SizedBox(height: 6),
                    ],
                    const Spacer(),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          InitialAvatar(user.name, onDark: true),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  user.isFarmer ? 'Farmer' : 'Buyer',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.white, alignment: Alignment.centerLeft),
                      onPressed: () => confirmLogout(context, ref),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Log out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.item, required this.selected, required this.onTap});
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? KopraColors.forest : Colors.white.withAlpha(225);
    return Semantics(
      selected: selected,
      button: true,
      label: item.title,
      child: Material(
        color: selected ? KopraColors.soft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.white.withAlpha(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(selected ? item.selectedIcon : item.icon, color: fg, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label == 'Classify' ? 'Classify Copra' : item.label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 16,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      ),
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

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: KopraColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.headlineSmall?.copyWith(color: KopraColors.forest)),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: KopraColors.muted)),
        ],
      ),
    );
  }
}
