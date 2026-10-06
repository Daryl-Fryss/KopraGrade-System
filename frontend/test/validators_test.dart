import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopragrade/core/validators.dart';

void main() {
  test('email validation', () {
    expect(validateEmail('juan@example.com'), isNull);
    expect(validateEmail('not-an-email'), isNotNull);
    expect(validateEmail(''), isNotNull);
  });

  test('password validation', () {
    expect(validatePassword('password123'), isNull);
    expect(validatePassword('short'), isNotNull);
  });

  test('image kind is found from the first bytes', () {
    expect(detectImageKind(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), 'jpg');
    expect(detectImageKind(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), 'png');
    expect(detectImageKind(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
}
