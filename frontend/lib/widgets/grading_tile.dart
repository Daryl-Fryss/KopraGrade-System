import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/grading.dart';
import '../screens/result_screen.dart';
import 'common.dart';

/// One past classification: thumbnail, class, date and time. Opens the detailed result.
/// Used by both the Dashboard ("Recent classifications") and the History page.
class GradingTile extends StatelessWidget {
  const GradingTile(this.g, {super.key, this.showFarmer = false});
  final Grading g;
  final bool showFarmer;

  @override
  Widget build(BuildContext context) {
    final when = DateFormat('MMM d, y  •  h:mm a').format(g.classifiedAt);
    return KCard(
      padding: const EdgeInsets.all(12),
      semanticLabel: 'Open details for ${g.sampleCode}, ${g.grade}, $when',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(gradingId: g.id, source: ResultSource.history),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: NetworkPhoto(g.imageUrl, height: 76, width: 76),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.sampleCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(child: GradeBadge(g.grade)),
                    if (g.needsReview) ...[
                      const SizedBox(width: 8),
                      const Tooltip(
                        message: 'Low confidence: needs review',
                        child: Icon(Icons.warning_amber_rounded, size: 20, color: KopraColors.amber),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  showFarmer ? '$when  •  ${g.farmerName}' : when,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: KopraColors.muted),
        ],
      ),
    );
  }
}
