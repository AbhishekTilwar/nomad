import 'dart:math' as math;
import 'dart:ui' as ui show Image;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'
    show FlutterMap, InteractionOptions, InteractiveFlag, MapOptions;
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/widgets/basemap_layer.dart';
import 'welcome_people.dart';

/// Living background for the welcome page, built around what the app does:
/// plans appear on a map and people head towards them.
///
///  * the real city map (the same soft basemap as Explore), drifting almost
///    imperceptibly, washed out around the logo and the buttons; if it cannot
///    load, a painted topographic ground takes its place,
///  * plan pins that pop in around the logo, then bob gently over a ripple,
///  * a dotted route that draws itself between three of them, with a small
///    traveller dot that keeps walking it ("go together").
///
/// Decorative only (excluded from semantics). With reduced motion it renders
/// the finished picture and never animates.
class WelcomeBackdrop extends StatefulWidget {
  const WelcomeBackdrop({super.key});

  @override
  State<WelcomeBackdrop> createState() => _WelcomeBackdropState();
}

class _WelcomeBackdropState extends State<WelcomeBackdrop>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );
  bool _started = false;
  bool _mapFailed = false;
  List<ui.Image> _photos = const [];
  final _config = MapConfig.fromEnvironment();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
      _ambient.value = 0.25;
    } else {
      _intro.forward();
      _ambient.repeat();
    }
  }

  @override
  void initState() {
    super.initState();
    WelcomePeople.load().then((p) {
      if (mounted && p.isNotEmpty) setState(() => _photos = p);
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  /// The slow drift (under a slight zoom so edges never show), shared by the
  /// map and the pin layer so pins stay glued to their places.
  Widget _drifting(Widget child) => AnimatedBuilder(
    animation: _ambient,
    child: child,
    builder: (_, child) {
      final a = _ambient.value * math.pi * 2;
      return Transform.translate(
        offset: Offset(math.sin(a) * 18, math.cos(a * 0.8) * 12),
        child: Transform.scale(scale: 1.18, child: child),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ground (and contours when there is no map).
            RepaintBoundary(
              child: CustomPaint(
                painter: _BackdropPainter(
                  _Layer.ground,
                  intro: _intro,
                  ambient: _ambient,
                  contours: _mapFailed,
                ),
              ),
            ),
            if (!_mapFailed)
              // The city, drifting under a slight zoom so its edges never show.
              ClipRect(
                child: RepaintBoundary(
                  child: _drifting(
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _kMapCenter,
                        initialZoom: _kMapZoom,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        Opacity(
                          opacity: 0.9,
                          child: BasemapLayer(
                            config: _config,
                            onTileError: () {
                              if (!_mapFailed && mounted) {
                                setState(() => _mapFailed = true);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Washes: a clearing around the logo (its image has its own sand
            // backdrop) and a fade into the page below, for the buttons.
            const _Washes(),
            () {
              final overlay = RepaintBoundary(
                child: CustomPaint(
                  painter: _BackdropPainter(
                    _Layer.overlay,
                    intro: _intro,
                    ambient: _ambient,
                    contours: false,
                    photos: _photos,
                  ),
                ),
              );
              // Pins belong to the map, so they drift with it.
              return _mapFailed ? overlay : _drifting(overlay);
            }(),
          ],
        ),
      ),
    );
  }
}

/// Soft sand veils that keep the logo and the buttons readable over the map.
class _Washes extends StatelessWidget {
  const _Washes();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Clearing around the logo.
          Align(
            alignment: const Alignment(0, -0.4),
            child: FractionallySizedBox(
              widthFactor: 1.15,
              child: AspectRatio(
                aspectRatio: 1.25,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.sand.withValues(alpha: 0.92),
                        AppColors.sand.withValues(alpha: 0.85),
                        AppColors.sand.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Fade the map out under the sign-in block.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.sand.withValues(alpha: 0.55),
                  AppColors.sand.withValues(alpha: 0.0),
                  AppColors.sand.withValues(alpha: 0.0),
                  AppColors.sand.withValues(alpha: 0.95),
                ],
                stops: const [0, 0.16, 0.56, 0.82],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Layer { ground, overlay }

/// A plan pin anchored to a real place on the map.
class _Pin {
  const _Pin(
    this.name,
    this.lat,
    this.lng,
    this.category,
    this.size,
    this.delay, {
    this.people = 3,
  });
  final String name;
  final double lat;
  final double lng;

  /// Activity category: sets the pin's colour and icon.
  final String category;
  final double size;

  /// How many people are drawn gathered at this spot (decorative).
  final int people;

  Color get color => CategoryStyle.color(category);

  /// 0..1 point in the intro at which the pin starts to pop.
  final double delay;
}

/// The camera the welcome map uses, shared by the map and the painted overlay
/// so pins land on the places they name.
const _kMapZoom = 12.4;
const _kMapCenter = LatLng(19.031, 72.8477);

/// Web-Mercator position of [lat]/[lng] in world pixels at [_kMapZoom].
Offset _world(double lat, double lng) {
  final world = 256 * math.pow(2, _kMapZoom).toDouble();
  final x = (lng + 180) / 360 * world;
  final sinLat = math.sin(lat * math.pi / 180);
  final y =
      (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * world;
  return Offset(x, y);
}

/// Screen position of a place inside a map widget of [size] centred on
/// [_kMapCenter].
Offset _screenOf(double lat, double lng, Size size) {
  final c = _world(_kMapCenter.latitude, _kMapCenter.longitude);
  final p = _world(lat, lng);
  return Offset(
    size.width / 2 + (p.dx - c.dx),
    size.height / 2 + (p.dy - c.dy),
  );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(
    this.layer, {
    required this.intro,
    required this.ambient,
    required this.contours,
    this.photos = const [],
  }) : super(repaint: Listenable.merge([intro, ambient]));

  /// Real photos for the people at each pin; empty means illustrated avatars.
  final List<ui.Image> photos;

  final _Layer layer;
  final Animation<double> intro;
  final Animation<double> ambient;

  /// Only the ground layer, and only when the real map is unavailable.
  final bool contours;

  // Real places, chosen to sit on land and to stay clear of the logo block
  // (centre, upper third) and of the sign-in buttons (bottom).
  static const _pins = <_Pin>[
    _Pin('Juhu', 19.0985, 72.8285, 'food', 30, 0.00, people: 3),
    _Pin('Andheri East', 19.1000, 72.8800, 'music', 28, 0.10, people: 2),
    _Pin('Worli', 19.0176, 72.8180, 'hiking', 30, 0.22, people: 3),
    _Pin('Parel', 19.0100, 72.8370, 'sports', 34, 0.34, people: 4),
    _Pin('Wadala', 19.0176, 72.8690, 'photography', 28, 0.46, people: 2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = ambient.value;
    final tau = math.pi * 2;

    if (layer == _Layer.ground) {
      _ground(canvas, size, t, tau);
    } else {
      _overlay(canvas, size, t, tau);
    }
  }

  void _ground(Canvas canvas, Size size, double t, double tau) {
    final w = size.width;
    final h = size.height;
    // Ground: sand under the logo, easing into a soft mint towards the buttons.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.sand, AppColors.sand, Color(0xFFE3F0EB)],
          stops: [0, 0.5, 1],
        ).createShader(Offset.zero & size),
    );

    if (!contours) return;
    // Topographic contours (fallback when the map cannot load): two clusters
    // at opposite corners, away from the logo, breathing slowly.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _contours(
      canvas,
      Offset(w * 1.02, h * 0.02),
      w * 0.40,
      10,
      t * tau,
      1,
      ring,
      0.085,
    );
    _contours(
      canvas,
      Offset(-w * 0.02, h * 0.97),
      w * 0.50,
      12,
      t * tau,
      -1,
      ring,
      0.085,
    );
  }

  void _overlay(Canvas canvas, Size size, double t, double tau) {
    Offset at(_Pin p) => _screenOf(p.lat, p.lng, size);

    // Route Worli -> Parel -> Wadala (drawn after the first pins landed),
    // bowed slightly so it reads as a path, not a ruler line.
    final routeP = Curves.easeInOutCubic.transform(
      ((intro.value - 0.45) / 0.45).clamp(0.0, 1.0),
    );
    final a = at(_pins[2]);
    final b = at(_pins[3]);
    final c = at(_pins[4]);
    final route = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(
        a.dx + (b.dx - a.dx) * 0.2,
        a.dy + (b.dy - a.dy) * 0.9 + 26,
        a.dx + (b.dx - a.dx) * 0.7,
        b.dy + 22,
        b.dx,
        b.dy,
      )
      ..cubicTo(
        b.dx + (c.dx - b.dx) * 0.3,
        b.dy - 34,
        b.dx + (c.dx - b.dx) * 0.7,
        c.dy + 30,
        c.dx,
        c.dy,
      );
    _dashed(canvas, route, routeP);
    if (routeP >= 1) _traveller(canvas, route, t);

    // Pins: ripple underneath, people gathered, then the pin itself popping
    // in (with its activity icon) and bobbing.
    for (var i = 0; i < _pins.length; i++) {
      final p = _pins[i];
      final local = ((intro.value - p.delay) / 0.30).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final pop = Curves.easeOutBack.transform(local);
      final base = at(p);
      final bob = math.sin((t * 2 + i * 0.37) * tau) * 3;
      // Ripple: a ring that grows and fades, offset per pin.
      final r = ((t * 2 + i * 0.29) % 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: base.translate(0, 2),
          width: p.size * (0.7 + 1.9 * r),
          height: p.size * (0.7 + 1.9 * r) * 0.38,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = p.color.withValues(alpha: 0.35 * (1 - r) * local),
      );
      // People arrive just after their pin lands.
      final crowd = ((intro.value - p.delay - 0.12) / 0.25).clamp(0.0, 1.0);
      if (crowd > 0) {
        _people(
          canvas,
          base.translate(0, p.size * 0.42),
          p.people,
          Curves.easeOutBack.transform(crowd),
          crowd,
          i,
          bob,
        );
      }
      _pin(
        canvas,
        base.translate(0, bob),
        p.size * pop,
        p.color,
        CategoryStyle.icon(p.category),
        local,
      );
    }
  }

  static const _bg = <Color>[
    Color(0xFFDCEFEA),
    Color(0xFFFFF0D8),
    Color(0xFFE6EEFA),
    Color(0xFFF8E1EC),
    Color(0xFFEFEAF8),
  ];
  static const _skinTones = <Color>[
    Color(0xFFF1C9A5),
    Color(0xFFD9A47A),
    Color(0xFFB9794F),
    Color(0xFF8D5A3B),
    Color(0xFFF5D6BE),
  ];
  static const _hair = <Color>[
    Color(0xFF2B2118),
    Color(0xFF4A3022),
    Color(0xFF7A4A2A),
    Color(0xFF1C1C1C),
    Color(0xFFB5651D),
  ];
  static const _clothes = <Color>[
    Color(0xFF1F6F5F),
    Color(0xFFE99A32),
    Color(0xFF2F6FBF),
    Color(0xFFC2408A),
    Color(0xFF5B6B7A),
  ];

  /// A small gathered group of people. Real photos are used when provided,
  /// otherwise varied illustrated avatars (skin tone, hair and clothes differ
  /// per person) so the crowd looks like different people, not a pattern.
  void _people(
    Canvas canvas,
    Offset centre,
    int count,
    double scale,
    double alpha,
    int seed,
    double bob,
  ) {
    const r = 9.0;
    final step = r * 1.55;
    final total = (count - 1) * step;
    for (var k = 0; k < count; k++) {
      final dx = -total / 2 + k * step;
      final dy = (k.isOdd ? -3.0 : 0) + math.sin((bob / 3) + k) * 0.7;
      _person(
        canvas,
        centre.translate(dx * scale, dy * scale),
        r * scale,
        seed * 7 + k * 3 + 1,
        alpha,
      );
    }
  }

  void _person(Canvas canvas, Offset c, double r, int who, double a) {
    if (r <= 0.6) return;
    final ring = Paint()..color = Colors.white.withValues(alpha: a);
    canvas.drawCircle(c, r + 1.8, ring);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));

    if (photos.isNotEmpty) {
      final img = photos[who.abs() % photos.length];
      final side = math.min(img.width, img.height).toDouble();
      final src = Rect.fromCenter(
        center: Offset(img.width / 2, img.height * 0.45),
        width: side,
        height: side,
      );
      canvas.drawImageRect(
        img,
        src,
        Rect.fromCircle(center: c, radius: r),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(255, 255, 255, a),
      );
      canvas.restore();
      return;
    }

    final n = who.abs();
    final skin = _skinTones[(n * 3 + 1) % _skinTones.length];
    final hair = _hair[(n * 2 + 3) % _hair.length];
    final cloth = _clothes[n % _clothes.length];
    final style = (n + n ~/ 5) % 4; // 0 short, 1 long, 2 bun, 3 cropped

    canvas.drawCircle(
      c,
      r,
      Paint()..color = _bg[n % _bg.length].withValues(alpha: a),
    );
    final head = c.translate(0, -r * 0.16);
    // Long hair sits behind the head and shoulders.
    if (style == 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: head.translate(0, r * 0.2),
          width: r * 1.0,
          height: r * 1.15,
        ),
        Paint()..color = hair.withValues(alpha: a),
      );
    }
    // Shoulders / clothes.
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, r * 0.86),
        width: r * 1.7,
        height: r * 1.15,
      ),
      Paint()..color = cloth.withValues(alpha: a),
    );
    // Neck and head.
    final skinPaint = Paint()..color = skin.withValues(alpha: a);
    canvas.drawRect(
      Rect.fromCenter(
        center: head.translate(0, r * 0.34),
        width: r * 0.26,
        height: r * 0.3,
      ),
      skinPaint,
    );
    canvas.drawCircle(head, r * 0.34, skinPaint);
    // Hair on top.
    final hairPaint = Paint()..color = hair.withValues(alpha: a);
    if (style == 2) {
      canvas.drawCircle(
        head.translate(0, -r * 0.4),
        r * 0.16,
        hairPaint,
      ); // bun
    }
    final top = Path()
      ..addArc(
        Rect.fromCircle(center: head, radius: r * 0.36),
        math.pi * 1.02,
        math.pi * 0.96,
      );
    canvas.drawPath(top, hairPaint..style = PaintingStyle.fill);
    canvas.drawArc(
      Rect.fromCircle(center: head.translate(0, -r * 0.02), radius: r * 0.355),
      math.pi * 1.0,
      math.pi * 1.0,
      true,
      hairPaint,
    );
    canvas.restore();
  }

  void _contours(
    Canvas canvas,
    Offset c,
    double maxR,
    int rings,
    double phase,
    double dir,
    Paint paint,
    double alpha,
  ) {
    for (var k = 1; k <= rings; k++) {
      final r0 = maxR * k / rings;
      final path = Path();
      const steps = 72;
      for (var s = 0; s <= steps; s++) {
        final a = s / steps * math.pi * 2;
        final wob =
            1 +
            0.07 * math.sin(3 * a + k * 0.55 + dir * phase) +
            0.045 * math.sin(5 * a - k * 0.4 - dir * phase * 1.3);
        final r = r0 * wob;
        final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
        s == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      // Inner rings a touch stronger, like elevation lines.
      final a = alpha * (0.6 + 0.4 * (1 - k / rings));
      canvas.drawPath(
        path,
        paint..color = AppColors.primary.withValues(alpha: a),
      );
    }
  }

  void _dashed(Canvas canvas, Path path, double progress) {
    if (progress <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary.withValues(alpha: 0.45);
    for (final PathMetric m in path.computeMetrics()) {
      final end = m.length * progress;
      var d = 0.0;
      while (d < end) {
        final seg = math.min(6.0, end - d);
        canvas.drawPath(m.extractPath(d, d + seg), paint);
        d += 12;
      }
    }
  }

  /// A person walking the route, with a soft halo.
  void _traveller(Canvas canvas, Path path, double t) {
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (a, m) => a + m.length);
    var at = (t * 2 % 1.0) * total;
    for (final m in metrics) {
      if (at <= m.length) {
        final tan = m.getTangentForOffset(at);
        if (tan != null) {
          final step = math.sin(t * math.pi * 2 * 14).abs() * 1.6;
          final c = tan.position.translate(0, -step);
          canvas.drawCircle(
            c,
            11,
            Paint()..color = AppColors.secondary.withValues(alpha: 0.22),
          );
          _person(canvas, c, 8.6, 11, 1);
        }
        return;
      }
      at -= m.length;
    }
  }

  /// A teardrop map pin carrying its activity icon, tip at [tip].
  void _pin(
    Canvas canvas,
    Offset tip,
    double size,
    Color color,
    IconData icon,
    double a,
  ) {
    if (size <= 0.5) return;
    final r = size * 0.44;
    final cy = tip.dy - size * 0.78;
    final body = Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(
        tip.dx - r * 1.35,
        cy + r * 0.9,
        tip.dx - r * 1.15,
        cy - r * 0.2,
        tip.dx - r,
        cy,
      )
      ..arcToPoint(Offset(tip.dx + r, cy), radius: Radius.circular(r))
      ..cubicTo(
        tip.dx + r * 1.15,
        cy - r * 0.2,
        tip.dx + r * 1.35,
        cy + r * 0.9,
        tip.dx,
        tip.dy,
      )
      ..close();
    canvas.drawShadow(body, Colors.black.withValues(alpha: 0.35 * a), 3, false);
    canvas.drawPath(body, Paint()..color = color.withValues(alpha: a));
    // White disc with the activity icon in the pin's colour.
    final centre = Offset(tip.dx, cy);
    canvas.drawCircle(
      centre,
      r * 0.7,
      Paint()..color = Colors.white.withValues(alpha: a),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: r * 0.95,
          color: color.withValues(alpha: a),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      !identical(old.photos, photos) || old.contours != contours;
}
