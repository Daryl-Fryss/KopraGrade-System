import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../core/frame_steadiness.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

enum _Phase { starting, ready, capturing, grading, blocked }

/// Phones only: live camera with a scanning frame, like a QR scanner.
///
/// When the camera is held steady over something, it takes ONE photo and sends it to the
/// same grading endpoint as "Upload Image" (GradingService.upload -> POST /api/classification/predict).
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

  // Camera choice and flashlight. The torch is only offered on a rear camera, and only outside the
  // browser (the web camera plugin cannot switch a torch on), so unsupported devices never see it.
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lens = CameraLensDirection.back;
  bool _torchOn = false;

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
        _block('No camera was found on this device. You can upload an image instead.', canRetry: false);
        return;
      }
      _cameras = cameras;
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => cameras.first,
      );
      _lens = camera.lensDirection;
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
      setState(() {
        _phase = _Phase.ready;
        _torchOn = false; // a new camera always starts with the flashlight off
      });
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
        _block('The camera could not be started. Please try again, or upload an image instead.');
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
            'or upload an image instead.',
        canRetry: true,
      );
    }
    if (code.contains('restricted')) {
      return (message: 'Camera access is restricted on this device. You can upload an image instead.', canRetry: false);
    }
    if (code.contains('denied') || code.contains('permission') || code.contains('notallowed')) {
      return (message: 'Camera permission is required for scanning. You can also upload an image instead.', canRetry: true);
    }
    if (code.contains('notreadable') || code.contains('inuse')) {
      return (
        message: 'The camera is busy. Close other apps that use the camera and try again.',
        canRetry: true,
      );
    }
    if (code.contains('notfound') || code.contains('nocamera')) {
      return (message: 'No camera was found on this device. You can upload an image instead.', canRetry: false);
    }
    if (code.contains('security')) {
      return (
        message: 'The browser only allows the camera on a secure (HTTPS) page. You can upload an image instead.',
        canRetry: false,
      );
    }
    return (
      message: 'The camera could not be started. Please try again, or upload an image instead.',
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
      await _backToReady('The image is too large (max 5 MB). Try Upload Image instead.', pauseAuto: true);
      return;
    }
    if (mounted) setState(() => _phase = _Phase.grading);

    // Same call as the Upload Image screen: the backend runs the real model and saves one history record.
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
        builder: (_) => ResultScreen(gradingId: gradingId, source: ResultSource.scan),
      ),
    );
    _resultOpen = false;
    if (!mounted) return;
    await _startCamera(); // "Scan Again": a fresh start, nothing carried over
  }

  // ------------------------------------------------- flashlight + camera switch

  bool get _torchAvailable => !kIsWeb && _lens == CameraLensDirection.back;

  bool get _canSwitchCamera {
    final other = _lens == CameraLensDirection.back ? CameraLensDirection.front : CameraLensDirection.back;
    return _cameras.any((c) => c.lensDirection == other);
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _phase != _Phase.ready) return;
    final next = !_torchOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) {
        setState(() {
          _torchOn = next;
          _banner = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _torchOn = false;
          _banner = 'The flashlight is not available on this camera.';
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_phase != _Phase.ready || _requestInFlight || !_canSwitchCamera) return;
    _lens = _lens == CameraLensDirection.back ? CameraLensDirection.front : CameraLensDirection.back;
    await _releaseCamera();
    if (!mounted) return;
    unawaited(_startCamera());
  }

  // ------------------------------------------------------------------- UI

  String _statusText() {
    return switch (_phase) {
      _Phase.starting => 'Starting camera... Allow camera access if your phone asks.',
      _Phase.capturing => 'Capturing image...',
      _Phase.grading => 'Processing image...',
      _Phase.blocked => '',
      _Phase.ready => !_autoAvailable
          ? 'Tap the green button when the copra is inside the frame.'
          : _autoPaused
              ? 'Auto-scan is paused. Tap the green button to try again.'
              : _reading.progress > 0
                  ? 'Hold steady...'
                  : 'Hold the camera steady over the copra, or tap the green button.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase == _Phase.capturing || _phase == _Phase.grading;
    return PopScope(
      canPop: !busy, // do not walk away in the middle of a classification request
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
    final theme = Theme.of(context);
    return ColoredBox(
      color: KopraColors.page,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ResponsiveBody(
            child: KCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(color: KopraColors.amberTint, shape: BoxShape.circle),
                      child: const Icon(Icons.no_photography_outlined, size: 40, color: KopraColors.amber),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Camera not available', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(_blockedMessage, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 22),
                  if (_canRetry) ...[
                    FilledButton.icon(
                      onPressed: () {
                        _lens = CameraLensDirection.back; // a failed camera switch must not trap the user
                        unawaited(_startCamera());
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(), // back to the screen that has Upload Image
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload an image instead'),
                  ),
                ],
              ),
            ),
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
        final side = math.min(box.maxWidth, box.maxHeight) * 0.68;
        final frame = Rect.fromCenter(
          center: Offset(box.maxWidth / 2, box.maxHeight * 0.43),
          width: side,
          height: side,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            if (showPreview) _CameraFill(controller: controller!),
            IgnorePointer(
              child: CustomPaint(
                painter: _FramePainter(
                  frame: frame,
                  color: _reading.progress > 0 ? KopraColors.freshLight : Colors.white,
                ),
              ),
            ),
            // How to position the copra
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xD9174D36),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Place one copra sample inside the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Use good daylight and hold the phone steady.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            // Status, flashlight, capture and camera switch
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xD9174D36),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_banner != null) ...[ErrorBanner(_banner!), const SizedBox(height: 12)],
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _statusText(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                    if (_autoAvailable && !_autoPaused && _reading.progress > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _reading.progress,
                        minHeight: 6,
                        color: KopraColors.freshLight,
                        backgroundColor: Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (_torchAvailable)
                          _RoundControl(
                            icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            label: _torchOn ? 'Turn flashlight off' : 'Turn flashlight on',
                            active: _torchOn,
                            onPressed: canCapture ? () => unawaited(_toggleTorch()) : null,
                          )
                        else
                          const SizedBox(width: 56, height: 56),
                        _CaptureButton(onPressed: canCapture ? () => unawaited(_capture()) : null),
                        if (_canSwitchCamera)
                          _RoundControl(
                            icon: Icons.cameraswitch_rounded,
                            label: 'Switch camera',
                            active: false,
                            onPressed: canCapture ? () => unawaited(_switchCamera()) : null,
                          )
                        else
                          const SizedBox(width: 56, height: 56),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (busy)
              ColoredBox(
                color: const Color(0xB3000000),
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _phase == _Phase.grading ? 'Processing image...' : 'Capturing image...',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Round flashlight / camera-switch button.
class _RoundControl extends StatelessWidget {
  const _RoundControl({required this.icon, required this.label, required this.active, required this.onPressed});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: active ? KopraColors.soft : Colors.white24,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, color: active ? KopraColors.forest : Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

/// The big round capture button.
class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Capture photo',
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
            child: Container(
              decoration: const BoxDecoration(color: KopraColors.fresh, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
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