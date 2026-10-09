import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'common.dart';

/// Shared frame for the Log in and Create account screens.
/// Wide screens: forest-green brand panel on the left, form on the right.
/// Phones: brand header on top, form card below.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();
    final theme = Theme.of(context);

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: theme.textTheme.headlineSmall?.copyWith(color: KopraColors.forest))),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: KopraColors.muted)),
        const SizedBox(height: 22),
        child,
      ],
    );

    if (isWideScreen(context)) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                color: KopraColors.forest,
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandMark(onDark: true, size: 56),
                    const SizedBox(height: 40),
                    Text(
                      'Know how well your copra is dried.',
                      style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 36),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Copra Drying Quality Classification Using Image Processing',
                      style: theme.textTheme.titleMedium?.copyWith(color: KopraColors.freshLight),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Text(
                        'Take or upload a photo and KopraGrade classifies it as Well-Dried, '
                        'Moderately Dried or Poorly Dried, then keeps a history of every result.',
                        style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withAlpha(225)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (canGoBack)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Back to log in'),
                              ),
                            ),
                          KCard(padding: const EdgeInsets.all(28), child: form),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: KopraColors.forest,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (canGoBack)
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      )
                    else
                      const SizedBox(height: 20),
                    const SizedBox(height: 4),
                    const BrandMark(onDark: true, size: 48),
                    const SizedBox(height: 14),
                    Text(
                      'Copra Drying Quality Classification Using Image Processing',
                      style: theme.textTheme.bodyMedium?.copyWith(color: KopraColors.freshLight),
                    ),
                  ],
                ),
              ),
            ),
            // The card overlaps the green header a little.
            Transform.translate(
              offset: const Offset(0, -32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: KCard(padding: const EdgeInsets.all(22), child: form),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
