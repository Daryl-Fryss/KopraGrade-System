// Picks the right drag-and-drop implementation: the web one in browsers, a no-op elsewhere.
export 'file_drop_stub.dart' if (dart.library.js_interop) 'file_drop_web.dart';
