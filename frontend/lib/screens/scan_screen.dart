import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../core/frame_steadiness.dart';
import '../core/validators.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

enum _Phase { starting, ready, capturing, grading, blocked }

/// Phones only: live camera with a scanning frame, like a QR scanner.
///
/// When the camera is held steady over something, it takes ONE photo and sends it to the
/// same grading endpoint as "Upload Photo" (GradingService.upload -> POST /api/classification/predict).
/// The backend model does the grading. The Capture button is always there as a fallback.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with WidgetsBindingObserver {
  static const _sampleEvery = Duration(milliseconds: 250);

  final _detector = SteadinessDetector();
  CameraController? _controller;
  _Phase _phase = _Phase.starting;

  // Goes up every time the camera is stopped or started, so a slow start that finishes
  // late can notice it is out of date and clean up after itself.
  int _epoch = 0;
  Future<void>? _startFuture;

  bool _resultOpen = false; // the result screen is on top, so the camera must stay off
  bool _requestInFlight = false; // one photo at a time: this is what stops duplicate scans
  bool _autoAvailable = false; // automatic detection works on this device/browser
  bool _autoPaused = false; // paused after a server problem; Capture still works
  DateTime _lastSample = DateTime.fromMillisecondsSinceEpoch(0);
  SteadyReading _reading = const SteadyReading.idle();

  String? _banner; // short message shown above the Capture button
  String _blockedMessage = '';
  bool _canRetry = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_startCamera()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_releaseCamera(rebuild: false)); // leaving the screen frees the camera
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Also covers coming back from the phone's Settings after allowing the camera.
      if (!_resultOpen && !_requestInFlight && _controller == null) unawaited(_startCamera());
    } else {
      // inactive / paused / hidden: do not keep the camera running in the background
      if (_controller != null) unawaited(_releaseCamera());
    }
  }

  // ---------------------------------------------------------------- camera

  Future<void> _startCamera({String? banner, bool pauseAuto = false}) async {
    final epoch = ++_epoch;
    final previous = _startFuture;
    final done = Completer<void>();
    _startFuture = done.future;
    try {
      if (previous != null) await previous; // never start two cameras at the same time
      if (!mounted || epoch != _epoch) return;
      await _openCamera(epoch, banner, pauseAuto);
    } finally {
      done.complete();
    }
  }

  Future<void> _openCamera(int epoch, String? banner, bool pauseAuto) async {
    _detector.reset();
    setState(() {
      _phase = _Phase.starting;
      _banner = banner;
      _autoPaused = pauseAuto;
      _autoAvailable = false;
      _reading = const SteadyReading.idle();
    });

    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (!mounted || epoch != _epoch) return;
      if (cameras.isEmpty) {
        _block('No camera was found on this device. You can upload a photo instead.', canRetry: false);
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            defaultTargetPlatform == TargetPlatform.iOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted || epoch != _epoch) {
        await _disposeQuietly(controller);
        return;
      }
      _controller = controller;
      controller = null; // from here on _controller owns it
      setState(() => _phase = _Phase.ready);
      if (!pauseAuto) await _startStream();
    } on CameraException catch (e) {
      await _disposeQuietly(controller);
      if (mounted && epoch == _epoch) {
        final why = _explain(e);
        _block(why.message, canRetry: why.canRetry);
      }
    } catch (_) {
      await _disposeQuietly(controller);
      if (mounted && epoch == _epoch) {
        _block('The camera could not be started. Please try again, or upload a photo instead.');
      }
    }
  }

  Future<void> _releaseCamera({bool rebuild = true}) async {
    _epoch++;
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    if (rebuild && mounted) {
      setState(() {
        if (_phase != _Phase.blocked) _phase = _Phase.starting;
      });
    }
    await _disposeQuietly(controller);
  }

  Future<void> _disposeQuietly(CameraController? controller) async {
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }

  void _block(String message, {bool canRetry = true}) {
    setState(() {
      _phase = _Phase.blocked;
      _blockedMessage = message;
      _canRetry = canRetry;
    });
  }

  ({String message, bool canRetry}) _explain(CameraException e) {
    final code = e.code.toLowerCase();
    if (code.contains('withoutprompt')) {
      return (
        message: 'Camera access is turned off for KopraGrade. Turn it on in your phone settings, '
            'or upload a photo instead.',
        canRetry: true,
      );
    }
    if (code.contains('restricted')) {
      return (message: 'Camera access is restricted on this device. You can upload a photo instead.', canRetry: false);
    }
    if (code.contains('denied') || code.contains('permission') || code.contains('notallowed')) {
      return (message: 'Camera permission is required for scanning. You can also upload a photo instead.', canRetry: true);
    }
    if (code.contains('notreadable') || code.contains('inuse')) {
      return (
        message: 'The camera is busy. Close other apps that use the camera and try again.',
        canRetry: true,
      );
    }
    if (code.contains('notfound') || code.contains('nocamera')) {
      return (message: 'No camera was found on this device. You can upload a photo instead.', canRetry: false);
    }
    if (code.contains('security')) {
      return (
        message: 'The browser only allows the camera on a secure (HTTPS) page. You can upload a photo instead.',
        canRetry: false,
      );
    }
    return (
      message: 'The camera could not be started. Please try again, or upload a photo instead.',
      canRetry: true,
    );
  }

  // ------------------------------------------------------- auto detection

  Future<void> _startStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || controller.value.isStreamingImages) return;
    if (kIsWeb) return; // browsers cannot stream frames here: use the Capture button
    try {
      await controller.startImageStream(_onFrame);
      if (mounted && identical(controller, _controller)) setState(() => _autoAvailable = true);
    } catch (_) {
      if (mounted) setState(() => _autoAvailable = false);
    }
  }

  void _onFrame(CameraImage image) {
    if (!mounted || _phase != _Phase.ready || _autoPaused || _requestInFlight) return;
    final now = DateTime.now();
    if (now.difference(_lastSample) < _sampleEvery) return;
    _lastSample = now;

    final plane = image.planes.first;
    final isBgra = image.format.group == ImageFormatGroup.bgra8888;
    final samples = sampleCenterLuma(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      bytesPerPixel: plane.bytesPerPixel ?? (isBgra ? 4 : 1),
      channelOffset: isBgra ? 1 : 0, // green channel is close enough to brightness
    );
    if (samples == null) return;

    final reading = _detector.update(samples);
    setState(() => _reading = reading);
    if (reading.ready) unawaited(_capture());
  }

  // -------------------------------------------------------- capture + grade

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_phase != _Phase.ready || _requestInFlight) return; // already busy: ignore
    _requestInFlight = true;
    _detector.reset();
    setState(() {
      _phase = _Phase.capturing;
      _banner = null;
      _reading = const SteadyReading.idle();
    });

    Uint8List bytes;
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
      final file = await controller.takePicture();
      bytes = await file.readAsBytes();
    } catch (_) {
      _requestInFlight = false;
      await _backToReady('Could not take the photo. Please try again.', pauseAuto: false);
      return;
    }
    await _grade(bytes);
  }

  Future<void> _grade(Uint8List bytes) async {
    final kind = detectImageKind(bytes);
    if (kind == null) {
      _requestInFlight = false;
      await _backToReady('Unable to process this image. Please try again.', pauseAuto: false);
      return;
    }
    if (bytes.length > AppConfig.maxImageBytes) {
      _requestInFlight = false;
      await _backToReady('The photo is too large (max 5 MB). Try Upload Photo instead.', pauseAuto: true);
      return;
    }
    if (mounted) setState(() => _phase = _Phase.grading);

    // Same call as the Upload Photo screen: the backend runs the real model and saves one history record.
    int? gradingId;
    ApiException? failure;
    try {
      final grading = await ref.read(gradingServiceProvider).upload(bytes, kind);
      gradingId = grading.id;
    } catch (e) {
      failure = ApiException.from(e);
    }
    _requestInFlight = false;
    if (!mounted) return;

    if (gradingId != null) {
      await _showResult(gradingId);
      return;
    }
    // 422 = "no copra detected / unreadable photo": nothing was saved, just look again after the
    // camera moves. Any other problem (server, model, network) pauses auto-scan so we do not keep retrying.
    final soft = failure?.statusCode == 422;
    await _backToReady(failure?.message ?? 'Something went wrong. Please try again.', pauseAuto: !soft);
  }

  Future<void> _backToReady(String message, {required bool pauseAuto}) async {
    if (!mounted) return;
    _detector.requireMotion();
    if (_controller == null) {
      await _startCamera(banner: message, pauseAuto: pauseAuto);
      return;
    }
    setState(() {
      _phase = _Phase.ready;
      _banner = message;
      _autoPaused = pauseAuto;
    });
    if (!pauseAuto) await _startStream();
  }

  Future<void> _showResult(int gradingId) async {
    _resultOpen = true;
    await _releaseCamera(); // the camera is off while the result is on screen
    if (!mounted) {
      _resultOpen = false;
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(gradingId: gradingId, againLabel: 'Scan Again'),
      ),
    );
    _resultOpen = false;
    if (!mounted) return;
    await _startCamera(); // "Scan Again": a fresh start, nothing carried over
  }

  // ------------------------------------------------------------------- UI

  String _statusText() {
    return switch (_phase) {
      _Phase.starting => 'Starting camera...',
      _Phase.capturing => 'Capturing...',
      _Phase.grading => 'Grading...',
      _Phase.blocked => '',
      _Phase.ready => !_autoAvailable
          ? 'Tap Capture when the copra is inside the frame.'
          : _autoPaused
              ? 'Auto-scan is paused. Tap Capture to try again.'
              : _reading.progress > 0
                  ? 'Hold steady...'
                  : 'Hold the camera steady over the copra, or tap Capture.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase == _Phase.capturing || _phase == _Phase.grading;
    return PopScope(
      canPop: !busy, // do not walk away in the middle of a grading request
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('Scan Copra')),
        body: SafeArea(
          child: _phase == _Phase.blocked ? _buildBlocked(context) : _buildScanner(context, busy),
        ),
      ),
    );
  }

  Widget _buildBlocked(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ResponsiveBody(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.no_photography_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(_blockedMessage, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (_canRetry) ...[
                FilledButton(onPressed: () => unawaited(_startCamera()), child: const Text('Try again')),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(), // back to the screen that has Upload Photo
                child: const Text('Upload a photo instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanner(BuildContext context, bool busy) {
    final controller = _controller;
    final showPreview = controller != null && controller.value.isInitialized;
    final canCapture = _phase == _Phase.ready && showPreview;

    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(box.maxWidth, box.maxHeight) * 0.7;
        final frame = Rect.fromCenter(
          center: Offset(box.maxWidth / 2, box.maxHeight * 0.40),
          width: side,
          height: side,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            if (showPreview) _CameraFill(controller: controller),
            IgnorePointer(
              child: CustomPaint(
                painter: _FramePainter(
                  frame: frame,
                  color: _reading.progress > 0 ? Colors.greenAccent : Colors.white,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  'Place one copra sample inside the frame.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_banner != null) ...[ErrorBanner(_banner!), const SizedBox(height: 12)],
                  Text(
                    _statusText(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  if (_autoAvailable && !_autoPaused && _reading.progress > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _reading.progress,
                      minHeight: 6,
                      color: Colors.greenAccent,
                      backgroundColor: Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: canCapture ? () => unawaited(_capture()) : null,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture'),
                  ),
                ],
              ),
            ),
            if (busy)
              const ColoredBox(
                color: Colors.black54,
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
          ],
        );
      },
    );
  }
}

/// Fills the whole area with the camera picture (cropping the edges instead of stretching).
class _CameraFill extends StatelessWidget {
  const _CameraFill({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final ratio = controller.value.aspectRatio;
    if (ratio <= 0) return const SizedBox.shrink();
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    final previewAspect = portrait ? 1 / ratio : ratio;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: 1000 * previewAspect,
          height: 1000,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

/// Dims everything outside the frame and draws the four corner marks.
class _FramePainter extends CustomPainter {
  const _FramePainter({required this.frame, required this.color});
  final Rect frame;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 20.0;
    const arm = 34.0;

    final hole = RRect.fromRectAndRadius(frame, const Radius.circular(radius));
    final dimmed = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(hole),
    );
    canvas.drawPath(dimmed, Paint()..color = const Color(0x88000000));

    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final l = frame.left, t = frame.top, r = frame.right, b = frame.bottom;
    const round = Radius.circular(radius);

    final corners = Path()
      ..moveTo(l, t + arm)
      ..lineTo(l, t + radius)
      ..arcToPoint(Offset(l + radius, t), radius: round)
      ..lineTo(l + arm, t)
      ..moveTo(r - arm, t)
      ..lineTo(r - radius, t)
      ..arcToPoint(Offset(r, t + radius), radius: round)
      ..lineTo(r, t + arm)
      ..moveTo(r, b - arm)
      ..lineTo(r, b - radius)
      ..arcToPoint(Offset(r - radius, b), radius: round)
      ..lineTo(r - arm, b)
      ..moveTo(l + arm, b)
      ..lineTo(l + radius, b)
      ..arcToPoint(Offset(l, b - radius), radius: round)
      ..lineTo(l, b - arm);
    canvas.drawPath(corners, pen);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.frame != frame || old.color != color;
}