// The parts date-input and time-input share around their segmented field:
// the picker icon (Chromium's `::-webkit-calendar-picker-indicator`, redrawn
// with the components' own glyphs) and the today / now tag under the field.
// Not exported; each owner feeds them its own settings.
import 'package:flutter/widgets.dart';

import 'kakao_field.dart';

/// The picker icon (Chromium's `::-webkit-calendar-picker-indicator`,
/// redrawn): a tab stop of its own, the muted colour, the text colour under
/// the pointer, the focus colour while it has focus.
class KakaoPickerIcon extends StatefulWidget {
  const KakaoPickerIcon({
    super.key,
    required this.focusNode,
    required this.size,
    required this.clock,
    required this.color,
    required this.hoverColor,
    required this.focusColor,
    required this.enabled,
    required this.semanticLabel,
    required this.onTap,
  });

  final FocusNode focusNode;
  final double size;
  final bool clock;
  final Color color;
  final Color hoverColor;
  final Color focusColor;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  State<KakaoPickerIcon> createState() => _KakaoPickerIconState();
}

class _KakaoPickerIconState extends State<KakaoPickerIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.focusNode.hasFocus
        ? widget.focusColor
        : _hover
        ? widget.hoverColor
        : widget.color;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      onTap: widget.enabled ? widget.onTap : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onFocusChange: (_) => setState(() {}),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (widget.enabled) widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _GlyphPainter(clock: widget.clock, color: color),
          ),
        ),
      ),
    );
  }
}

/// date-input.js `CALENDAR` / `CLOCK` (time-input.js `CLOCK` is the same): 24-unit glyphs, stroke 2, round caps
/// and joins.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.clock, required this.color});
  final bool clock;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (clock) {
      // <circle cx='12' cy='12' r='8.5'/><path d='M12 7.5V12l3 2'/>
      canvas.drawCircle(const Offset(12, 12), 8.5, p);
      canvas.drawPath(
        Path()
          ..moveTo(12, 7.5)
          ..lineTo(12, 12)
          ..lineTo(15, 14),
        p,
      );
    } else {
      // <rect x='3.5' y='5' width='17' height='15.5' rx='2.5'/><path d='M3.5 10h17M8 3v4M16 3v4'/>
      canvas.drawRRect(RRect.fromLTRBR(3.5, 5, 20.5, 20.5, const Radius.circular(2.5)), p);
      canvas.drawPath(
        Path()
          ..moveTo(3.5, 10)
          ..lineTo(20.5, 10)
          ..moveTo(8, 3)
          ..lineTo(8, 7)
          ..moveTo(16, 3)
          ..lineTo(16, 7),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.clock != clock || old.color != color;
}

/// The today tag (date-input.js `.today`, time-input.js `.now`): the chip's neutral tag as a real button,
/// today-height high, its hover fill, the focus outline, disabled (out of
/// range) at disabled-opacity with the reason in semantics.
class KakaoTodayTag extends StatefulWidget {
  const KakaoTodayTag({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.reason,
    required this.style,
    required this.height,
    required this.paddingX,
    required this.radius,
    required this.background,
    required this.hoverBackground,
    required this.focus,
    required this.focusWidth,
    required this.focusOffset,
    required this.disabledOpacity,
    required this.duration,
    required this.curve,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final String? reason;
  final TextStyle style;
  final double height;
  final double paddingX;
  final double radius;
  final Color background;
  final Color hoverBackground;
  final Color focus;
  final double focusWidth;
  final double focusOffset;
  final double disabledOpacity;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onTap;

  @override
  State<KakaoTodayTag> createState() => _KakaoTodayTagState();
}

class _KakaoTodayTagState extends State<KakaoTodayTag> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget tag = AnimatedContainer(
      duration: widget.duration,
      curve: widget.curve,
      height: widget.height,
      padding: EdgeInsets.symmetric(horizontal: widget.paddingX),
      decoration: BoxDecoration(
        color: _hover && enabled ? widget.hoverBackground : widget.background,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      // inline-flex: as wide as the label.
      child: Align(widthFactor: 1, child: Text(widget.label, maxLines: 1, softWrap: false, style: widget.style)),
    );
    tag = KakaoRing(
      color: _focus ? widget.focus : null,
      width: widget.focusWidth,
      offset: widget.focusOffset,
      radius: widget.radius,
      child: tag,
    );
    if (!enabled) tag = Opacity(opacity: widget.disabledOpacity, child: tag);
    return Semantics(
      button: true,
      // aria-disabled: still focusable, says why.
      enabled: enabled,
      label: widget.semanticLabel,
      hint: widget.reason,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: tag),
      ),
    );
  }
}
