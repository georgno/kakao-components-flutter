import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/kakao_theme.dart';

/// `<kakao-button variant>`.
enum KakaoButtonVariant { primary, secondary, ghost, danger }

/// `<kakao-button size>`.
enum KakaoButtonSize { sm, md, lg }

/// The settings block of `components/button/button.css`, sizes part.
class _Size {
  const _Size(this.height, this.paddingX, this.fontSize, this.radius, this.gap);
  final double height, paddingX, fontSize, radius, gap;
}

const _sizes = {
  KakaoButtonSize.sm: _Size(36, 16, 13, 10, 6),
  KakaoButtonSize.md: _Size(44, 22, 14.5, 14, 8),
  KakaoButtonSize.lg: _Size(52, 28, 16, 14, 10),
};

const _labelWeight = 550.0;
const _focusRingWidth = 4.0;
const _disabledOpacity = 0.2;
const _spinnerSize = 18.0;
const _transition = Duration(milliseconds: 200);

/// Flutter twin of `<kakao-button>`: same variants, sizes, colours and timing.
///
/// Pass `onPressed: null` for the disabled state. An [icon] without a
/// [label] gives the round icon-only button; give it a [semanticLabel].
class KakaoButton extends StatefulWidget {
  const KakaoButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.variant = KakaoButtonVariant.primary,
    this.size = KakaoButtonSize.md,
    this.loading = false,
    this.semanticLabel,
  }) : assert(label != null || icon != null, 'A button needs a label or an icon');

  final String? label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final KakaoButtonVariant variant;
  final KakaoButtonSize size;
  final bool loading;
  final String? semanticLabel;

  @override
  State<KakaoButton> createState() => _KakaoButtonState();
}

class _KakaoButtonState extends State<KakaoButton> {
  bool _hover = false;
  bool _pressed = false;
  bool _focusVisible = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final c = theme.colors;
    final s = _sizes[widget.size]!;
    final iconOnly = widget.label == null;

    // Colours: the --_primary-* / --_secondary-* … defaults of button.css.
    late Color bg, hoverBg, fg, ring;
    List<BoxShadow> shadow = const [];
    switch (widget.variant) {
      case KakaoButtonVariant.primary:
        bg = c.ink;
        hoverBg = c.inkHover;
        fg = c.onInk;
        ring = c.ink.withValues(alpha: .16);
        shadow = const [BoxShadow(offset: Offset(0, 2), blurRadius: 24, color: Color(0x0A000000))];
      case KakaoButtonVariant.secondary:
        bg = c.subtle;
        hoverBg = c.subtleStrong;
        fg = c.ink;
        ring = c.ink.withValues(alpha: .12);
      case KakaoButtonVariant.ghost:
        bg = c.ink.withValues(alpha: 0);
        hoverBg = c.ink.withValues(alpha: .045);
        fg = c.textSoft;
        ring = c.ink.withValues(alpha: .10);
      case KakaoButtonVariant.danger:
        bg = c.danger;
        hoverBg = c.dangerHover;
        fg = c.onDanger;
        ring = c.danger.withValues(alpha: .18);
        shadow = const [BoxShadow(offset: Offset(0, 2), blurRadius: 24, color: Color(0x0FBD4B43))];
    }
    // Touch has no hover: a pressed button shows the hover colour instead.
    final active = _enabled && (_hover || _pressed);
    final shadows = _focusVisible ? [BoxShadow(color: ring, spreadRadius: _focusRingWidth)] : shadow;

    final textStyle = theme
        .text(size: s.fontSize, weight: _labelWeight, color: fg)
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
        if (!iconOnly) Text(widget.label!, style: textStyle, maxLines: 1, softWrap: false),
      ],
    );

    Widget box = AnimatedContainer(
      duration: _transition,
      curve: Curves.ease,
      height: s.height,
      width: iconOnly ? s.height : null,
      padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : s.paddingX),
      decoration: BoxDecoration(
        color: active ? hoverBg : bg,
        borderRadius: BorderRadius.circular(iconOnly ? s.height / 2 : s.radius),
        boxShadow: shadows,
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedOpacity(opacity: widget.loading ? 0 : 1, duration: _transition, child: content),
          if (widget.loading) _Spinner(color: fg),
        ],
      ),
    );

    box = AnimatedOpacity(
      opacity: widget.onPressed == null ? _disabledOpacity : 1,
      duration: _transition,
      curve: Curves.ease,
      child: box,
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed?.call())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: _enabled ? widget.onPressed : null,
          child: box,
        ),
      ),
    );
  }
}

/// The button's loading arc: r 9 in a 24 box, stroke 3, dash 42 of 56.55,
/// one turn per 0.85s. Stands still when the platform asks for less motion.
class _Spinner extends StatefulWidget {
  const _Spinner({required this.color});
  final Color color;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _turn,
    child: CustomPaint(size: const Size.square(_spinnerSize), painter: _ArcPainter(widget.color)),
  );
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
