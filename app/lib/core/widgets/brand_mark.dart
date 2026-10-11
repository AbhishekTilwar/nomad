import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// The Nomad Mingle logo (transparent PNG built from the supplied SVG) with
/// the tagline set in code underneath, so the type stays crisp at any size.
///
/// The splash and the welcome page place it at the same spot
/// ([restAlignment]), so when the splash hands over the logo stays put and
/// only the surroundings change (no second logo ever appears).
///
/// [animate] plays a one-off entrance: the logo fades in, rises and settles,
/// then the tagline follows. It is skipped when the system asks for reduced
/// motion.
class BrandMark extends StatefulWidget {
  const BrandMark({super.key, this.width = 250, this.animate = false});

  /// Width of the logo image; the tagline sits beneath it.
  final double width;
  final bool animate;

  /// Where the logo sits on both screens (a little above centre).
  static const restAlignment = Alignment(0, -0.4);

  static const assetPath = 'assets/images/brand_logo.png';
  static const tagline = 'Find your people. Make a plan. Go together.';

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.4, curve: Curves.easeOut),
  );
  late final Animation<double> _settle = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _tagFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.5, 1, curve: Curves.easeOut),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      BrandMark.assetPath,
      key: const ValueKey('brand-mark-image'),
      width: widget.width,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Nomad Mingle',
    );
    final tagline = ExcludeSemantics(
      child: Text(
        BrandMark.tagline,
        key: const ValueKey('brand-mark-tagline'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.ink.withValues(alpha: 0.82),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
    );
    return Semantics(
      label: 'Nomad Mingle. ${BrandMark.tagline}',
      container: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: _fade.value,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - _settle.value)),
                  child: Transform.scale(
                    scale: 0.94 + 0.06 * _settle.value,
                    child: logo,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: _tagFade.value,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - _tagFade.value)),
                  child: tagline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
