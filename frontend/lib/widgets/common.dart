import 'package:flutter/material.dart';
import '../core/theme.dart';

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

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer))),
        ],
      ),
    );
  }
}

class GradeBadge extends StatelessWidget {
  const GradeBadge(this.grade, {super.key, this.large = false});
  final String grade;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = gradeColor(grade);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 16 : 10, vertical: large ? 8 : 4),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        grade,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: large ? 20 : 13),
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
          : SizedBox(height: height, width: width, child: const Center(child: CircularProgressIndicator())),
      errorBuilder: (context, error, stack) => Container(
        height: height,
        width: width,
        color: Colors.black12,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
