import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'providers/providers.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'widgets/common.dart';

void main() {
  runApp(const ProviderScope(child: KopraGradeApp()));
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class KopraGradeApp extends ConsumerWidget {
  const KopraGradeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // When the user logs out (or the session expires) close any screens still open on top.
    ref.listen(authProvider, (previous, next) {
      if (previous?.user != null && next.user == null) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });

    final auth = ref.watch(authProvider);
    final Widget home;
    if (auth.initializing) {
      home = const _Splash();
    } else if (auth.user == null) {
      home = const LoginScreen();
    } else {
      home = const HomeShell();
    }

    return MaterialApp(
      title: 'KopraGrade',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: buildTheme(),
      home: home,
    );
  }
}

/// Shown for a moment while a saved login is being checked.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: KopraColors.forest,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(onDark: true, size: 56),
            SizedBox(height: 28),
            SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
