// Генерирует исходники иконки приложения в assets/icon/.
// Запуск: flutter test tool/generate_icon_test.dart
// Затем: dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:chance_affair/ui/theme.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

/// Четырёхлучевая звезда с вогнутыми гранями, как логотип в приложении.
Path _spark(Offset c, double r) => Path()
  ..moveTo(c.dx, c.dy - r)
  ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
  ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
  ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
  ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
  ..close();

/// Полная иконка: фон с дугами и оранжевая звезда.
void _paintFull(Canvas canvas) {
  _paintBackground(canvas);
  _paintStar(canvas, 300);
}

/// Графитовый фон с дугами из углов и тёмным «окном» под звезду.
void _paintBackground(Canvas canvas) {
  const rect = Rect.fromLTWH(0, 0, _size, _size);
  canvas.drawRect(rect, Paint()..color = AppColors.ink);

  final arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..color = AppColors.sage.withValues(alpha: 0.16);
  canvas.save();
  canvas.clipRect(rect);
  for (final corner in const [
    Offset(0, 0),
    Offset(_size, 0),
    Offset(0, _size),
    Offset(_size, _size),
  ]) {
    for (var r = 90.0; r <= 470; r += 38) {
      canvas.drawCircle(corner, r, arc);
    }
  }
  canvas.restore();

  // Мягкое свечение под звездой, чтобы она читалась поверх дуг.
  canvas.drawCircle(
    const Offset(_size / 2, _size / 2),
    250,
    Paint()..color = AppColors.ink,
  );
}

void _paintStar(Canvas canvas, double radius) {
  const c = Offset(_size / 2, _size / 2);
  canvas.drawPath(_spark(c, radius), Paint()..color = AppColors.orange);
  canvas.drawPath(
    _spark(c, radius * 0.22),
    Paint()..color = AppColors.cream.withValues(alpha: 0.9),
  );
  // Маленькая звёздочка-искра справа сверху.
  canvas.drawPath(
    _spark(c + Offset.fromDirection(-pi / 4, radius * 0.95), radius * 0.16),
    Paint()..color = AppColors.sage,
  );
}

Future<void> _save(String path, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(
    _size.toInt(),
    _size.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('generate app icon', (tester) async {
    await tester.runAsync(() async {
      await _save('assets/icon/icon.png', _paintFull);
      // Адаптивная иконка Android: фон с дугами + звезда в безопасной зоне.
      await _save('assets/icon/icon_background.png', _paintBackground);
      await _save('assets/icon/icon_foreground.png', (c) => _paintStar(c, 280));
      // Заставка при запуске.
      await _save('assets/icon/splash.png', (c) => _paintStar(c, 300));
    });
  });
}
