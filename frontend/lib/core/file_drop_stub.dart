import 'dart:typed_data';

/// Drag-and-drop of files is only available in the web build (see file_drop_web.dart).
/// On Android, iOS and desktop builds this does nothing, so the Choose File button is the way in.
class FileDropListener {
  FileDropListener({
    required this.maxBytes,
    required this.onDragChanged,
    required this.onFile,
    required this.onError,
  });

  final int maxBytes;
  final void Function(bool dragging) onDragChanged;
  final void Function(Uint8List bytes) onFile;
  final void Function(String message) onError;

  void dispose() {}
}
