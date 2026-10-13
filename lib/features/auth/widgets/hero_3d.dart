import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';


//ไฟล์นี้เป็นไฟล์ที่เก็บภาพประกอบ 3 มิติแบบวาดเองและเคลื่อนไหวบนหน้าเข้าสู่ระบบ เพื่อให้ผู้ใช้สนใจและรู้สึกว่าแอปมีความเป็นมืออาชีพ
/// Animated isometric hero for the login screen.
///
/// WHY THIS IS DRAWN INSTEAD OF A 3D ENGINE
/// A real 3D engine (model_viewer / WebGL) would need an exported .glb asset
/// and would cost frame budget on low-end Android — the exact devices OTOP
/// buyers use. The brief's goal for the hero is *attention*, so this paints an
/// isometric (true 3D projection, 2D rasteriser) Thai craft parcel in pure
/// Flutter. Result: 60fps, no extra dependency, no asset download, and the
/// student can explain every line.
///
/// Swap-in point: if a real 3D asset is produced later, replace [IsoParcel]
/// with a `model_viewer_plus` widget — the layout here does not change.
/// ภาพประกอบ 3 มิติแบบวาดเองและเคลื่อนไหวบนหน้าเข้าสู่ระบบ
class Hero3d extends StatefulWidget {
  const Hero3d({super.key, this.size = 260});

  final double size;

  @override
  State<Hero3d> createState() => _Hero3dState();
}

