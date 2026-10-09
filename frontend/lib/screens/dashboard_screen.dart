import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../core/platform_info.dart';
import '../core/theme.dart';
import '../models/app_user.dart';
import '../providers/home_providers.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/grading_tile.dart';
import 'scan_screen.dart';

/// Welcome, the two main actions (Scan Copra on phones, Upload Image everywhere),
/// real classification counts, and the most recent classifications.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _openScanner(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ScanScreen()));
    ref.invalidate(dashboardProvider); // a new classification may have been saved
  }

  void _openUpload(WidgetRef ref) => ref.read(homeTabProvider.notifier).state = HomeTab.classify;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();
    final data = ref.watch(dashboardProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        try {
          await ref.read(dashboardProvider.future);
        } catch (_) {
          // the error is shown on the page
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          ResponsiveBody(
            maxWidth: 1040,
            child: Padding(
              padding: pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Welcome(user: user),
                  const SizedBox(height: 20),
                  if (user.isFarmer)
                    _Actions(
                      onScan: () => _openScanner(context, ref),
                      onUpload: () => _openUpload(ref),
                    )
                  else
                    const NoticeBanner(
                      'Buyer accounts can view classifications from all farmers in History. '
                      'Only farmers can classify new copra photos.',
                    ),
                  const SizedBox(height: 28),
                  const SectionHeader('Classification summary'),
                  const SizedBox(height: 12),
                  data.when(
                    loading: () => const _LoadingBlock(label: 'Loading summary...'),
                    error: (e, _) => _LoadError(
                      message: ApiException.from(e).message,
                      onRetry: () => ref.invalidate(dashboardProvider),
                    ),
                    data: (d) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Stats(data: d, buyer: user.isBuyer),
                        const SizedBox(height: 28),
                        SectionHeader(
                          'Recent classifications',
                          actionLabel: d.recent.isEmpty ? null : 'View all',
                          onAction: () => ref.read(homeTabProvider.notifier).state = HomeTab.history,
                        ),
                        const SizedBox(height: 12),
                        if (d.recent.isEmpty)
                          KCard(
                            child: StatePanel(
                              icon: Icons.photo_library_outlined,
                              title: 'No classifications yet',
                              message: user.isFarmer
                                  ? 'Scan or upload a copra photo and the result will appear here.'
                                  : 'Classifications will appear here once farmers start using KopraGrade.',
                              actionLabel: user.isFarmer ? 'Upload Image' : null,
                              actionIcon: Icons.upload_file_rounded,
                              onAction: user.isFarmer ? () => _openUpload(ref) : null,
                            ),
                          )
                        else
                          for (final g in d.recent) ...[
                            GradingTile(g, showFarmer: user.isBuyer),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = user.name.trim().split(RegExp(r'\s+')).first;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: KopraColors.forest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COPRA DRYING QUALITY CLASSIFICATION USING IMAGE PROCESSING',
            style: TextStyle(
              color: KopraColors.freshLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            header: true,
            child: Text(
              'Welcome, $first',
              style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'KopraGrade checks how well your copra is dried from a photo. '
            'It sorts each sample into ${AppConfig.grades[0]}, ${AppConfig.grades[1]} or ${AppConfig.grades[2]}, '
            'and keeps a history of every result.',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withAlpha(225)),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onScan, required this.onUpload});
  final VoidCallback onScan;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneDevice;
    final wide = MediaQuery.sizeOf(context).width >= 700;

    final upload = _ActionCard(
      icon: Icons.upload_file_rounded,
      title: 'Upload Image',
      body: 'Choose a copra photo from your ${phone ? 'phone' : 'computer'}, then classify it.',
      buttonLabel: 'Upload Image',
      onPressed: onUpload,
      primary: true,
    );
    if (!phone) return upload; // PCs and laptops: upload only, no camera scanner

    final scan = _ActionCard(
      icon: Icons.center_focus_strong_rounded,
      title: 'Scan Copra',
      body: 'Point your camera at one copra sample and take a photo to classify it.',
      buttonLabel: 'Scan Copra',
      onPressed: onScan,
      primary: true,
    );
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Expanded(child: scan), const SizedBox(width: 16), Expanded(child: upload)],
        ),
      );
    }
    return Column(children: [scan, const SizedBox(height: 12), upload]);
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
    required this.primary,
  });
  final IconData icon;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: KopraColors.soft, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: KopraColors.forest, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data, required this.buyer});
  final DashboardData data;
  final bool buyer;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _StatTile(
        icon: Icons.fact_check_outlined,
        color: KopraColors.forest,
        tint: KopraColors.soft,
        label: buyer ? 'Total classifications' : 'My classifications',
        value: data.total,
        caption: null,
      ),
      for (final grade in AppConfig.grades)
        _StatTile(
          icon: gradeIcon(grade),
          color: gradeColor(grade),
          tint: gradeTint(grade),
          label: grade,
          value: data.byGrade[grade] ?? 0,
          caption: data.total == 0 ? null : '${((data.byGrade[grade] ?? 0) * 100 / data.total).round()}% of total',
        ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        const gap = 12.0;
        final columns = box.maxWidth >= 720 ? 4 : 2;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.tint,
    required this.label,
    required this.value,
    required this.caption,
  });
  final IconData icon;
  final Color color;
  final Color tint;
  final String label;
  final int value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value${caption == null ? '' : ', $caption'}',
      child: ExcludeSemantics(
        child: KCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text('$value', style: theme.textTheme.headlineMedium?.copyWith(color: KopraColors.forest)),
              const SizedBox(height: 2),
              Text(label, style: theme.textTheme.titleSmall),
              if (caption != null) Text(caption!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: StatePanel(
        icon: Icons.cloud_off_rounded,
        isError: true,
        title: 'Could not load the summary',
        message: message,
        actionLabel: 'Try again',
        onAction: onRetry,
      ),
    );
  }
}
