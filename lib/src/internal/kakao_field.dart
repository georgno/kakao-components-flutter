import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// Field chrome shared by the field-like widgets (select, combobox; the text
// input family next, ROADMAP step 2). Every value comes from the caller, out
// of its own component's settings: the web components each draw this
// themselves.

/// The chrome around a field (`.label`, `.hint`, `.error`,
/// `:host([disabled])` in select.js and combobox.js): the label above, the
/// hint or error below, the whole dimmed when disabled.
///
/// The label and the message are left out of semantics: the field's own
/// semantics carries them (its name and its hint, as `aria-describedby`).
class KakaoField extends StatelessWidget {
  const KakaoField({
    super.key,
    required this.label,
    required this.message,
    required this.messageColor,
    required this.labelStyle,
    required this.messageStyle,
    required this.labelGap,
    required this.messageGap,
    required this.disabledOpacity,
    required this.onLabelTap,
    required this.child,
  });

  final String? label;

  /// The error, else the hint; null: none.
  final String? message;
  final Color messageColor;
  final TextStyle labelStyle;
  final TextStyle messageStyle;
  final double labelGap;
  final double messageGap;

  /// Not null: disabled, at this opacity.
  final double? disabledOpacity;

  /// A tap on the label (`<label for>`: it focuses the field).
  final VoidCallback? onLabelTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    final message = this.message;
    Widget field = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null && label.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: labelGap),
            child: ExcludeSemantics(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onLabelTap,
                  child: Text(label, style: labelStyle),
                ),
              ),
            ),
          ),
        child,
        if (message != null)
          Padding(
            padding: EdgeInsets.only(top: messageGap),
            child: ExcludeSemantics(
              child: Text(message, style: messageStyle.copyWith(color: messageColor)),
            ),
          ),
      ],
    );
    final o = disabledOpacity;
    if (o != null) field = Opacity(opacity: o, child: field);
    return field;
  }
}

