import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/config.dart';
import '../models/grading.dart';
import '../providers/history_controller.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

/// Farmers see their own gradings, buyers see everyone's (the API decides).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _pickRange(BuildContext context, WidgetRef ref, HistoryState s) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: s.range,
    );
    if (picked != null) ref.read(historyProvider.notifier).setRange(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyProvider);
    final controller = ref.read(historyProvider.notifier);
    final isBuyer = ref.watch(authProvider).user?.isBuyer ?? false;
    final day = DateFormat('MMM d');

    return ResponsiveBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String?>(
                  value: state.grade,
                  hint: const Text('All grades'),
                  onChanged: controller.setGrade,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All grades')),
                    ...AppConfig.grades.map((g) => DropdownMenuItem<String?>(value: g, child: Text(g))),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickRange(context, ref, state),
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(state.range == null
                      ? 'Any date'
                      : '${day.format(state.range!.start)} - ${day.format(state.range!.end)}'),
                ),
                if (state.hasFilters)
                  TextButton(onPressed: controller.clearFilters, child: const Text('Clear filters')),
              ],
            ),
          ),
          Expanded(child: _body(context, state, controller, isBuyer)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, HistoryState state, HistoryController controller, bool isBuyer) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorBanner(state.error!),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: controller.refresh, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.hasFilters ? 'No results match these filters.' : 'No gradings yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == state.items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: state.loadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : OutlinedButton(onPressed: controller.loadMore, child: const Text('Load more')),
            );
          }
          return _HistoryTile(state.items[i], showFarmer: isBuyer);
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.g, {required this.showFarmer});
  final Grading g;
  final bool showFarmer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(gradingId: g.id))),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: NetworkPhoto(g.imageUrl, height: 72, width: 72),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.sampleCode, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        GradeBadge(g.grade),
                        const SizedBox(width: 8),
                        Text('${g.confidence.toStringAsFixed(0)}%'),
                        if (g.needsReview) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFEF8F00)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('MMM d, y').format(g.classifiedAt)}${showFarmer ? '  •  ${g.farmerName}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
