import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../core/platform_info.dart';
import '../core/validators.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import 'result_screen.dart';
import 'scan_screen.dart';

/// Farmers: grade copra. Phones get "Scan Copra" (live camera) AND "Upload Photo";
/// PCs and laptops get "Upload Photo" only. Both go to the same grading API.
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

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      // On a phone this opens the gallery / file picker, on a PC the file chooser.
      final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 90);
      if (file == null) return; // the user cancelled
      final bytes = await file.readAsBytes();
      final kind = detectImageKind(bytes);
      if (kind == null) {
        setState(() => _error = 'Please choose a JPG or PNG photo.');
        return;
      }
      if (bytes.length > AppConfig.maxImageBytes) {
        setState(() => _error = 'That photo is too large (max 5 MB). Please choose a smaller one.');
        return;
      }
      setState(() {
        _bytes = bytes;
        _kind = kind;
      });
    } catch (_) {
      setState(() => _error = 'Could not open the photo. Please try again.');
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

  Future<void> _grade() async {
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
          builder: (_) => ResultScreen(gradingId: grading.id, againLabel: 'Upload Another Photo'),
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
    final scheme = Theme.of(context).colorScheme;
    final phone = isPhoneDevice;
    final hasPhoto = _bytes != null;
    return ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            phone ? 'Ready to Grade Copra?' : 'Upload a Copra Photo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(phone
              ? 'Scan a copra sample with your camera, or upload a photo. Good daylight gives the best result.'
              : 'Choose a clear photo of the dried copra, taken in good daylight.'),
          const SizedBox(height: 16),
          if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: !hasPhoto
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_camera_outlined, size: 56, color: scheme.outline),
                        const SizedBox(height: 8),
                        const Text('No photo selected yet'),
                      ],
                    )
                  : Image.memory(_bytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          if (!hasPhoto) ...[
            // The scanner button only exists on phones. On a PC/laptop it is not built at all.
            if (phone) ...[
              FilledButton.icon(
                onPressed: _busy ? null : _openScanner,
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Scan Copra'),
              ),
              const SizedBox(height: 12),
            ],
            if (phone)
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.photo_library),
                label: const Text('Upload Photo'),
              )
            else
              FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Photo'),
              ),
          ] else ...[
            FilledButton.icon(
              onPressed: _busy ? null : _grade,
              icon: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.analytics_outlined),
              label: Text(_busy ? 'Grading...' : 'Grade this copra'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _clear,
              icon: const Icon(Icons.close),
              label: const Text('Choose a different photo'),
            ),
          ],
        ],
      ),
    );
  }
}
