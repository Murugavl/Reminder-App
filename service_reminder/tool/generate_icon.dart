// Generates the app's launcher icon and splash screen source images.
//
// Run with: dart run tool/generate_icon.dart
// Then regenerate platform assets with:
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// Draws a simple bell (the "reminder" glyph) on the app's deep-purple brand
// color, using basic shape primitives from package:image — there's no
// external logo asset, so this is fully reproducible from source.
import 'dart:io';

import 'package:image/image.dart' as img;

const _canvasSize = 1024;
const _purple = 0xFF673AB7; // Colors.deepPurple, same seed as the app theme
const _white = 0xFFFFFFFF;

void main() {
  _write(_iconWithBackground(), 'assets/icon/icon.png');
  _write(_bellGlyph(color: _white, padded: true), 'assets/icon/icon_foreground.png');
  _write(_bellGlyph(color: _purple, padded: false), 'assets/icon/splash_icon_light.png');
  _write(_bellGlyph(color: _white, padded: false), 'assets/icon/splash_icon_dark.png');
}

img.ColorRgba8 _rgb(int hex, {int alpha = 255}) {
  return img.ColorRgba8((hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF, alpha);
}

img.Image _iconWithBackground() {
  final image = img.Image(width: _canvasSize, height: _canvasSize, numChannels: 4);
  img.fill(image, color: _rgb(_purple));
  _drawBell(image, color: _rgb(_white), scale: 1);
  return image;
}

/// [padded] leaves extra margin around the glyph, needed for Android
/// adaptive icon foregrounds (the OS crops/masks a generous margin off all
/// sides, so content must stay within the inner ~66% safe zone).
img.Image _bellGlyph({required int color, required bool padded}) {
  final image = img.Image(width: _canvasSize, height: _canvasSize, numChannels: 4);
  _drawBell(image, color: _rgb(color), scale: padded ? 0.62 : 0.92);
  return image;
}

void _drawBell(img.Image image, {required img.Color color, required double scale}) {
  final cx = _canvasSize / 2;
  final cy = _canvasSize / 2;
  int sx(double dx) => (cx + dx * scale).round();
  int sy(double dy) => (cy + dy * scale).round();

  // Handle.
  img.fillRect(image, x1: sx(-20), y1: sy(-260), x2: sx(20), y2: sy(-215), color: color, radius: 10);

  // Dome.
  img.fillCircle(image, x: sx(0), y: sy(-90), radius: (150 * scale).round(), color: color, antialias: true);

  // Body (widens toward the base).
  img.fillPolygon(
    image,
    color: color,
    vertices: [
      img.Point(sx(-150), sy(-90)),
      img.Point(sx(150), sy(-90)),
      img.Point(sx(230), sy(150)),
      img.Point(sx(-230), sy(150)),
    ],
  );

  // Base bar.
  img.fillRect(image, x1: sx(-252), y1: sy(150), x2: sx(252), y2: sy(190), color: color, radius: 20);

  // Clapper.
  img.fillCircle(image, x: sx(0), y: sy(248), radius: (40 * scale).round(), color: color, antialias: true);
}

void _write(img.Image image, String path) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Wrote $path');
}
