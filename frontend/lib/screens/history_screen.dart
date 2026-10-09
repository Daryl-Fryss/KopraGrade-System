import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/grading.dart';
import '../providers/history_controller.dart';
import '../providers/home_providers.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/grading_tile.dart';

/// Farmers see their own classifications, buyers see everyone's (the API decides).
/// Filtering by class and date is done by the API; the search box looks through the loaded records.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickRange(HistoryState s) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: s.range,
    );
    if (picked != null) ref.read(historyProvider.notifier).setRange(picked);
  }

  bool _matches(Grading g, bool isBuyer) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return g.sampleCode.toLowerCase().contains(q) ||
        g.grade.toLowerCase().contains(q) ||
        (isBuyer && g.farmerName.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final controller = ref.read(historyProvider.notifier);
    final isBuyer = ref.watch(authProvider).user?.isBuyer ?? false;
    final day = DateFormat('MMM d');
    final theme = Theme.of(context);

    return ResponsiveBody(
      maxWidth: 880,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pagePadding(context).left, pagePadding(context).top, pagePadding(context).right, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: isBuyer ? 'Search by sample code or farmer' : 'Search by sample code',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: state.grade == null,
                        onTap: () => controller.setGrade(null),
                      ),
                      for (final grade in AppConfig.grades) ...[
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: grade,
                          icon: gradeIcon(grade),
                          iconColor: gradeColor(grade),
                          selected: state.grade == grade,
                          onTap: () => controller.setGrade(grade),
                        ),
                      ],
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.date_range_rounded, size: 18, color: KopraColors.forest),
                        label: Text(
                          state.range == null
                              ? 'Any date'
                              : '${day.format(state.range!.start)} - ${day.format(state.range!.end)}',
                        ),
                        labelStyle: TextStyle(
                          fontWeight: state.range == null ? FontWeight.w600 : FontWeight.w800,
                          color: KopraColors.forest,
                        ),
                        backgroundColor: state.range == null ? Colors.white : KopraColors.soft,
                        side: BorderSide(color: state.range == null ? KopraColors.border : KopraColors.fresh),
                        onPressed: () => _pickRange(state),
                      ),
                      if (state.hasFilters) ...[
                        const SizedBox(width: 4),
                        TextButton(onPressed: controller.clearFilters, child: const Text('Clear filters')),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (!state.loading || state.items.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${state.total} ${state.total == 1 ? 'classification' : 'classifications'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
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
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading history...'),
          ],
        ),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return StatePanel(
        icon: Icons.cloud_off_rounded,
        isError: true,
        title: 'Could not load history',
        message: state.error,
        actionLabel: 'Try again',
        onAction: controller.refresh,
      );
    }
    if (state.items.isEmpty) {
      if (state.hasFilters) {
        return StatePanel(
          icon: Icons.filter_alt_off_outlined,
          title: 'No classifications match these filters',
          message: 'Try a different class or date range.',
          actionLabel: 'Clear filters',
          actionIcon: Icons.filter_alt_off_rounded,
          onAction: controller.clearFilters,
        );
      }
      final farmer = !isBuyer;
      return StatePanel(
        icon: Icons.history_rounded,
        title: 'No classifications yet',
        message: farmer
            ? 'Your classified copra photos will be saved here.'
            : 'Classifications will appear here once farmers start using KopraGrade.',
        actionLabel: farmer ? 'Classify Copra' : null,
        actionIcon: Icons.center_focus_strong_rounded,
        onAction: farmer ? () => ref.read(homeTabProvider.notifier).state = HomeTab.classify : null,
      );
    }

    final visible = state.items.where((g) => _matches(g, isBuyer)).toList();
    final searching = _query.trim().isNotEmpty;

    if (visible.isEmpty) {
      return ListView(
        padding: pagePadding(context),
        children: [
          StatePanel(
            icon: Icons.search_off_rounded,
            title: 'No matches for "${_query.trim()}"',
            message: state.hasMore
                ? 'Only the ${state.items.length} loaded records were searched. Load more to search further.'
                : 'Check the spelling or try another sample code.',
            actionLabel: state.hasMore ? 'Load more' : null,
            actionIcon: Icons.expand_more_rounded,
            onAction: state.hasMore ? controller.loadMore : null,
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pagePadding(context),
        itemCount: visible.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == visible.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: state.loadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.error != null) ...[ErrorBanner(state.error!), const SizedBox(height: 8)],
                        if (searching)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Search covers the ${state.items.length} loaded records.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: controller.loadMore,
                          icon: const Icon(Icons.expand_more_rounded),
                          label: const Text('Load more'),
                        ),
                      ],
                    ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GradingTile(visible[i], showFarmer: isBuyer),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: icon == null ? null : Icon(icon, size: 18, color: iconColor),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: KopraColors.forest,
      ),
      selectedColor: KopraColors.soft,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? KopraColors.fresh : KopraColors.border, width: selected ? 1.5 : 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    );
  }
}
