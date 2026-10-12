import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// The Nomad Mingle logo. At rest it is just the stacked "Nomad Mingle"
/// wordmark with the tagline set in code underneath (crisp at any size). The
/// pin mark only appears in the splash's entrance, then leaves.
///
/// The splash and the welcome page place it at the same spot
/// ([restAlignment]), so when the splash hands over the logo stays put and
/// only the surroundings change (no second logo ever appears).
///
/// [animate] plays a one-off entrance: the pin drops in with a soft bounce,
/// the name appears, the pin exits, then the tagline fades in. It is skipped
/// when the system asks for reduced motion.
class BrandMark extends StatefulWidget {
  const BrandMark({super.key, this.width = 250, this.animate = false});

  /// Width of the logo image; the tagline sits beneath it.
  final double width;
  final bool animate;

  /// Where the logo sits on both screens (a little above centre).
  static const restAlignment = Alignment(0, -0.4);

  static const markAsset = 'assets/images/logo_mark.png';
  static const nameAsset = 'assets/images/logo_wordmark.png';
  static const tagline = 'Find your people. Make a plan. Go together.';

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  // The name never moves: it fades up into its resting spot. The pin floats
  // in above it, holds for a beat, then lifts away and fades.
  late final Animation<double> _pinIn = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.3, curve: Curves.easeOutQuart),
  );
  late final Animation<double> _nameIn = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.22, 0.5, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _pinOut = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.6, 0.86, curve: Curves.easeInOutCubic),
  );
  late final Animation<double> _tagIn = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.78, 1, curve: Curves.easeOutCubic),
  );

  /// Logo pin proportions (trimmed asset is 720 x 866).
  static const _pinAspect = 866 / 720;
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
    final w = widget.width;
    final pinW = w * 0.34;
    final pinH = pinW * _pinAspect;
    const gap = 20.0;
    final pin = Image.asset(
      BrandMark.markAsset,
      key: const ValueKey('brand-mark-image'),
      width: pinW,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Nomad Mingle',
    );
    final name = Image.asset(
      BrandMark.nameAsset,
      key: const ValueKey('brand-mark-name'),
      width: w * 0.8,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
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
          builder: (_, _) {
            // The resting layout (name over tagline) is laid out always, so
            // nothing shifts when the pin leaves.
            final base = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: widget.animate ? _nameIn.value : 1,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      widget.animate ? 10 * (1 - _nameIn.value) : 0,
                    ),
                    child: name,
                  ),
                ),
                const SizedBox(height: 12),
                Opacity(
                  opacity: widget.animate ? _tagIn.value : 1,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      widget.animate ? 6 * (1 - _tagIn.value) : 0,
                    ),
                    child: tagline,
                  ),
                ),
              ],
            );
            if (!widget.animate || _pinOut.value >= 1) return base;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                base,
                // Sits above the name; floats down into place, then lifts off.
                Positioned(
                  top: -(pinH + gap),
                  child: Opacity(
                    opacity: _pinIn.value * (1 - _pinOut.value),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        18 * (1 - _pinIn.value) - 30 * _pinOut.value,
                      ),
                      child: Transform.scale(
                        scale: 0.9 + 0.1 * _pinIn.value - 0.05 * _pinOut.value,
                        child: pin,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
