import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Tells the look-alike script (tool/lookalike) where the subject is, in CSS
/// pixels: it waits for `window.lookalikeBox`, then takes the screenshot.
void reportBox(double x, double y, double width, double height) {
  globalContext['lookalikeBox'] = {'x': x, 'y': y, 'width': width, 'height': height}.jsify();
}
