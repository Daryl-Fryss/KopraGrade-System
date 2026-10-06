import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopragrade/core/frame_steadiness.dart';
import 'package:kopragrade/core/platform_info.dart';

/// A picture-like list of samples: a gradient, so it has contrast.
List<int> scene({int shift = 0}) => List<int>.generate(256, (i) => ((i % 16) * 12 + shift).clamp(0, 255));

void main() {
  group('platform detection', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('phones get the scanner', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(isPhoneDevice, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(isPhoneDevice, isTrue);
    });

    test('PCs and laptops do not', () {
      for (final p in [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = p;
        expect(isPhoneDevice, isFalse, reason: '$p');
      }
    });
  });

  group('steadiness detector', () {
    test('becomes ready only after the camera is held still', () {
      final d = SteadinessDetector(framesNeeded: 3);
      expect(d.update(scene()).ready, isFalse); // first frame: nothing to compare with
      expect(d.update(scene()).ready, isFalse);
      expect(d.update(scene()).ready, isFalse);
      final r = d.update(scene());
      expect(r.ready, isTrue);
      expect(r.progress, 1.0);
    });

    test('moving resets the count', () {
      final d = SteadinessDetector(framesNeeded: 3);
      d.update(scene());
      d.update(scene());
      d.update(scene());
      final moved = d.update(scene(shift: 60));
      expect(moved.moving, isTrue);
      expect(moved.ready, isFalse);
      expect(moved.progress, 0);
    });

    test('an empty or dark scene is never ready', () {
      final d = SteadinessDetector(framesNeeded: 2);
      final flat = List<int>.filled(256, 120);
      final dark = List<int>.filled(256, 5);
      for (var i = 0; i < 6; i++) {
        expect(d.update(flat).ready, isFalse);
        expect(d.update(dark).ready, isFalse);
      }
      expect(d.update(flat).lowContent, isTrue);
    });

    test('after a rejected photo it waits for movement before trying again', () {
      final d = SteadinessDetector(framesNeeded: 2);
      d.requireMotion();
      for (var i = 0; i < 8; i++) {
        expect(d.update(scene()).ready, isFalse); // same still scene: not allowed
      }
      d.update(scene(shift: 70)); // the camera moves
      d.update(scene(shift: 70));
      d.update(scene(shift: 70));
      expect(d.update(scene(shift: 70)).ready, isTrue);
    });
  });

  group('sampleCenterLuma', () {
    test('reads the middle of a frame and respects the row stride', () {
      const w = 64, h = 48, stride = 80; // stride is bigger than the width, like real cameras
      final bytes = Uint8List(stride * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          bytes[y * stride + x] = x;
        }
      }
      final s = sampleCenterLuma(bytes: bytes, width: w, height: h, bytesPerRow: stride)!;
      expect(s.length, 256);
      expect(s.first, greaterThanOrEqualTo(16)); // starts inside the picture, not at its edge
      expect(s.every((v) => v < w), isTrue);
    });

    test('returns null instead of crashing on a bad buffer', () {
      expect(sampleCenterLuma(bytes: Uint8List(10), width: 64, height: 48, bytesPerRow: 64), isNull);
      expect(sampleCenterLuma(bytes: Uint8List(100), width: 4, height: 4, bytesPerRow: 4), isNull);
    });
  });
}