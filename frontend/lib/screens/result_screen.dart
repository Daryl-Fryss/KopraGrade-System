import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';

/// Shows one grading: photo, grade, confidence and recommendation (GET /api/gradings/{id}).
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.gradingId, this.againLabel});
  final int gradingId;

  /// When set (right after a scan or an upload), a button with this text closes the result
  /// so the user can grade another sample. History does not set it.
  final String? againLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gradingProvider(gradingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Grading result')),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ErrorBanner(ApiException.from(e).message),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(gradingProvider(gradingId)),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          data: (g) {
            final color = gradeColor(g.grade);
            return ResponsiveBody(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: NetworkPhoto(g.imageUrl, height: 260, width: double.infinity),
                  ),
                  const SizedBox(height: 16),
                  Center(child: GradeBadge(g.grade, large: true)),
                  if (g.gradeDescription != null) ...[
                    const SizedBox(height: 8),
                    Text(g.gradeDescription!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 20),
                  Text('Confidence: ${g.confidence.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (g.confidence / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    color: color,
                    backgroundColor: Colors.black12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  if (g.needsReview) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF8F00)),
                          SizedBox(width: 8),
                          Expanded(child: Text('Low confidence: this result needs review. Try a clearer photo.')),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recommendation', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(g.recommendation ?? 'No recommendation available.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.tag),
                          title: const Text('Sample code'),
                          subtitle: Text(g.sampleCode),
                        ),
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: const Text('Farmer'),
                          subtitle: Text(g.farmerName),
                        ),
                        ListTile(
                          leading: const Icon(Icons.schedule),
                          title: const Text('Graded on'),
                          subtitle: Text(DateFormat('MMM d, y  h:mm a').format(g.classifiedAt)),
                        ),
                      ],
                    ),
                  ),
                  if (againLabel != null) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.refresh),
                      label: Text(againLabel!),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
