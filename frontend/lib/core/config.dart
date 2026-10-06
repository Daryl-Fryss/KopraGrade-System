import 'package:flutter/foundation.dart';

class AppConfig {
  // Run with --dart-define=API_BASE_URL=http://192.168.1.10:8000 to use another server
  // (for example a real phone on the same Wi-Fi as your computer).
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8000';
    // The Android emulator reaches the computer through 10.0.2.2
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  static const int maxImageBytes = 5 * 1024 * 1024; // same limit as the API (MAX_UPLOAD_MB)

  // Drying-quality classes, from best to worst. Must match the quality_classes table.
  static const List<String> grades = ['Well-Dried', 'Moderately Dried', 'Poorly Dried'];
}
