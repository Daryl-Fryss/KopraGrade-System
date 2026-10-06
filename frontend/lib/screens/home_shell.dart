import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'upload_screen.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

/// Main screen after login. Farmers get Grade / History / Profile, buyers get History / Profile.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final tabs = <_Tab>[
      if (user.isFarmer) const _Tab('Grade', Icons.photo_camera_outlined, UploadScreen()),
      _Tab(user.isBuyer ? 'Gradings' : 'History', Icons.history, const HistoryScreen()),
      const _Tab('Profile', Icons.person_outline, ProfileScreen()),
    ];
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(title: Text(tabs[index].label == 'Grade' ? 'KopraGrade' : tabs[index].label)),
      body: SafeArea(child: tabs[index].page), // only the open tab is built, so History reloads on each visit
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in tabs) NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}
