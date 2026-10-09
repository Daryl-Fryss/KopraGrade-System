import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/platform_info.dart';
import '../core/theme.dart';
import '../models/grading.dart';
import '../providers/home_providers.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import 'scan_screen.dart';

/// Where the result screen was opened from. It decides which buttons are shown.
enum ResultSource { scan, upload, history }

/// Shows one classification: photo, drying quality, confidence and recommendation
/// (GET /api/gradings/{id}).
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.gradingId, this.source = ResultSource.history});
  final int gradingId;
  final ResultSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gradingProvider(gradingId));
    return Scaffold(
      appBar: AppBar(
        title: Text(source == ResultSource.history ? 'Classification Details' : 'Classification Result'),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('Loading result...'),
              ],
            ),
          ),
          error: (e, _) => StatePanel(
            icon: Icons.cloud_off_rounded,
            isError: true,
            title: 'Could not load this result',
            message: ApiException.from(e).message,
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(gradingProvider(gradingId)),
          ),
          data: (g) => _ResultBody(g: g, source: source),
        ),
      ),
    );
  }
}

class _ResultBody extends ConsumerWidget {
  const _ResultBody({required this.g, required this.source});
  final Grading g;
  final ResultSource source;

  void _goTab(WidgetRef ref, NavigatorState nav, HomeTab tab) {
    ref.read(homeTabProvider.notifier).state = tab;
    nav.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 840;

    final photo = _PhotoCard(g: g);
    final details = _Details(g: g, source: source, actions: _actions(context, ref));

    return ResponsiveBody(
      maxWidth: 1040,
      child: ListView(
        padding: pagePadding(context),
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: photo),
                const SizedBox(width: 24),
                Expanded(flex: 6, child: details),
              ],
            )
          else ...[
            photo,
            const SizedBox(height: 16),
            details,
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref) {
    // Grab the navigator now: the buttons below close this screen before they act.
    final nav = Navigator.of(context);
    final farmer = ref.watch(authProvider).user?.isFarmer ?? false;

    final List<Widget> buttons;
    switch (source) {
      case ResultSource.scan:
        buttons = [
          FilledButton.icon(
            onPressed: () => nav.pop(), // back to the live camera, started fresh
            icon: const Icon(Icons.center_focus_strong_rounded),
            label: const Text('Scan Again'),
          ),
          OutlinedButton.icon(
            onPressed: () => _goTab(ref, nav, HomeTab.classify),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload Another Image'),
          ),
          TextButton.icon(
            onPressed: () => _goTab(ref, nav, HomeTab.history),
            icon: const Icon(Icons.history_rounded),
            label: const Text('View History'),
          ),
        ];
      case ResultSource.upload:
        buttons = [
          FilledButton.icon(
            onPressed: () => nav.pop(), // back to the upload area, which is empty again
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload Another Image'),
          ),
          if (isPhoneDevice)
            OutlinedButton.icon(
              onPressed: () {
                nav.popUntil((route) => route.isFirst);
                nav.push(MaterialPageRoute<void>(builder: (_) => const ScanScreen()));
              },
              icon: const Icon(Icons.center_focus_strong_rounded),
              label: const Text('Scan Again'),
            ),
          TextButton.icon(
            onPressed: () => _goTab(ref, nav, HomeTab.history),
            icon: const Icon(Icons.history_rounded),
            label: const Text('View History'),
          ),
        ];
      case ResultSource.history:
        buttons = [
          OutlinedButton.icon(
            onPressed: () => nav.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to History'),
          ),
          if (farmer)
            FilledButton.icon(
              onPressed: () => _goTab(ref, nav, HomeTab.classify),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Classify Another Image'),
            ),
        ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          buttons[i],
        ],
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.g});
  final Grading g;

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.all(10),
      child: Semantics(
        label: 'Photo of the copra sample ${g.sampleCode}',
        image: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ColoredBox(
              color: KopraColors.page,
              child: NetworkPhoto(g.imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.g, required this.source, required this.actions});
  final Grading g;
  final ResultSource source;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = gradeColor(g.grade);
    final confidence = g.confidence.clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (source != ResultSource.history) ...[
          const NoticeBanner('Classification completed.', kind: NoticeKind.success),
          const SizedBox(height: 14),
        ],
        Semantics(
          header: true,
          child: Text('Classification Result', style: theme.textTheme.titleMedium?.copyWith(color: KopraColors.muted)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: gradeTint(g.grade),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(gradeIcon(g.grade), size: 44, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Predicted drying quality',
                        style: theme.textTheme.bodySmall?.copyWith(color: gradeTextColor(g.grade))),
                    const SizedBox(height: 2),
                    Text(
                      g.grade,
                      style: theme.textTheme.headlineSmall?.copyWith(color: gradeTextColor(g.grade)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (g.gradeDescription != null) ...[
          const SizedBox(height: 12),
          Text(g.gradeDescription!, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 16),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Model confidence', style: theme.textTheme.titleMedium)),
                  Text(
                    '${confidence.toStringAsFixed(1)}%',
                    style: theme.textTheme.titleLarge?.copyWith(color: gradeTextColor(g.grade)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Semantics(
                label: 'Model confidence ${confidence.toStringAsFixed(1)} percent',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: confidence / 100,
                    minHeight: 10,
                    color: color,
                    backgroundColor: KopraColors.page,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This is the model's estimate for this photo. It is not a guarantee of accuracy.",
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (g.needsReview) ...[
          const SizedBox(height: 12),
          const NoticeBanner(
            'Low confidence: this result needs review. Try a clearer photo in good daylight.',
            kind: NoticeKind.warning,
          ),
        ],
        const SizedBox(height: 12),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: KopraColors.fresh),
                  const SizedBox(width: 8),
                  Text('Recommendation', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              Text(g.recommendation ?? 'No recommendation available.', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 12),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              _InfoRow(icon: Icons.tag_rounded, label: 'Sample code', value: g.sampleCode),
              const Divider(),
              _InfoRow(icon: Icons.person_outline_rounded, label: 'Farmer', value: g.farmerName),
              const Divider(),
              _InfoRow(
                icon: Icons.schedule_rounded,
                label: 'Classified on',
                value: DateFormat('MMM d, y  •  h:mm a').format(g.classifiedAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        actions,
        const SizedBox(height: 8),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: KopraColors.muted, size: 22),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
