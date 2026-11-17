import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../settings/kakao_button_settings.g.dart';
import '../theme/kakao_theme.dart';
import 'kakao_corner_scope.dart';
import 'kakao_tooltip.dart';

/// `<kakao-button variant>`.
enum KakaoButtonVariant { primary, secondary, ghost, danger }

/// `<kakao-button size>`.
enum KakaoButtonSize { sm, md, lg }

/// One size's values from the generated settings (`--kakao-button-<size>-*`).
class _Size {
  const _Size(this.height, this.paddingX, this.fontSize, this.radius, this.gap);
  final double height, paddingX, fontSize, radius, gap;

  factory _Size.of(KakaoButtonSettings st, KakaoButtonSize size) => switch (size) {
    KakaoButtonSize.sm => _Size(st.smHeight, st.smPaddingX, st.smFontSize, st.smRadius, st.smGap),
    KakaoButtonSize.md => _Size(st.mdHeight, st.mdPaddingX, st.mdFontSize, st.mdRadius, st.mdGap),
    KakaoButtonSize.lg => _Size(st.lgHeight, st.lgPaddingX, st.lgFontSize, st.lgRadius, st.lgGap),
  };
}

/// Makes the [KakaoButton]s below it fill the width they get (the dialog's
/// full-width footer sets the inner button to width: 100% the same way).
class KakaoButtonStretch extends InheritedWidget {
  const KakaoButtonStretch({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<KakaoButtonStretch>() != null;

  @override
  bool updateShouldNotify(KakaoButtonStretch oldWidget) => false;
}

/// The CSS `transition: … ease` the button uses with its --kakao-button-transition.
const _ease = Curves.ease;

// button.js easings.
const _bounce = Cubic(0.34, 1.3, 0.64, 1); // BOUNCE
const _soft = Cubic(0.25, 1.0, 0.5, 1); // SOFT

/// Flutter twin of `<kakao-button>`: same variants, sizes, colours and motion.
///
/// Motion as in button.js:
/// - press squash: scale to 0.94 on touch down (110 ms, soft), springs back
///   (220 ms, bounce);
/// - loading: the label shrinks and fades out, the spinner pops in;
/// - [onPressedAsync]: loading while the future runs, then the success check
///   for 900 ms (or straight back to the label when it fails), like `run()`.
///
/// [toggle] makes it a toggle button (`toggle` / `pressed` on the web): off
/// it is dimmed to 0.45 at weight 400, [pressed] it is full at weight 600,
/// so the state never depends on colour alone. Tapping calls [onPressed];
/// the owner flips [pressed].
///
/// Pass neither callback for the disabled state. An [icon] without a [label]
/// gives the round icon-only button; give it a [semanticLabel], which also
/// shows as its tooltip. [tooltip] is the web's `title`: a themed tooltip
/// on any button.
class KakaoButton extends StatefulWidget {
  const KakaoButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.onPressedAsync,
    this.variant = KakaoButtonVariant.primary,
    this.size = KakaoButtonSize.md,
    this.loading = false,
    this.successHold = const Duration(milliseconds: 900),
    this.semanticLabel,
    this.tooltip,
    this.toggle = false,
    this.pressed = false,
  }) : assert(label != null || icon != null, 'A button needs a label or an icon'),
       assert(onPressed == null || onPressedAsync == null, 'Pass onPressed or onPressedAsync, not both');

  final String? label;
  final Widget? icon;
  final VoidCallback? onPressed;

  /// Runs the button's loading → success / fail animation around the future.
  final Future<void> Function()? onPressedAsync;
  final KakaoButtonVariant variant;
  final KakaoButtonSize size;

  /// Shows the spinner (for loading driven from outside).
  final bool loading;

  /// How long the success check stays (`run(…, { successHold })`).
  final Duration successHold;
  final String? semanticLabel;

  /// The web's `title`: shown as a [KakaoTooltip]. Empty turns off the
  /// icon-only button's automatic one (`title=""`).
  final String? tooltip;

  /// Toggle button (`toggle`), currently [pressed] or not.
  final bool toggle;
  final bool pressed;

  @override
  State<KakaoButton> createState() => _KakaoButtonState();
}

enum _Overlay { none, spinner, check }

class _KakaoButtonState extends State<KakaoButton> with TickerProviderStateMixin {
  KakaoCornerRegistry? _corners;
  bool _hover = false;
  bool _focusVisible = false;
  bool _running = false; // onPressedAsync in flight or showing its result
  _Overlay _overlay = _Overlay.none;

  late final _press = AnimationController(vsync: this, value: 1, lowerBound: 0, upperBound: 2);
  late final _content = AnimationController(vsync: this, value: 1, upperBound: 2);
  late final _spinner = AnimationController(vsync: this, value: 0, upperBound: 2);
  late final _check = AnimationController(vsync: this, value: 0, upperBound: 2);
  double _checkFrom = .7; // the check grows from .7, leaves towards .85
  final _timers = <Timer>[];

