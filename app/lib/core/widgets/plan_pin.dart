import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/activities/models/activity.dart';
import '../theme/app_tokens.dart';
import '../utils/category_style.dart';
import '../utils/plan_emoji.dart';

/// Short, pin-sized start time: "now", "in 40m", "in 3h", "7 PM", "Tmrw", "Sat".
String planTimeLabel(DateTime start, DateTime now) {
  final mins = start.difference(now).inMinutes;
  if (mins <= 0) return 'now';
  if (mins < 60) return 'in ${mins}m';
  if (mins < 360) return 'in ${(mins / 60).round()}h';
  final d0 = DateTime(now.year, now.month, now.day);
  final days = DateTime(
    start.year,
    start.month,
    start.day,
  ).difference(d0).inDays;
  if (days == 0) return _clock(start);
  if (days == 1) return 'Tmrw';
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return wd[start.weekday - 1];
}

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute == 0 ? '' : ':${t.minute.toString().padLeft(2, '0')}';
  return '$h$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// Springs a child in from nothing (anchored at the pin's tip) when it first
/// appears on the map.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child, this.alignment = Alignment.bottomCenter});
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (_, v, c) =>
          Transform.scale(scale: v, alignment: alignment, child: c),
      child: child,
    );
  }
}

/// Map pin for a plan (an event for a group, not a person): a glossy
/// category-coloured sticker holding an emoji picked from the plan's title,
/// ringed by an arc that fills as the plan fills up. It pops in, floats, and
/// shakes with ripples when it starts soon or is selected.
class PlanPin extends StatefulWidget {
  const PlanPin({
    super.key,
    required this.activity,
    this.selected = false,
    DateTime? now,
  }) : _now = now;

  final Activity activity;
  final bool selected;
  final DateTime? _now;

  static const double width = 64;
  static const double height = 82;

  @override
  State<PlanPin> createState() => _PlanPinState();
}

