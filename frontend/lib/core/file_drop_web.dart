// Web only: lets the user drag an image file from their computer onto the page.
// It uses only the Dart SDK (dart:js_interop), so no extra package is needed.
//
// If this file ever causes trouble in a web build, open file_drop.dart and point it at
// file_drop_stub.dart instead: the app then works the same, just without drag-and-drop.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

class FileDropListener {
  FileDropListener({
    required this.maxBytes,
    required this.onDragChanged,
    required this.onFile,
    required this.onError,
  }) {
    _document = globalContext.getProperty<JSObject>('document'.toJS);
    _document.callMethod<JSAny?>('addEventListener'.toJS, 'dragenter'.toJS, _enterOver);
    _document.callMethod<JSAny?>('addEventListener'.toJS, 'dragover'.toJS, _enterOver);
    _document.callMethod<JSAny?>('addEventListener'.toJS, 'dragleave'.toJS, _leave);
    _document.callMethod<JSAny?>('addEventListener'.toJS, 'drop'.toJS, _drop);
  }

  final int maxBytes;
  final void Function(bool dragging) onDragChanged;
  final void Function(Uint8List bytes) onFile;
  final void Function(String message) onError;

  late final JSObject _document;
  late final JSFunction _enterOver = _handleEnterOver.toJS;
  late final JSFunction _leave = _handleLeave.toJS;
  late final JSFunction _drop = _handleDrop.toJS;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _document.callMethod<JSAny?>('removeEventListener'.toJS, 'dragenter'.toJS, _enterOver);
    _document.callMethod<JSAny?>('removeEventListener'.toJS, 'dragover'.toJS, _enterOver);
    _document.callMethod<JSAny?>('removeEventListener'.toJS, 'dragleave'.toJS, _leave);
    _document.callMethod<JSAny?>('removeEventListener'.toJS, 'drop'.toJS, _drop);
  }

  /// Only react to drags that carry files (not dragged text or links).
  bool _hasFiles(JSObject event) {
    final transfer = event.getProperty<JSObject?>('dataTransfer'.toJS);
    if (transfer == null) return false;
    final types = transfer.getProperty<JSObject?>('types'.toJS);
    if (types == null) return false;
    try {
      final found = types.callMethod<JSBoolean?>('includes'.toJS, 'Files'.toJS);
      return found?.toDart ?? false;
    } catch (_) {
      // very old browsers expose a DOMStringList, which has contains() instead of includes()
      final found = types.callMethod<JSBoolean?>('contains'.toJS, 'Files'.toJS);
      return found?.toDart ?? false;
    }
  }

  void _handleEnterOver(JSObject event) {
    if (_disposed || !_hasFiles(event)) return;
    event.callMethod<JSAny?>('preventDefault'.toJS); // required, or the browser refuses the drop
    onDragChanged(true);
  }

  void _handleLeave(JSObject event) {
    if (_disposed) return;
    // relatedTarget is null when the pointer leaves the browser window.
    if (event.getProperty<JSAny?>('relatedTarget'.toJS) == null) onDragChanged(false);
  }

  void _handleDrop(JSObject event) {
    if (_disposed || !_hasFiles(event)) return;
    event.callMethod<JSAny?>('preventDefault'.toJS); // do not let the browser open the file
    onDragChanged(false);

    final transfer = event.getProperty<JSObject>('dataTransfer'.toJS);
    final files = transfer.getProperty<JSObject>('files'.toJS);
    final count = files.getProperty<JSNumber>('length'.toJS).toDartInt;
    if (count < 1) return;
    final file = files.callMethod<JSObject>('item'.toJS, 0.toJS);
    final size = file.getProperty<JSNumber>('size'.toJS).toDartInt;
    if (size > maxBytes) {
      onError('That photo is too large (max ${maxBytes ~/ (1024 * 1024)} MB). Please choose a smaller one.');
      return;
    }
    unawaited(_read(file));
  }

  Future<void> _read(JSObject file) async {
    try {
      final buffer = await file.callMethod<JSPromise<JSArrayBuffer>>('arrayBuffer'.toJS).toDart;
      if (_disposed) return;
      onFile(buffer.toDart.asUint8List());
    } catch (_) {
      if (!_disposed) onError('Could not open the photo. Please try again.');
    }
  }
}
