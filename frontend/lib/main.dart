import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'providers/providers.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

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
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
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