class _PlanPinState extends State<PlanPin> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  // Desynchronise pins so a screen of them doesn't bob in unison.
  late final double _phase = (widget.activity.id.hashCode & 0xFFF) / 0xFFF;

  bool get _soon {
    final mins = widget.activity.startAt
        .difference(widget._now ?? DateTime.now())
        .inMinutes;
    return mins <= 120 && !widget.activity.isFull;
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final color = a.isFull
        ? Colors.grey.shade600
        : CategoryStyle.color(a.category);
    final fill = a.capacity <= 0 ? 0.0 : a.participantCount / a.capacity;
    final label = planTimeLabel(a.startAt, widget._now ?? DateTime.now());
    final emoji = PlanEmoji.of(a.title, a.category);
    final lively = _soon || widget.selected;
    return _PopIn(
      child: AnimatedScale(
        scale: widget.selected ? 1.25 : 1,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: PlanPin.width,
          height: PlanPin.height,
          child: AnimatedBuilder(
            animation: _loop,
            builder: (_, _) {
              final t = (_loop.value + _phase) % 1;
              final bob = math.sin(t * math.pi * 2) * 2.5;
              // A quick shake at the start of each cycle, then rest.
              final shake = lively && t < 0.35
                  ? math.sin(t / 0.35 * math.pi * 4) * 0.28 * (1 - t / 0.35)
                  : 0.0;
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  if (_soon)
                    for (final k in const [0.0, 0.5])
                      Positioned(
                        top: 11,
                        child: _Ripple(progress: (t + k) % 1, color: color),
                      ),
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(0, bob),
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _StickerPainter(
                                color: color,
                                fill: fill,
                                selected: widget.selected,
                              ),
                            ),
                          ),
                          // Fixed box centred on the disc (centre = 32, 40) so
                          // the emoji sits dead-centre whatever its glyph metrics.
                          Positioned(
                            top: 25,
                            left: 17,
                            width: 30,
                            height: 30,
                            child: Transform.rotate(
                              angle: shake,
                              child: Center(child: _Emoji(emoji, 24)),
                            ),
                          ),
                          Positioned(
                            top: 56,
                            right: 0,
                            child: _GoingChip(
                              color: color,
                              count: a.participantCount,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            child: _TimePill(color: color, label: label),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// An emoji drawn with tight, symmetric line metrics so it centres on its box.
class _Emoji extends StatelessWidget {
  const _Emoji(this.emoji, this.size);
  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      emoji,
      textAlign: TextAlign.center,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      style: TextStyle(
        fontSize: size,
        height: 1.0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
  }
}

class _Ripple extends StatelessWidget {
  const _Ripple({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.9 + 0.9 * progress,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.5 * (1 - progress)),
            width: 3,
          ),
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 3)],
      ),
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 9.5,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _GoingChip extends StatelessWidget {
  const _GoingChip({required this.color, required this.count});
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color, width: 1.2),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_rounded, size: 11, color: color),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StickerPainter extends CustomPainter {
  _StickerPainter({
    required this.color,
    required this.fill,
    required this.selected,
  });
  final Color color;
  final double fill;
  final bool selected;

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, 40);
    const outer = 28.0;
    // Soft coloured glow under the sticker.
    canvas.drawCircle(
      c.translate(0, 3),
      outer,
      Paint()
        ..color = color.withValues(alpha: selected ? 0.55 : 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, selected ? 10 : 7),
    );
    final tail = Path()
      ..moveTo(c.dx - 9, c.dy + outer - 5)
      ..quadraticBezierTo(c.dx - 2, c.dy + outer + 1, c.dx, s.height - 1)
      ..quadraticBezierTo(
        c.dx + 2,
        c.dy + outer + 1,
        c.dx + 9,
        c.dy + outer - 5,
      )
      ..close();
    canvas.drawPath(tail, Paint()..color = Colors.white);
    canvas.drawCircle(c, outer, Paint()..color = Colors.white);

    // Fill arc: how full the plan is.
    final ring = Rect.fromCircle(center: c, radius: outer - 3);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = color.withValues(alpha: 0.2);
    canvas.drawArc(ring, 0, math.pi * 2, false, track);
    canvas.drawArc(
      ring,
      -math.pi / 2,
      math.pi * 2 * fill.clamp(0.04, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    // Glossy gradient disc the emoji sits on.
    final disc = Rect.fromCircle(center: c, radius: outer - 7.5);
    canvas.drawCircle(
      c,
      outer - 7.5,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.55)!,
            color.withValues(alpha: 0.85),
          ],
        ).createShader(disc),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(-6, -9), width: 13, height: 7),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
    if (selected) {
      canvas.drawCircle(
        c,
        outer + 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_StickerPainter o) =>
      o.color != color || o.fill != fill || o.selected != selected;
}

/// A stack of plans: a donut split by category colour with the count inside
/// and the emoji of the most common category on its shoulder.
class ClusterPin extends StatelessWidget {
  const ClusterPin({super.key, required this.items});

  final List<Activity> items;

  static const double size = 58;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final a in items) {
      counts[a.category] = (counts[a.category] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _PopIn(
      alignment: Alignment.center,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(size - 6, size - 6),
              painter: _DonutPainter([
                for (final e in entries) (CategoryStyle.color(e.key), e.value),
              ]),
            ),
            Text(
              '${items.length}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B2B2A),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.card,
                ),
                child: _Emoji(PlanEmoji.forCategory(entries.first.key), 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.parts);
  final List<(Color, int)> parts;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Colors.black54,
      3,
      true,
    );
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    final total = parts.fold<int>(0, (n, p) => n + p.$2);
    final ring = Rect.fromCircle(center: c, radius: r - 5);
    const gap = 0.07;
    var start = -math.pi / 2;
    for (final (color, n) in parts) {
      final sweep = math.pi * 2 * n / total;
      final g = parts.length > 1 ? gap : 0.0;
      canvas.drawArc(
        ring,
        start + g / 2,
        math.max(sweep - g, 0.01),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.parts != parts;
}

/// The plan's emoji on a soft category-tinted disc: pops in, then floats and
/// gives a little shake every few seconds. Used where a plan is shown big
/// (the card that opens from a pin, the plan page header).
class PlanEmojiBadge extends StatefulWidget {
  const PlanEmojiBadge({
    super.key,
    required this.title,
    required this.category,
    this.size = 48,
    this.onDark = false,
  });

  final String title;
  final String category;
  final double size;

  /// Draws the disc as translucent white (for use over a coloured hero).
  final bool onDark;

  @override
  State<PlanEmojiBadge> createState() => _PlanEmojiBadgeState();
}

class _PlanEmojiBadgeState extends State<PlanEmojiBadge>
    with SingleTickerProviderStateMixin {
  // A few playful cycles, then it rests (an endless wobble on a card you're
  // reading is distracting, and it keeps the screen able to settle).
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(count: 3);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(widget.category);
    final emoji = PlanEmoji.of(widget.title, widget.category);
    final size = widget.size;
    if (MediaQuery.disableAnimationsOf(context)) _c.stop();
    return _PopIn(
      alignment: Alignment.center,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final t = _c.value;
            final bob = math.sin(t * math.pi * 2) * size * 0.04;
            final shake = t < 0.2
                ? math.sin(t / 0.2 * math.pi * 4) * 0.25 * (1 - t / 0.2)
                : 0.0;
            return Transform.translate(
              offset: Offset(0, bob),
              child: Transform.rotate(angle: shake, child: child),
            );
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.onDark
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.28),
                        color.withValues(alpha: 0.12),
                      ],
                    ),
              color: widget.onDark ? Colors.white.withValues(alpha: 0.22) : null,
              border: Border.all(
                color: widget.onDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : color.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                textAlign: TextAlign.center,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
                style: TextStyle(
                  fontSize: size * 0.54,
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