  bool get _hasAction => widget.onPressed != null || widget.onPressedAsync != null;
  bool get _busy => widget.loading || _running;
  bool get _enabled => _hasAction && !_busy;
  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.loading) {
      _content.value = 0;
      _spinner.value = 1;
      _overlay = _Overlay.spinner;
    }
  }

  @override
  void didUpdateWidget(KakaoButton old) {
    super.didUpdateWidget(old);
    if (widget.loading != old.loading && !_running) {
      widget.loading ? _startLoading() : _finishLoading(success: false);
    }
  }

  @override
  void dispose() {
    _corners?.remove(this);
    for (final t in _timers) {
      t.cancel();
    }
    _press.dispose();
    _content.dispose();
    _spinner.dispose();
    _check.dispose();
    super.dispose();
  }

  void _after(Duration d, VoidCallback f) {
    _timers.add(
      Timer(d, () {
        if (mounted) f();
      }),
    );
  }

  Duration _ms(int ms) => Duration(milliseconds: _reduceMotion ? 1 : ms);

  // ---- press squash, interruption-safe (animates from the current scale) ----
  void _animatePress(double target) {
    if (_reduceMotion) {
      _press.value = target;
      return;
    }
    final down = target < 1;
    _press.animateTo(
      target,
      duration: Duration(milliseconds: down ? 110 : 220),
      curve: down ? _soft : _bounce,
    );
  }

  // ---- loading / success, as _startLoading / _finishLoading in button.js ----
  void _startLoading() {
    setState(() => _overlay = _Overlay.spinner);
    _content.animateTo(0, duration: _ms(180), curve: _soft);
    _spinner.value = 0;
    _after(_ms(54), () => _spinner.animateTo(1, duration: _ms(180), curve: _bounce));
  }

  /// Removes an overlay once it has faded out, so a hidden spinner stops ticking.
  void _dropOverlay(_Overlay which, TickerFuture faded) {
    faded.whenCompleteOrCancel(() {
      if (mounted && _overlay == which) setState(() => _overlay = _Overlay.none);
    });
  }

  void _finishLoading({required bool success}) {
    final spinnerOut = _spinner.animateTo(0, duration: _ms(160), curve: _soft);
    if (success) {
      setState(() {
        _overlay = _Overlay.check;
        _checkFrom = .7;
      });
      _check.value = 0;
      _after(_ms(48), () => _check.animateTo(1, duration: _ms(160), curve: _bounce));
      _after(widget.successHold, () {
        setState(() => _checkFrom = .85);
        _dropOverlay(_Overlay.check, _check.animateTo(0, duration: _ms(160), curve: _soft));
        _content.animateTo(1, duration: _ms(220), curve: _bounce);
        _running = false;
      });
    } else {
      _dropOverlay(_Overlay.spinner, spinnerOut);
      _after(_ms(160), () => _content.animateTo(1, duration: _ms(220), curve: _bounce));
      _running = false;
    }
  }

  Future<void> _activate() async {
    if (!_enabled) return;
    if (widget.onPressedAsync == null) {
      widget.onPressed?.call();
      return;
    }
    setState(() => _running = true);
    _startLoading();
    var ok = true;
    try {
      await widget.onPressedAsync!();
    } on Object {
      ok = false;
    }
    if (mounted) setState(() => _finishLoading(success: ok));
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoButtonSettings.of(theme.colors);
    final s = _Size.of(st, widget.size);
    final iconOnly = widget.label == null;

    // Colours per variant: the generated --kakao-button-<variant>-* settings.
    // A ghost button has no fill at rest (transparent ink, so hover blends from ink).
    final (Color bg, Color hoverBg, Color fg, Color ring, List<BoxShadow> shadow) = switch (widget.variant) {
      KakaoButtonVariant.primary => (st.primaryBg, st.primaryHoverBg, st.primaryText, st.primaryRing, st.primaryShadow),
      KakaoButtonVariant.secondary => (
        st.secondaryBg,
        st.secondaryHoverBg,
        st.secondaryText,
        st.secondaryRing,
        const [],
      ),
      KakaoButtonVariant.ghost => (st.ink.withValues(alpha: 0), st.ghostHoverBg, st.ghostText, st.ghostRing, const []),
      KakaoButtonVariant.danger => (st.dangerBg, st.dangerHoverBg, st.dangerText, st.dangerRing, st.dangerShadow),
    };
    // Focus halo: box-shadow 0 0 0 <focus-ring-width> <ring>, in place of the rest shadow.
    final shadows = _focusVisible ? [BoxShadow(color: ring, spreadRadius: st.focusRingWidth)] : shadow;

    // Toggles show their state with weight as well: 400 off, 600 pressed.
    final weight = widget.toggle ? (widget.pressed ? 600.0 : 400.0) : st.labelWeight;
    final textStyle = theme
        .text(size: s.fontSize, weight: weight, color: fg)
        .copyWith(letterSpacing: -0.01 * s.fontSize, height: 1);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null)
          IconTheme(
            data: IconThemeData(color: fg, size: s.fontSize * .95),
            child: widget.icon!,
          ),
        if (widget.icon != null && !iconOnly) SizedBox(width: s.gap),
        if (!iconOnly)
          AnimatedDefaultTextStyle(
            style: textStyle,
            duration: st.transition,
            curve: _ease,
            child: Text(widget.label!, maxLines: 1, softWrap: false),
          ),
      ],
    );

    // The label keeps its place while hidden, so the width stays put
    // (button.js locks the width the same way).
    final layers = Stack(
      alignment: Alignment.center,
      children: [
        _ScaleFade(controller: _content, from: .9, child: content),
        if (_overlay == _Overlay.spinner)
          _ScaleFade(
            controller: _spinner,
            from: .85,
            child: _Spinner(color: fg, size: st.spinnerSize, still: _reduceMotion),
          ),
        if (_overlay == _Overlay.check)
          _ScaleFade(
            controller: _check,
            from: _checkFrom,
            child: CustomPaint(size: Size.square(st.spinnerSize), painter: _CheckPainter(fg)),
          ),
      ],
    );

    Widget box = AnimatedContainer(
      duration: st.transition,
      curve: _ease,
      height: s.height,
      width: iconOnly ? s.height : (KakaoButtonStretch.of(context) ? double.infinity : null),
      padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : s.paddingX),
      decoration: BoxDecoration(
        color: _enabled && _hover ? hoverBg : bg,
        borderRadius: BorderRadius.circular(iconOnly ? s.height / 2 : s.radius),
        boxShadow: shadows,
      ),
      child: layers,
    );

    box = ScaleTransition(scale: _press, child: box);

    box = AnimatedOpacity(
      opacity: !_hasAction
          ? st.disabledOpacity
          : (widget.toggle && !widget.pressed)
          ? st.toggleOffOpacity
          : 1,
      duration: st.transition,
      curve: _ease,
      child: box,
    );

    // In a dialog footer: tell the dialog where this button is and how round
    // its corners are, so a corner it sits in can follow it (nesting rule).
    _corners = KakaoCornerScope.maybeOf(context);
    _corners?.put(
      this,
      KakaoCornerEntry(
        context: context,
        filled: widget.variant != KakaoButtonVariant.ghost,
        radius: iconOnly ? s.height / 2 : s.radius,
      ),
    );

    final tip = widget.tooltip ?? (iconOnly ? widget.semanticLabel : null);
    final button = Semantics(
      button: true,
      enabled: _enabled,
      toggled: widget.toggle ? widget.pressed : null,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _hasAction,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activate())},
        child: Listener(
          // Pointer events, like button.js: the squash starts on touch down,
          // before the tap is recognised.
          onPointerDown: (_) {
            if (_enabled) _animatePress(.94);
          },
          onPointerUp: (_) => _animatePress(1),
          onPointerCancel: (_) => _animatePress(1),
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _enabled ? _activate : null, child: box),
        ),
      ),
    );
    return tip == null || tip.isEmpty ? button : KakaoTooltip(message: tip, child: button);
  }
}

