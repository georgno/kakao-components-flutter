// The chip's look (chip.js `.chip`, `.main`, `.label`, `.remove`), for the
// tags of tag-input until `<kakao-chip>` itself is ported (ROADMAP step 3):
// every value from the chip's own `--kakao-chip-*` settings, as the web tag
// input draws real <kakao-chip>s that follow them.
import 'package:flutter/widgets.dart';

import '../settings/kakao_chip_settings.g.dart';
import '../theme/kakao_theme.dart';
import '../theme/kakao_values.dart';
import 'kakao_field.dart';

/// chip.js `tone`: neutral (the default) or a tinted tone.
enum KakaoChipTone { neutral, primary, success, danger, ink }

// chip.js values outside the settings block.
const _removeInset = 6.0; // .remove width / height: calc(var(--_height) - 6px)
const _removeEnd = 3.0; // .remove margin-right: 3px
const _removePull = .5; // .remove margin-left: calc(var(--_padding-x) * -0.5)
const _removeOpacity = .7; // .remove opacity: 0.7 (1 on hover and focus)
const _removeHover = 12.0; // .remove:hover background: color-mix(currentColor 12%, transparent)
const _crossSize = .7; // .remove svg width / height: 0.7em
const _labelLineHeight = 1.3; // .label line-height: 1.3
const _outline = 2.0; // .remove:focus-visible outline: 2px solid var(--_focus); outline-offset: 2px

/// A chip's colours for a tone (chip.js `:host([tone])` rules), with
/// [fill] and [text] overriding `--kakao-chip-bg` / `--kakao-chip-text`
/// for the neutral tone (a tinted tone does not read them, as on the web).
({Color fill, Color text}) kakaoChipColors(KakaoChipSettings st, KakaoChipTone tone, {Color? fill, Color? text}) {
  Color tinted(Color c) => kakaoMix(c, st.tint * 100, st.surface, null);
  Color ink(Color c) => kakaoMix(c, st.textMix * 100, st.text, null);
  return switch (tone) {
    KakaoChipTone.neutral => (fill: fill ?? st.bg, text: text ?? st.text),
    KakaoChipTone.primary => (fill: tinted(st.primary), text: ink(st.primary)),
    KakaoChipTone.success => (fill: tinted(st.success), text: ink(st.success)),
    KakaoChipTone.danger => (fill: tinted(st.danger), text: ink(st.danger)),
    KakaoChipTone.ink => (fill: st.ink, text: st.onInk),
  };
}

/// A chip as chip.js draws it: `height` high, `radius` corners, the label
/// (`font-size`, `font-weight`, cut off with an ellipsis) `padding-x` from
/// both ends; [onRemove] adds the remove button: a ✕ in a square
/// `height - 6` px wide at the end (3 px from it, half the side padding
/// pulled in), at 70 % opacity, full with a 12 % fill under the pointer and
/// with [removeRing] (its keyboard focus: the 2 px focus outline 2 px away).
/// Its tap target is the whole height of the chip.
///
/// Not focusable itself: the owner wraps it in its own focus handling (a
/// tag input moves focus between its chips with the arrow keys).
class KakaoChipView extends StatefulWidget {
  const KakaoChipView({
    super.key,
    required this.label,
    required this.settings,
    this.tone = KakaoChipTone.neutral,
    this.fill,
    this.text,
    this.onRemove,
    this.removeLabel,
    this.removeRing = false,
  });

  final String label;
  final KakaoChipSettings settings;
  final KakaoChipTone tone;

  /// `--kakao-chip-bg` / `--kakao-chip-text` set from outside (neutral tone).
  final Color? fill;
  final Color? text;

  /// Null: no remove button (`removable` not set).
  final VoidCallback? onRemove;

  /// `remove-label`; default "Remove <label>".
  final String? removeLabel;
  final bool removeRing;

  @override
  State<KakaoChipView> createState() => _KakaoChipViewState();
}

class _KakaoChipViewState extends State<KakaoChipView> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = widget.settings;
    final colors = kakaoChipColors(st, widget.tone, fill: widget.fill, text: widget.text);
    final label = Text(
      widget.label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.text(size: st.fontSize, weight: st.fontWeight, color: colors.text, height: _labelLineHeight),
    );
    final onRemove = widget.onRemove;
    final side = st.height - _removeInset;
    Widget? remove;
    if (onRemove != null) {
      final lit = _hover || widget.removeRing;
      remove = Semantics(
        button: true,
        label: widget.removeLabel ?? 'Remove ${widget.label}'.trim(),
        onTap: onRemove,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: SizedBox(
              height: st.height,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: _removeEnd),
                child: Center(
                  child: KakaoRing(
                    color: widget.removeRing ? st.focus : null,
                    width: _outline,
                    offset: _outline,
                    radius: st.radius - 1,
                    child: Opacity(
                      opacity: lit ? 1 : _removeOpacity,
                      child: Container(
                        width: side,
                        height: side,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _hover ? kakaoMix(colors.text, _removeHover, const Color(0x00000000), null) : null,
                          borderRadius: BorderRadius.circular(st.radius - 1),
                        ),
                        child: CustomPaint(
                          size: Size.square(_crossSize * st.fontSize),
                          painter: KakaoCrossPainter(colors.text),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      height: st.height,
      decoration: BoxDecoration(color: colors.fill, borderRadius: BorderRadius.circular(st.radius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: st.paddingX),
          Flexible(child: label),
          if (remove == null) SizedBox(width: st.paddingX) else ...[SizedBox(width: st.paddingX * _removePull), remove],
        ],
      ),
    );
  }
}

/// chip.js's ✕: `M2 2l6 6M8 2l-6 6` in a 10 box, stroke 1.6, round caps.
class KakaoCrossPainter extends CustomPainter {
  const KakaoCrossPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 10;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(2 * k, 2 * k), Offset(8 * k, 8 * k), paint);
    canvas.drawLine(Offset(8 * k, 2 * k), Offset(2 * k, 8 * k), paint);
  }

  @override
  bool shouldRepaint(KakaoCrossPainter old) => old.color != color;
}
