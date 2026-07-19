import 'dart:math' as math;

import 'package:flutter/material.dart';

Icon telegramIcon({double size = 24.0, Color? color}) {
  return Icon(Icons.send, size: size, color: color ?? Colors.blue);
}

class MatrixIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const MatrixIcon({super.key, this.size = 24.0, this.color});

  @override
  Widget build(BuildContext context) {
    // Falls keine Farbe übergeben wurde, nutzen wir die aktuelle IconTheme-Farbe
    final iconColor = color ?? Colors.green.shade500;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MatrixIconPainter(color: iconColor)),
    );
  }
}

class _MatrixIconPainter extends CustomPainter {
  final Color color;

  _MatrixIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Wir nutzen ein relatives Koordinatensystem (Basis 100x100),
    // damit das Icon perfekt mit der Widget-Größe skaliert.
    final scaleX = size.width / 100.0;
    final scaleY = size.height / 100.0;
    canvas.scale(scaleX, scaleY);

    // --- 1. Linke eckige Klammer [ ---
    final leftBracket = Path()
      ..moveTo(22, 15) // Oben rechts der Klammer
      ..lineTo(8, 15) // Nach links ziehen
      ..lineTo(8, 85) // Runter nach links unten
      ..lineTo(22, 85) // Nach rechts ziehen
      ..lineTo(22, 75) // Dicke unten: rauf
      ..lineTo(16, 75) // Innenkante unten nach links
      ..lineTo(16, 25) // Innenkante hoch
      ..lineTo(22, 25) // Innenkante oben nach rechts
      ..close();
    canvas.drawPath(leftBracket, paint);

    // --- 2. Rechte eckige Klammer ] ---
    final rightBracket = Path()
      ..moveTo(78, 15) // Oben links der Klammer
      ..lineTo(92, 15) // Nach rechts ziehen
      ..lineTo(92, 85) // Runter nach rechts unten
      ..lineTo(78, 85) // Nach links ziehen
      ..lineTo(78, 75) // Dicke unten: rauf
      ..lineTo(84, 75) // Innenkante unten nach rechts
      ..lineTo(84, 25) // Innenkante hoch
      ..lineTo(78, 25) // Innenkante oben nach links
      ..close();
    canvas.drawPath(rightBracket, paint);

    // --- 3. Das kleine "m" (Geometrischer Nachbau im FreeSans-Stil) ---
    // Strichstärke des "m" und Kurvenradien
    final double thickness = 8;
    final double mTop = 32.0;
    final double mBottom = 68.0;
    final double rightLeg = 70.0;
    final double leftLeg = 30.0;
    final double middleLeg = (leftLeg + rightLeg) / 2;
    final double bowTop = mTop - thickness / 3;
    final double bowBottom = mTop + thickness / 2;

    // Linker vertikaler Stamm
    canvas.drawRect(
      Rect.fromLTWH(leftLeg, mTop, thickness, mBottom - mTop),
      paint,
    );

    // Pfad für die beiden Bögen des "m"
    final mArches = Path();

    // Erster Bogen (Mitte)
    mArches.moveTo(
      leftLeg + thickness / 2,
      mTop + thickness,
    ); // Startpunkt: Innenkante oben links
    // Bogen nach oben rechts
    mArches.cubicTo(
      leftLeg + thickness,
      bowTop,
      middleLeg - thickness / 3,
      bowTop,
      middleLeg + thickness / 2,
      bowBottom,
    );
    // Rechter Abstrich des ersten Bogens runter
    mArches.lineTo(middleLeg + thickness / 2, mBottom);
    mArches.lineTo(middleLeg - thickness / 2, mBottom);
    // Innenkante wieder hoch
    mArches.lineTo(middleLeg - thickness / 2, mTop + 8);
    mArches.cubicTo(
      middleLeg - thickness / 2,
      mTop + 4,
      leftLeg + thickness,
      mTop + 4,
      leftLeg + thickness,
      mTop + 9,
    );

