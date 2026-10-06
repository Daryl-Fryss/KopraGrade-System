import 'dart:math' as math;
import 'dart:typed_data';

/// Reads a small grid of brightness values from the middle of a camera frame.
///
/// [bytes] is the first plane of the camera image (the brightness plane on Android,
/// the BGRA pixels on iPhone). Returns null if the frame is too small or the numbers
/// do not fit the buffer, so the caller can just skip that frame.
List<int>? sampleCenterLuma({
  required Uint8List bytes,
  required int width,
  required int height,
  required int bytesPerRow,
  int bytesPerPixel = 1,
  int channelOffset = 0,
  int grid = 16,
}) {
  if (width < grid || height < grid || bytesPerPixel < 1) return null;
  final side = (math.min(width, height) * 0.5).floor();
  if (side < grid) return null;
  final x0 = (width - side) ~/ 2;
  final y0 = (height - side) ~/ 2;
  final out = List<int>.filled(grid * grid, 0);
  for (var gy = 0; gy < grid; gy++) {
    final y = y0 + (gy * side) ~/ grid;
    for (var gx = 0; gx < grid; gx++) {
      final x = x0 + (gx * side) ~/ grid;
      final i = y * bytesPerRow + x * bytesPerPixel + channelOffset;
      if (i < 0 || i >= bytes.length) return null;
      out[gy * grid + gx] = bytes[i];
    }
  }
  return out;
}

/// What the detector thinks about the latest frame.
class SteadyReading {
  const SteadyReading({
    required this.progress,
    required this.ready,
    required this.moving,
    required this.lowContent,
  });

  const SteadyReading.idle()
      : progress = 0,
        ready = false,
        moving = false,
        lowContent = false;

  /// 0 to 1: how close we are to "held steady long enough".
  final double progress;

  /// True once the camera has been held steady over something for long enough.
  final bool ready;
  final bool moving;

  /// The middle of the picture is too dark, too bright or too flat (nothing in it).
  final bool lowContent;
}

/// Decides WHEN to take the photo. It does not grade anything and it does not know what
/// copra looks like: the real decision is always made by the backend model.
///
/// It only waits until the camera is held steady over a scene that has something in it.
/// Call [update] a few times per second. When [SteadyReading.ready] turns true, take one photo.
class SteadinessDetector {
  SteadinessDetector({
    this.motionLimit = 8.0,
    this.minContrast = 10.0,
    this.minBrightness = 30.0,
    this.maxBrightness = 240.0,
    this.framesNeeded = 5,
  });

  /// Average brightness change between two samples that counts as "moving".
  final double motionLimit;
  final double minContrast;
  final double minBrightness;
  final double maxBrightness;

  /// Steady samples in a row before we are ready (about 1.25 s at 4 samples per second).
  final int framesNeeded;

  List<int>? _previous;
  int _steady = 0;
  bool _needMotion = false;
  bool _motionSeen = false;

  /// Forget everything (used when the camera starts or a photo was just taken).
  void reset() {
    _previous = null;
    _steady = 0;
    _needMotion = false;
    _motionSeen = false;
  }

  /// After a photo was rejected, do not try the same still scene again:
  /// wait until the camera has moved first.
  void requireMotion() {
    _previous = null;
    _steady = 0;
    _needMotion = true;
    _motionSeen = false;
  }

  SteadyReading update(List<int> samples) {
    if (samples.isEmpty) return const SteadyReading.idle();

    var sum = 0;
    for (final v in samples) {
      sum += v;
    }
    final mean = sum / samples.length;
    var squares = 0.0;
    for (final v in samples) {
      final d = v - mean;
      squares += d * d;
    }
    final contrast = math.sqrt(squares / samples.length);
    final lowContent = contrast < minContrast || mean < minBrightness || mean > maxBrightness;

    final previous = _previous;
    _previous = samples;

    var moving = false;
    var hasPrevious = false;
    if (previous != null && previous.length == samples.length) {
      hasPrevious = true;
      var diff = 0;
      for (var i = 0; i < samples.length; i++) {
        diff += (samples[i] - previous[i]).abs();
      }
      moving = diff / samples.length > motionLimit;
    }

    if (moving) {
      _steady = 0;
      _motionSeen = true;
    } else if (lowContent || !hasPrevious) {
      _steady = 0;
    } else if (_needMotion && !_motionSeen) {
      _steady = 0;
    } else {
      _steady++;
    }

    return SteadyReading(
      progress: (_steady / framesNeeded).clamp(0.0, 1.0),
      ready: _steady >= framesNeeded,
      moving: moving,
      lowContent: lowContent,
    );
  }
}
