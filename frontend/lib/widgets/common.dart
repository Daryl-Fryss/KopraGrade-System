import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/home_providers.dart';
import '../providers/providers.dart';

/// Keeps content a readable width on big web screens, full width on phones.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 640});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Page padding used by every tab: roomier on wide screens.
EdgeInsets pagePadding(BuildContext context) => EdgeInsets.all(isWideScreen(context) ? 28 : 16);

/// White rounded card with a subtle border and shadow. The one card style for the whole app.
class KCard extends StatelessWidget {
  const KCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color = KopraColors.white,
    this.borderColor = KopraColors.border,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: borderColor),
        boxShadow: const [BoxShadow(color: Color(0x0F174D36), blurRadius: 12, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : Semantics(
                button: true,
                label: semanticLabel,
                child: InkWell(onTap: onTap, child: content),
              ),
      ),
    );
  }
}

/// KopraGrade logo: a leaf mark and the name. [onDark] is for the forest-green sidebar / headers.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.onDark = false, this.size = 40, this.showName = true, this.subtitle});
  final bool onDark;
  final double size;
  final bool showName;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onDark ? KopraColors.soft : KopraColors.forest,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(Icons.eco_rounded, size: size * 0.6, color: onDark ? KopraColors.forest : Colors.white),
    );
    if (!showName) return Semantics(label: 'KopraGrade', child: mark);

    final nameSize = size * 0.5;
    return Semantics(
      label: 'KopraGrade',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: mark),
          SizedBox(width: size * 0.28),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Kopra', style: TextStyle(color: onDark ? Colors.white : KopraColors.forest)),
                      TextSpan(text: 'Grade', style: TextStyle(color: onDark ? KopraColors.freshLight : KopraColors.fresh)),
                    ],
                  ),
                  style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w800, height: 1.1),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: onDark ? Colors.white70 : KopraColors.muted,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section heading with an optional action on the right (for example "View all").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        ),
        if (actionLabel != null && onAction != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KopraColors.redTint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KopraColors.red.withAlpha(90)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: KopraColors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: KopraColors.redText, height: 1.4))),
          ],
        ),
      ),
    );
  }
}

enum NoticeKind { success, warning, info }

/// Success / warning / info message box (for example "Classification completed.").
class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.message, {super.key, this.kind = NoticeKind.info});
  final String message;
  final NoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color line;
    final IconData icon;
    switch (kind) {
      case NoticeKind.success:
        bg = KopraColors.soft;
        fg = KopraColors.forest;
        line = KopraColors.fresh;
        icon = Icons.check_circle_rounded;
      case NoticeKind.warning:
        bg = KopraColors.amberTint;
        fg = KopraColors.amberText;
        line = KopraColors.amber;
        icon = Icons.warning_amber_rounded;
      case NoticeKind.info:
        bg = KopraColors.soft;
        fg = KopraColors.forest;
        line = KopraColors.fresh;
        icon = Icons.info_outline_rounded;
    }
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: line.withAlpha(110)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: line),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: fg, fontWeight: FontWeight.w600, height: 1.4))),
          ],
        ),
      ),
    );
  }
}

/// A friendly centered message for empty lists and failed loads.
class StatePanel extends StatelessWidget {
  const StatePanel({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tint = isError ? KopraColors.redTint : KopraColors.soft;
    final fg = isError ? KopraColors.red : KopraColors.forest;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: fg),
              ),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small round-cornered pill that names a drying-quality class, with its own icon and color.
class GradeBadge extends StatelessWidget {
  const GradeBadge(this.grade, {super.key, this.large = false});
  final String grade;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = gradeTextColor(grade);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 16 : 10, vertical: large ? 8 : 4),
      decoration: BoxDecoration(
        color: gradeTint(grade),
        border: Border.all(color: gradeColor(grade).withAlpha(140)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(gradeIcon(grade), size: large ? 22 : 15, color: gradeColor(grade)),
          SizedBox(width: large ? 8 : 5),
          Flexible(
            child: Text(
              grade,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: large ? 20 : 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small helper so every screen shows a photo the same way (with a fallback icon).
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto(this.url, {super.key, this.height, this.width, this.fit = BoxFit.cover});
  final String url;
  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      height: height,
      width: width,
      fit: fit,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              height: height,
              width: width,
              color: KopraColors.soft,
              child: const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
            ),
      errorBuilder: (context, error, stack) => Container(
        height: height,
        width: width,
        color: KopraColors.page,
        child: const Icon(Icons.broken_image_outlined, color: KopraColors.muted),
      ),
    );
  }
}

/// Round avatar with the first letter of the name.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.name, {super.key, this.size = 44, this.onDark = false});
  final String name;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first).toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: onDark ? KopraColors.soft : KopraColors.forest, shape: BoxShape.circle),
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            color: onDark ? KopraColors.forest : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Asks "Log out?" and logs out if the user agrees.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Log out?'),
      content: const Text('You will need to log in again to classify copra or see your history.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (sure == true) {
    ref.read(homeTabProvider.notifier).state = HomeTab.dashboard;
    await ref.read(authProvider.notifier).logout();
  }
}