    // Zweiter Bogen (Rechts)
    mArches.moveTo(
      middleLeg,
      mTop + thickness,
    ); // Startpunkt: Innenkante oben links
    // Bogen nach oben rechts
    mArches.cubicTo(
      middleLeg,
      bowTop,
      rightLeg,
      bowTop,
      rightLeg,
      bowBottom + 2,
    );
    // Rechter Abstrich runter
    mArches.lineTo(rightLeg, mBottom);
    mArches.lineTo(rightLeg - thickness, mBottom);
    // Innenkante wieder hoch
    mArches.lineTo(rightLeg - thickness, mTop + 8);
    mArches.cubicTo(
      rightLeg - thickness,
      mTop + 6,
      middleLeg + thickness,
      mTop + 4,
      middleLeg + thickness / 2,
      mTop + 9,
    );

    mArches.close();
    canvas.drawPath(mArches, paint);
  }

  @override
  bool shouldRepaint(covariant _MatrixIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Google-Maps-artiger Location-Pin mit vier farbigen Quadranten.
class ColoredLocationPinIcon extends StatelessWidget {
  final double size;

  const ColoredLocationPinIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ColoredLocationPinPainter()),
    );
  }
}

class _ColoredLocationPinPainter extends CustomPainter {
  // Google-Farben
  static const Color _green = Color(0xFF34A853);
  static const Color _red = Color(0xFFEA4335);
  static const Color _blue = Color(0xFF4285F4);
  static const Color _yellow = Color(0xFFFBBC04);

  @override
  void paint(Canvas canvas, Size size) {
    // 100×100 Koordinatensystem
    const double cx = 50.0; // Kreismittelpunkt X
    const double cy = 40.0; // Kreismittelpunkt Y
    const double r = 37.0; // Kreisradius
    const double tipY = 98.0; // Spitze Y
    const double holeR = 13.5; // Radius des weißen Lochs

    canvas.scale(size.width / 100.0, size.height / 100.0);

    // Tangentenpunkte berechnen, an denen der Kreis in die Spitze übergeht
    final double d = tipY - cy; // Abstand Mittelpunkt → Spitze
    final double angleAtCenter = math.acos(
      r / d,
    ); // Winkel am Mittelpunkt zwischen CP und CT
    final double t1Angle = math.pi / 2 + angleAtCenter; // linker Tangentenpunkt
    // t2 (rechter Tangentenpunkt) wird implizit als Bogenendpunkt erreicht

    final Offset t1 = Offset(
      cx + r * math.cos(t1Angle),
      cy + r * math.sin(t1Angle),
    );
    // t2 (rechter Tangentenpunkt) wird implizit als Bogenendpunkt erreicht

    // Pin-Pfad: langer Bogen über den Scheitelpunkt, dann zwei Geraden zur Spitze
    final pinPath = Path()
      ..moveTo(t1.dx, t1.dy)
      ..arcTo(
        Rect.fromCircle(center: const Offset(cx, cy), radius: r),
        t1Angle,
        2 * math.pi -
            2 * angleAtCenter, // Bogen im Uhrzeigersinn über den Scheitelpunkt
        false,
      )
      ..lineTo(cx, tipY)
      ..close();

    // Pin-Form als Clip setzen, dann vier farbige Quadranten zeichnen
    canvas.save();
    canvas.clipPath(pinPath);

    final paint = Paint()..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(0, 0, cx, cy),
      paint..color = _green,
    ); // oben links
    canvas.drawRect(
      Rect.fromLTRB(cx, 0, 100, cy),
      paint..color = _red,
    ); // oben rechts
    canvas.drawRect(
      Rect.fromLTRB(0, cy, cx, 100),
      paint..color = _blue,
    ); // unten links
    canvas.drawRect(
      Rect.fromLTRB(cx, cy, 100, 100),
      paint..color = _yellow,
    ); // unten rechts

    canvas.restore();

    // Weißes Loch in der Mitte
    canvas.drawCircle(
      const Offset(cx, cy),
      holeR,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _ColoredLocationPinPainter oldDelegate) => false;
}
