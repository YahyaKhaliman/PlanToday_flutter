import 'dart:js_interop';

@JS('forceHardReload')
external void _forceHardReload();

@JS('location.reload')
external void _fallbackReload();

@JS('window.addEventListener')
external void _addWindowEventListener(JSString type, JSFunction listener);

@JS('document.addEventListener')
external void _addDocumentEventListener(JSString type, JSFunction listener);

@JS('document.hidden')
external bool get _isDocumentHidden;

void reloadWebPage() {
  try {
    _forceHardReload();
  } catch (_) {
    _fallbackReload();
  }
}

void registerWebFocusListener(void Function() onFocus) {
  try {
    final focusCallback = (() {
      onFocus();
    }).toJS;

    final visibilityCallback = (() {
      try {
        if (!_isDocumentHidden) {
          onFocus();
        }
      } catch (_) {
        onFocus();
      }
    }).toJS;

    _addWindowEventListener('focus'.toJS, focusCallback);
    _addDocumentEventListener('visibilitychange'.toJS, visibilityCallback);
  } catch (_) {}
}
