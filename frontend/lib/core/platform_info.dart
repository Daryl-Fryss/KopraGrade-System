import 'package:flutter/foundation.dart';

/// True on a phone (Android or iPhone/iPad), false on a PC or laptop.
///
/// The live copra scanner is only offered when this is true.
/// On the web, Flutter reports the operating system of the browser, so Chrome on an
/// Android phone counts as a phone and Chrome on Windows, macOS or Linux does not.
bool get isPhoneDevice {
  final platform = defaultTargetPlatform;
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}
