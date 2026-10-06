import 'dart:typed_data';

final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateName(String? v) {
  final s = (v ?? '').trim();
  if (s.length < 2) return 'Please enter your name.';
  if (s.length > 100) return 'Name is too long.';
  return null;
}

String? validateEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Please enter your email.';
  if (!_emailRe.hasMatch(s)) return 'Please enter a valid email address.';
  return null;
}

String? validatePassword(String? v) {
  if (v == null || v.length < 8) return 'Password must be at least 8 characters.';
  if (v.length > 72) return 'Password is too long.';
  return null;
}

String? validateContact(String? v) {
  if ((v ?? '').trim().length > 50) return 'Contact info is too long (max 50 characters).';
  return null;
}

/// Looks at the first bytes of the file: returns 'jpg', 'png' or null.
String? detectImageKind(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'jpg';
  const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (b.length >= 8) {
    var ok = true;
    for (var i = 0; i < 8; i++) {
      if (b[i] != png[i]) ok = false;
    }
    if (ok) return 'png';
  }
  return null;
}
