import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// Field chrome shared by the field-like widgets (select, combobox, command
// palette, the text input family of ROADMAP step 2). Every value comes from the caller, out
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

/// A text field without chrome (the `<input>` inside a field box; with
/// [maxLines] other than 1, a `<textarea>`): an [EditableText] with the
/// platform's pointer gestures (tap to place the caret, drag and double tap
/// to select), the [placeholder] in [placeholderColor] while empty (centred
/// on one line, at the top of several), and [onTap] after a tap on it (the
/// input's `click`).
///
/// [readOnly] (`readonly`) keeps it focusable and selectable; [enabled]
/// false (`disabled`) takes both away. [keyboardType], [obscureText] and
/// [autofillHints] stand for the input's `type`, `inputmode` and
/// `autocomplete`; [onSubmitted] is Enter on one line.
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
    this.readOnly = false,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
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

  /// Focusable and selectable, but not editable (`readonly`).
  final bool readOnly;

  /// Null: text on one line, multiline on several.
  final TextInputType? keyboardType;

  /// Shown as dots (`type="password"`).
  final bool obscureText;
  final Iterable<String>? autofillHints;

  /// 1: one line (an `<input>`); null: grows without limit.
  final int? maxLines;
  final int? minLines;

  /// Null: done on one line, a new line on several.
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  /// Enter on one line (the input's implicit `change`).
  final ValueChanged<String>? onSubmitted;
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
    final oneLine = widget.maxLines == 1;
    final editable = EditableText(
      key: editableTextKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      readOnly: !widget.enabled || widget.readOnly,
      style: widget.style,
      cursorColor: widget.cursorColor,
      cursorWidth: KakaoFieldText.caretWidth,
      backgroundCursorColor: widget.placeholderColor,
      selectionColor: widget.selectionColor,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: widget.keyboardType ?? (oneLine ? TextInputType.text : TextInputType.multiline),
      obscureText: widget.obscureText,
      autofillHints: widget.autofillHints,
      autocorrect: false,
      enableSuggestions: false,
      enableInteractiveSelection: widget.enabled,
      rendererIgnoresPointer: true,
      textInputAction: widget.textInputAction ?? (oneLine ? TextInputAction.done : TextInputAction.newline),
      inputFormatters: widget.inputFormatters,
      groupId: widget.groupId,
      selectAllOnFocus: widget.selectAllOnFocus,
      onTapOutside: (_) => widget.focusNode.unfocus(),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: _gestures.buildGestureDetector(
          behavior: HitTestBehavior.translucent,
          child: Stack(
            alignment: oneLine ? AlignmentDirectional.centerStart : AlignmentDirectional.topStart,
            children: [
              if (_empty && placeholder != null && placeholder.isNotEmpty)
                ExcludeSemantics(
                  child: Text(
                    placeholder,
                    maxLines: oneLine ? 1 : null,
                    softWrap: !oneLine,
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

/// The `change` event of an `<input>` or `<textarea>`: [commit] when focus
/// leaves (and on Enter in one line) is true when the text differs from
/// the text at the last [reset] (focus gained, or the last change).
class KakaoChangeTracker {
  KakaoChangeTracker(this.controller) : _base = controller.text;

  final TextEditingController controller;
  String _base;

  /// The text now is the one later commits compare with.
  void reset() => _base = controller.text;

  /// Whether the text changed since the last [reset] or commit; resets.
  bool commit() {
    final changed = controller.text != _base;
    _base = controller.text;
    return changed;
  }
}

/// A small round button inside a field box (text-input.js `.clear`, the
/// file upload's remove): [size] square, [background] always, the glyph in
/// [color] and [hoverColor] under the pointer. Pointer only, as the web's
/// `tabindex="-1"`: not in the focus order, but a labelled button in
/// semantics. It belongs to the tap region [groupId], so a tap on it does
/// not end the editing of the field it sits in.
class KakaoFieldButton extends StatefulWidget {
  const KakaoFieldButton({
    super.key,
    required this.size,
    required this.background,
    required this.color,
    required this.hoverColor,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.groupId = EditableText,
  });

  final double size;
  final Color background;
  final Color color;
  final Color hoverColor;
  final String semanticLabel;

  /// Null: shown, but does nothing.
  final VoidCallback? onTap;

  /// Drawn in an [IconTheme] and [DefaultTextStyle] of the current colour.
  final Widget child;
  final Object groupId;

  @override
  State<KakaoFieldButton> createState() => _KakaoFieldButtonState();
}

class _KakaoFieldButtonState extends State<KakaoFieldButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover ? widget.hoverColor : widget.color;
    return TapRegion(
      groupId: widget.groupId,
      child: Semantics(
        button: true,
        label: widget.semanticLabel,
        onTap: widget.onTap,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: widget.onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: widget.background, shape: BoxShape.circle),
              child: IconTheme.merge(
                data: IconThemeData(color: color),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: color),
                  child: widget.child,
                ),
              ),
            ),
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
