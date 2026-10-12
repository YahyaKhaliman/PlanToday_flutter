import 'dart:js_interop';

@JS('forceHardReload')
external void _forceHardReload();

@JS('location.reload')
external void _fallbackReload();

void reloadWebPage() {
  try {
    _forceHardReload();
  } catch (_) {
    _fallbackReload();
  }
}