/// The bordered field box (select.js `.trigger`, combobox.js `.field`): min
/// height, side padding, 1 px border fading between colours, and the
/// keyboard focus outline [ring] [ringWidth] wide, [ringOffset] outside the
/// border.
class KakaoFieldBox extends StatelessWidget {
  const KakaoFieldBox({
    super.key,
    required this.height,
    required this.paddingX,
    required this.radius,
    required this.background,
    required this.border,
    required this.ring,
    required this.ringWidth,
    required this.ringOffset,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final double height;
  final double paddingX;
  final double radius;
  final Color background;
  final Color border;
  final Color? ring;
  final double ringWidth;
  final double ringOffset;
  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final box = AnimatedContainer(
      duration: duration,
      curve: curve,
      constraints: BoxConstraints(minHeight: height),
      padding: EdgeInsets.symmetric(horizontal: paddingX),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    return KakaoRing(color: ring, width: ringWidth, offset: ringOffset, radius: radius, child: box);
  }
}

/// A CSS `outline`: [width] wide, [offset] outside [child], following its
/// corner [radius]. Nothing when [color] is null.
class KakaoRing extends StatelessWidget {
  const KakaoRing({
    super.key,
    required this.color,
    required this.width,
    required this.offset,
    required this.radius,
    required this.child,
  });

  final Color? color;
  final double width;
  final double offset;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    if (color == null) return child;
    final out = -(offset + width);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: out,
          top: out,
          right: out,
          bottom: out,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: color, width: width),
                borderRadius: BorderRadius.circular(radius + offset + width),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A one-line text field without chrome (the `<input>` inside a field box):
/// an [EditableText] with the platform's pointer gestures (tap to place the
/// caret, drag and double tap to select), the [placeholder] in
/// [placeholderColor] while empty, and [onTap] after a tap on it (the
/// input's `click`).
///
/// [groupId] is its tap region group: a pointer down outside the group
/// ends the editing (unfocuses it), as a pointer down elsewhere blurs an
/// input; put a panel that belongs to the field in the same group.
class KakaoFieldText extends StatefulWidget {
  const KakaoFieldText({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.placeholder,
    required this.placeholderColor,
    required this.cursorColor,
    required this.selectionColor,
    this.enabled = true,
    this.inputFormatters,
    this.onChanged,
    this.onTap,
    this.groupId = EditableText,
    this.selectAllOnFocus,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final String? placeholder;
  final Color placeholderColor;
  final Color cursorColor;
  final Color selectionColor;

  /// False: read only and not focusable (`disabled`).
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Object groupId;

  /// Whether focus selects all the text; null: the platform's way (all on
  /// web and desktop, as a tab into an `<input>` does). False keeps the
  /// caret where it is, as `input.focus()` from script does.
  final bool? selectAllOnFocus;

  /// The browser's text caret width.
  static const caretWidth = 1.0;

  @override
  State<KakaoFieldText> createState() => _KakaoFieldTextState();
}

class _KakaoFieldTextState extends State<KakaoFieldText> implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => widget.enabled;

  late final _gestures = _Gestures(this);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(KakaoFieldText old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  bool _empty = true;

  void _changed() {
    final empty = widget.controller.text.isEmpty;
    if (empty != _empty && mounted) setState(() => _empty = empty);
  }

  @override
  Widget build(BuildContext context) {
    _empty = widget.controller.text.isEmpty;
    final placeholder = widget.placeholder;
    final editable = EditableText(
      key: editableTextKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      readOnly: !widget.enabled,
      style: widget.style,
      cursorColor: widget.cursorColor,
      cursorWidth: KakaoFieldText.caretWidth,
      backgroundCursorColor: widget.placeholderColor,
      selectionColor: widget.selectionColor,
      maxLines: 1,
      autocorrect: false,
      enableSuggestions: false,
      enableInteractiveSelection: widget.enabled,
      rendererIgnoresPointer: true,
      textInputAction: TextInputAction.done,
      inputFormatters: widget.inputFormatters,
      groupId: widget.groupId,
      selectAllOnFocus: widget.selectAllOnFocus,
      onTapOutside: (_) => widget.focusNode.unfocus(),
      onChanged: widget.onChanged,
    );
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: _gestures.buildGestureDetector(
          behavior: HitTestBehavior.translucent,
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              if (_empty && placeholder != null && placeholder.isNotEmpty)
                ExcludeSemantics(
                  child: Text(
                    placeholder,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: widget.style.copyWith(color: widget.placeholderColor),
                  ),
                ),
              editable,
            ],
          ),
        ),
      ),
    );
  }
}

class _Gestures extends TextSelectionGestureDetectorBuilder {
  _Gestures(_KakaoFieldTextState state) : _state = state, super(delegate: state);

  final _KakaoFieldTextState _state;

  @override
  void onSingleTapUp(TapDragUpDetails details) {
    super.onSingleTapUp(details);
    _state.widget.onTap?.call();
  }
}

/// The chevron of select.js and combobox.js: `M6 9l6 6 6-6` in a 24 box,
/// stroke 2.4, round caps and joins.
class KakaoChevronPainter extends CustomPainter {
  const KakaoChevronPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.drawPath(
      Path()
        ..moveTo(6 * k, 9 * k)
        ..lineTo(12 * k, 15 * k)
        ..lineTo(18 * k, 9 * k),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(KakaoChevronPainter old) => old.color != color;
}

const _foldFrom = 'àáâãäåāăąçćĉċčďèéêëēĕėęěĝğġģĥìíîïĩīĭįĵķĺļľñńņňòóôõöōŏőŕŗřśŝşšţťùúûüũūŭůűųŵýÿŷźżž';
const _foldTo = 'aaaaaaaaacccccdeeeeeeeeegggghiiiiiiiijklllnnnnoooooooorrrssssttuuuuuuuuuuwyyyzzz';

/// select.js and combobox.js `fold`: lower case without accents (NFD,
/// combining marks dropped), for matching.
String kakaoFold(String s) {
  final out = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    if (r >= 0x300 && r <= 0x36f) continue;
    final c = String.fromCharCode(r);
    final i = _foldFrom.indexOf(c);
    out.write(i < 0 ? c : _foldTo[i]);
  }
  return out.toString();
}
