import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../core/file_drop.dart';
import '../core/platform_info.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import 'result_screen.dart';
import 'scan_screen.dart';

/// Farmers: classify copra. Phones get "Scan Copra" (live camera) AND "Upload Image";
/// PCs and laptops get image upload only (Choose File, or drag and drop on the web).
/// Both go to the same classification API.
class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _picker = ImagePicker();
  Uint8List? _bytes;
  String? _kind; // 'jpg' or 'png'
  String? _error;
  bool _busy = false;
  bool _dragging = false;
  FileDropListener? _drop;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _drop = FileDropListener(
        maxBytes: AppConfig.maxImageBytes,
        onDragChanged: (dragging) {
          if (mounted && !_busy && _dragging != dragging) setState(() => _dragging = dragging);
        },
        onFile: (bytes) {
          if (mounted && !_busy) _accept(bytes);
        },
        onError: (message) {
          if (mounted) {
            setState(() {
              _dragging = false;
              _error = message;
            });
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _drop?.dispose();
    super.dispose();
  }

  /// Checks a chosen or dropped photo the same way the API will: real JPG/PNG and at most 5 MB.
  void _accept(Uint8List bytes) {
    final kind = detectImageKind(bytes);
    if (kind == null) {
      setState(() => _error = 'Unsupported image. Please choose a JPG or PNG photo.');
      return;
    }
    if (bytes.length > AppConfig.maxImageBytes) {
      setState(() => _error = 'That photo is too large (max 5 MB). Please choose a smaller one.');
      return;
    }
    setState(() {
      _bytes = bytes;
      _kind = kind;
      _error = null;
    });
  }

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      // On a phone this opens the gallery / file picker, on a PC the file chooser.
      final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 90);
      if (file == null) return; // the user cancelled
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      _accept(bytes);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the photo. Please try again.');
    }
  }

  void _openScanner() {
    setState(() => _error = null);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ScanScreen()));
  }

  void _clear() => setState(() {
        _bytes = null;
        _kind = null;
        _error = null;
      });

  Future<void> _classify() async {
    final bytes = _bytes;
    final kind = _kind;
    if (bytes == null || kind == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final grading = await ref.read(gradingServiceProvider).upload(bytes, kind);
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _kind = null;
      });
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(gradingId: grading.id, source: ResultSource.upload),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneDevice;
    final hasPhoto = _bytes != null;
    return ResponsiveBody(
      maxWidth: 820,
      child: ListView(
        padding: pagePadding(context),
        children: [
          if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
          if (phone && !hasPhoto) ...[
            FilledButton.icon(
              onPressed: _busy ? null : _openScanner,
              icon: const Icon(Icons.center_focus_strong_rounded),
              label: const Text('Scan Copra'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
            ),
            const SizedBox(height: 14),
            const _OrDivider(),
            const SizedBox(height: 14),
          ],
          if (!hasPhoto)
            _DropZone(
              phone: phone,
              dragging: _dragging,
              onChoose: _busy ? null : _pick,
            )
          else
            _Preview(
              bytes: _bytes!,
              kind: _kind ?? 'jpg',
              busy: _busy,
              onClassify: _classify,
              onReplace: _pick,
              onRemove: _clear,
            ),
          const SizedBox(height: 20),
          const _Tips(),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// The empty state: a dashed upload area with an image icon and a Choose File button.
class _DropZone extends StatelessWidget {
  const _DropZone({required this.phone, required this.dragging, required this.onChoose});
  final bool phone;
  final bool dragging;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDrag = kIsWeb && !phone;
    final title = dragging
        ? 'Drop the image to select it'
        : canDrag
            ? 'Drag and drop a copra photo here'
            : 'No image selected';
    return Semantics(
      container: true,
      label: 'Image upload area. No image selected.',
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: dragging ? KopraColors.fresh : const Color(0xFF9DB5A5),
          strokeWidth: dragging ? 3 : 2,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
          decoration: BoxDecoration(
            color: dragging ? KopraColors.soft : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(color: KopraColors.soft, shape: BoxShape.circle),
                child: const Icon(Icons.add_photo_alternate_outlined, size: 46, color: KopraColors.forest),
              ),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'JPG or PNG, up to ${AppConfig.maxImageBytes ~/ (1024 * 1024)} MB',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 22),
              if (canDrag) ...[
                Text('or', style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
              ],
              FilledButton.icon(
                onPressed: onChoose,
                icon: Icon(phone ? Icons.photo_library_rounded : Icons.upload_file_rounded),
                label: Text(phone ? 'Upload Image' : 'Choose File'),
                style: FilledButton.styleFrom(minimumSize: const Size(220, 56)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A selected photo, ready to classify (or being processed).
class _Preview extends StatelessWidget {
  const _Preview({
    required this.bytes,
    required this.kind,
    required this.busy,
    required this.onClassify,
    required this.onReplace,
    required this.onRemove,
  });
  final Uint8List bytes;
  final String kind;
  final bool busy;
  final VoidCallback onClassify;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  String get _size {
    final kb = bytes.length / 1024;
    return kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.round()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KCard(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Semantics(
                        image: true,
                        label: 'Selected copra photo',
                        child: ColoredBox(
                          color: KopraColors.page,
                          child: Image.memory(bytes, fit: BoxFit.contain),
                        ),
                      ),
                      if (busy)
                        ColoredBox(
                          color: const Color(0xB3174D36),
                          child: Center(
                            child: Semantics(
                              liveRegion: true,
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Colors.white),
                                  SizedBox(height: 14),
                                  Text(
                                    'Processing image...',
                                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: KopraColors.fresh, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Image selected  •  ${kind.toUpperCase()}  •  $_size',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : onClassify,
          icon: busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Icon(Icons.analytics_outlined),
          label: Text(busy ? 'Processing image...' : 'Classify Image'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onReplace,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Replace Image'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: KopraColors.redText,
                  side: const BorderSide(color: KopraColors.red, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const tips = [
      (Icons.wb_sunny_outlined, 'Take the photo in good daylight, away from harsh shadows.'),
      (Icons.crop_free_rounded, 'Fill the frame with one copra sample.'),
      (Icons.center_focus_strong_outlined, 'Keep the camera steady so the photo is sharp.'),
    ];
    return KCard(
      color: KopraColors.soft,
      borderColor: const Color(0xFFCFE5D3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tips for a clear photo', style: theme.textTheme.titleMedium?.copyWith(color: KopraColors.forest)),
          const SizedBox(height: 10),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(tip.$1, size: 22, color: KopraColors.forest),
                  const SizedBox(width: 12),
                  Expanded(child: Text(tip.$2, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Draws the dashed rounded outline of the upload area.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    const dash = 10.0;
    const gap = 7.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + dash < metric.length ? distance + dash : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.strokeWidth != strokeWidth;
}