/// Opacity and scale driven by one 0..1 value (overshoot only scales).
class _ScaleFade extends AnimatedWidget {
  const _ScaleFade({required AnimationController controller, required this.from, required this.child})
    : super(listenable: controller);

  final double from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = (listenable as AnimationController).value;
    return Opacity(
      opacity: v.clamp(0.0, 1.0),
      child: Transform.scale(scale: from + (1 - from) * v, child: child),
    );
  }
}

/// The loading arc: r 9 in a 24 box, stroke 3, dash 42 of 56.55, one turn
/// per 0.85 s. With reduced motion it stands still and pulses instead
/// (opacity .4 ↔ 1, 1.1 s ease-in-out), as kakao-button-pulse.
class _Spinner extends StatefulWidget {
  const _Spinner({required this.color, required this.size, required this.still});
  final Color color;
  final double size;
  final bool still;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(_Spinner old) {
    super.didUpdateWidget(old);
    if (old.still != widget.still) _run();
  }

  void _run() {
    _c.duration = Duration(milliseconds: widget.still ? 1100 : 850);
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arc = CustomPaint(size: Size.square(widget.size), painter: _ArcPainter(widget.color));
    if (widget.still) {
      return AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = Curves.easeInOut.transform(_c.value < .5 ? _c.value * 2 : (1 - _c.value) * 2);
          return Opacity(opacity: .4 + .6 * t, child: child);
        },
        child: arc,
      );
    }
    return RotationTransition(turns: _c, child: arc);
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = Paint()
      ..color = color.withValues(alpha: color.a * .9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * k
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 9 * k);
    // SVG circles start at 3 o'clock; 42 / 56.55 of the circumference.
    canvas.drawArc(rect, 0, 2 * math.pi * 42 / 56.55, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}

/// button.js CHECK: `M5 12.5l4.5 4.5L19 7.5` in a 24 box, stroke 2.6, round.
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(5 * k, 12.5 * k)
      ..lineTo(9.5 * k, 17 * k)
      ..lineTo(19 * k, 7.5 * k);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color;
}