class _Hero3dState extends State<Hero3d> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the OS "reduce motion" accessibility setting.
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      label: 'ภาพสินค้าจากผู้ประกอบการ OTOP',
      image: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              final double t = reduceMotion ? 0 : _controller.value;
              return CustomPaint(
                painter: _HeroPainter(t: t),
                isComplex: true,
                willChange: !reduceMotion,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter({required this.t});

  /// 0..1 loop position.
  final double t;

  static const double _cos30 = 0.86602540378; // cos(30°)
  static const double _sin30 = 0.5; // sin(30°)

  /// Isometric projection: 3D box coordinates -> 2D canvas coordinates.
  Offset _project(double x, double y, double z) {
    return Offset((x - z) * _cos30, (x + z) * _sin30 - y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);

    // Gentle vertical float + slight rotation, so the object feels alive
    // without becoming a distracting animation.
    final double float = math.sin(t * 2 * math.pi) * 6;
    final double tilt = math.sin(t * 2 * math.pi + math.pi / 3) * 0.045;

    canvas.save();
    canvas.translate(centre.dx, centre.dy + float + size.height * 0.06);
    canvas.rotate(tilt);

    _paintGlow(canvas, size);
    _paintShadow(canvas);
    _paintParcel(canvas);
    _paintSparkles(canvas, t);

    canvas.restore();
  }

  /// Soft radial glow behind the object — the "premium" lighting cue.
  void _paintGlow(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader =
          RadialGradient(
            colors: <Color>[
              AppColors.accent.withValues(alpha: 0.22),
              AppColors.primary.withValues(alpha: 0.10),
              Colors.transparent,
            ],
            stops: const <double>[0, 0.55, 1],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: size.width * 0.48),
          );

    canvas.drawCircle(Offset.zero, size.width * 0.48, paint);
  }

  /// Elliptical contact shadow, squashed to match the isometric ground plane.
  void _paintShadow(Canvas canvas) {
    final Paint paint = Paint()
      ..color = AppColors.primaryDark.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.save();
    canvas.translate(6, 44);
    canvas.scale(1, 0.34);
    canvas.drawCircle(Offset.zero, 74, paint);
    canvas.restore();
  }

  void _paintParcel(Canvas canvas) {
    // Box dimensions in 3D space.
    const double width = 96; // x
    const double depth = 96; // z
    const double height = 104; // y

    // Eight corners.
    final Offset backBottom = _project(0, 0, 0);
    final Offset frontBottom = _project(width, 0, depth);
    final Offset leftBottom = _project(0, 0, depth);
    final Offset backTop = _project(0, height, 0);
    final Offset rightTop = _project(width, height, 0);
    final Offset frontTop = _project(width, height, depth);
    final Offset leftTop = _project(0, height, depth);

    // --- Faces, painted back-to-front -------------------------------------
    // Right face (darkest) — the shade side that gives the object volume.
    _face(canvas, <Offset>[
      leftBottom,
      frontBottom,
      frontTop,
      leftTop,
    ], AppColors.primaryDark);
    // Left face (mid tone).
    _face(canvas, <Offset>[
      backBottom,
      leftBottom,
      leftTop,
      backTop,
    ], AppColors.primary);
    // Top face (brightest — light comes from above).
    _face(canvas, <Offset>[
      backTop,
      rightTop,
      frontTop,
      leftTop,
    ], const Color(0xFF1E8570));

    // --- Kraft ribbon wrapping over the top and down both visible sides ----
    _ribbonBand(
      canvas,
      width: width,
      depth: depth,
      height: height,
      frontBottom: frontBottom,
      leftBottom: leftBottom,
      backTop: backTop,
      rightTop: rightTop,
      frontTop: frontTop,
      leftTop: leftTop,
    );

    // --- Lid seam ---------------------------------------------------------
    final Paint seam = Paint()
      ..color = AppColors.primaryDark.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(
      Path()
        ..moveTo(leftTop.dx, leftTop.dy)
        ..lineTo(frontTop.dx, frontTop.dy),
      seam,
    );

    // --- Bow on top -------------------------------------------------------
    _paintBow(canvas, centre: _project(width / 2, height, depth / 2));
  }

  /// Draws a filled quad from four projected points.
  void _face(Canvas canvas, List<Offset> points, Color color) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  /// Vertical kraft ribbon that wraps over the top and down both visible sides.
  void _ribbonBand(
    Canvas canvas, {
    required double width,
    required double depth,
    required double height,
    required Offset frontBottom,
    required Offset leftBottom,
    required Offset backTop,
    required Offset rightTop,
    required Offset frontTop,
    required Offset leftTop,
  }) {
    const double band = 18;
    const Color ribbon = AppColors.accent;

    // Strip running along the z axis across the top face.
    _face(canvas, <Offset>[
      backTop,
      _project(band, height, 0),
      _project(band, height, depth),
      leftTop,
    ], ribbon);

    // Strip running along the x axis across the top face.
    _face(canvas, <Offset>[
      _project(0, height, band),
      rightTop,
      _project(width, height, band),
      frontTop,
    ], ribbon.withValues(alpha: 0.92));

    // Continue down the left face.
    _face(canvas, <Offset>[
      leftTop,
      _project(0, height, band),
      _project(0, 0, band),
      leftBottom,
    ], ribbon.withValues(alpha: 0.85));

    // Continue down the right face.
    _face(canvas, <Offset>[
      _project(band, height, depth),
      frontTop,
      frontBottom,
      _project(band, 0, depth),
    ], ribbon.withValues(alpha: 0.72));
  }

  void _paintBow(Canvas canvas, {required Offset centre}) {
    // Lift the bow so it reads as sitting on top of the lid.
    final double knotY = centre.dy - 6;

    final Paint loop = Paint()
      ..color = AppColors.clay
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    // Two loops.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centre.dx - 20, knotY),
        width: 34,
        height: 22,
      ),
      loop,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centre.dx + 20, knotY),
        width: 34,
        height: 22,
      ),
      loop,
    );

    // Knot.
    canvas.drawCircle(
      Offset(centre.dx, knotY),
      6,
      Paint()..color = AppColors.clay,
    );

    // Ribbon tails falling over the front edge.
    final Paint tail = Paint()
      ..color = AppColors.clay.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(centre.dx - 4, knotY + 4),
      Offset(centre.dx - 16, knotY + 26),
      tail,
    );
    canvas.drawLine(
      Offset(centre.dx + 4, knotY + 4),
      Offset(centre.dx + 14, knotY + 24),
      tail,
    );
  }

  /// Small drifting motes — reads as "handmade / craft" rather than "tech".
  void _paintSparkles(Canvas canvas, double t) {
    const List<Offset> seeds = <Offset>[
      Offset(-108, -74),
      Offset(104, -92),
      Offset(-88, 34),
      Offset(96, 22),
      Offset(0, -122),
    ];

    for (int i = 0; i < seeds.length; i++) {
      // Each mote loops on its own offset in time.
      final double phase = (t + i / seeds.length) % 1.0;
      final double dy = math.sin(phase * 2 * math.pi) * 7;
      final double opacity =
          0.25 + 0.45 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));

      final Paint paint = Paint()
        ..color = AppColors.accent.withValues(alpha: opacity);
      canvas.drawCircle(seeds[i] + Offset(0, dy), 2.6, paint);
    }
  }

  @override
  bool shouldRepaint(_HeroPainter oldDelegate) => oldDelegate.t != t;
}
