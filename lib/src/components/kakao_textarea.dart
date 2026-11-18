import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_field.dart';
import '../settings/kakao_textarea_settings.g.dart';
import '../theme/kakao_theme.dart';

/// `<kakao-textarea size>`.
enum KakaoTextareaSize { sm, md, lg }

/// `<kakao-textarea resize>`: whether the person can drag the field taller
/// or shorter (the browser's resize grip in the bottom right corner).
enum KakaoTextareaResize { vertical, none }

// textarea.js values outside the settings block.
const _mdPadding = EdgeInsets.symmetric(
  vertical: 10,
  horizontal: 12,
); // --kakao-textarea-padding: 10px 12px (a list, not generated)
const _smSize = (
  padding: EdgeInsets.symmetric(vertical: 7, horizontal: 10),
  font: 14.0,
); // --kakao-textarea-sm-padding: 7px 10px; font-size 0.875rem
const _lgSize = (
  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
  font: 16.0,
); // --kakao-textarea-lg-padding: 12px 14px; font-size 1rem
const _labelSize = 13.12; // .label font-size: 0.82rem
const _messageSize = 12.48; // .hint, .error, .counter font-size: 0.78rem
const _counterGap = 12.0; // .below gap: 12px
const _fade = Duration(milliseconds: 150); // .field transition: border-color 150ms ease
const _fadeCurve = Curves.ease; // CSS `ease`
const _selectionAlpha = .25; // the text selection: the focus colour, light

// Chromium's resizer (not CSS): two diagonal strokes in the bottom right
// corner of the textarea, in a 15 px corner that takes the drag.
const _gripBox = 15.0;
const _gripStroke = 1.0;

/// Flutter twin of `<kakao-textarea>`: a multi-line text field with a
/// label, hint and error text, an optional character counter and optional
/// growing up to a height cap, in three sizes.
///
/// As textarea.js draws it from the `--kakao-textarea-*` settings: [label]
/// above (a tap on it focuses the field), [hint] below, or [error] instead
/// (danger border and outline, invalid in semantics); the [placeholder] in
/// the muted colour at the top while empty. The field is at least
/// `min-height` (88 px) high and, as the web textarea's `field-sizing:
/// content` in Chromium, grows with its text (the placeholder too); with
/// [autosize] up to [maxHeight] (default `max-height`, 288 px), then it
/// scrolls. Its border fades (150 ms) to the focus colour while it has
/// focus, which also draws the 2 px outline 2 px away. [disabled] dims
/// everything to `disabled-opacity` and takes the field out of the focus
/// order; [readOnly] keeps it focusable and selectable. It fills the width
/// it gets.
///
/// [resize] (not with [autosize]): the grip in the bottom right corner
/// drags the field to a fixed height (at least `min-height`); the text then
/// scrolls inside it.
///
/// [counter] shows the length below the field, at the end ("n / max" with
/// [maxLength], in the danger colour when the text is longer: [maxLength]
/// limits typing, not a [value] from the owner). [rows] is the least height
/// in lines (browsers without `field-sizing` use it; Chromium, the default
/// here, does not).
///
/// [onChanged] is the `input` event (every edit); [onCommitted] the
/// `change` event: when focus leaves, if the text differs from the text
/// when focus came. Enter is a new line.
///
/// The text is [controller]'s when given; otherwise [value] is the text the
/// field starts with, and a new [value] from the owner replaces the text,
/// without reporting it.
class KakaoTextarea extends StatefulWidget {
  const KakaoTextarea({
    super.key,
    this.value = '',
    this.controller,
    this.onChanged,
    this.onCommitted,
    this.label,
    this.semanticLabel,
    this.hint,
    this.error,
    this.placeholder,
    this.rows,
    this.maxLength,
    this.counter = false,
    this.autosize = false,
    this.maxHeight,
    this.resize = KakaoTextareaResize.vertical,
    this.inputFormatters,
    this.size = KakaoTextareaSize.md,
    this.disabled = false,
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
  });

  /// `value`: the text it starts with (ignored with a [controller]).
  final String value;

  /// Holds the text instead of [value] (`value` get / set, `select()`).
  final TextEditingController? controller;

  /// `input`: the text after each edit.
  final ValueChanged<String>? onChanged;

  /// `change`: the text when focus leaves, if it changed.
  final ValueChanged<String>? onCommitted;

  /// `label`: shown above the field.
  final String? label;

  /// `aria-label`: the name without a visible [label]; default the
  /// [placeholder], else [texts]`.name`.
  final String? semanticLabel;

  /// `hint`: below the field, hidden while there is an [error].
  final String? hint;

  /// `error`: the danger border and outline, the message below.
  final String? error;

  /// `placeholder`.
  final String? placeholder;

  /// `rows`: the least height in lines; null: `min-height` only (as
  /// Chromium, where `field-sizing: content` sets the textarea's rows aside).
  final int? rows;

  /// `maxlength`: limits typing; the counter's total.
  final int? maxLength;

  /// `counter`.
  final bool counter;

  /// `autosize`: grows up to [maxHeight], no resize grip.
  final bool autosize;

  /// `max-height`: the cap for [autosize]; null: the `max-height` setting.
  final double? maxHeight;

  /// `resize`.
  final KakaoTextareaResize resize;

  /// More input formatters, after [maxLength]'s.
  final List<TextInputFormatter>? inputFormatters;

  /// `size`.
  final KakaoTextareaSize size;

  /// `disabled`.
  final bool disabled;

  /// `readonly`.
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;

  /// `KakaoTextarea.texts`: textarea.js's built-in English texts.
  static ({String name}) texts = (name: 'Text');

  @override
  State<KakaoTextarea> createState() => _KakaoTextareaState();
}

class _KakaoTextareaState extends State<KakaoTextarea> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'KakaoTextarea'));
  TextEditingController? _ownText;
  TextEditingController get _text => widget.controller ?? (_ownText ??= TextEditingController(text: widget.value));
  late KakaoChangeTracker _change = KakaoChangeTracker(_text);

  final _group = Object();
  bool _focused = false;

  /// The height the grip dragged the field to (the textarea's inline
  /// `height`); null: its content's.
  double? _dragged;
  double _dragStart = 0;
  final _boxKey = GlobalKey();

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  bool get _resizable => widget.resize == KakaoTextareaResize.vertical && !widget.autosize;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
    _text.addListener(_textChanged);
    if (widget.autofocus && !widget.disabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(KakaoTextarea old) {
    super.didUpdateWidget(old);
    final oldFocus = old.focusNode ?? _ownFocus;
    if (oldFocus != _focus) {
      oldFocus?.removeListener(_focusChanged);
      _focus.addListener(_focusChanged);
      _focused = _focus.hasFocus;
    }
    final oldText = old.controller ?? _ownText;
    if (oldText != _text) {
      oldText?.removeListener(_textChanged);
      _text.addListener(_textChanged);
      _change = KakaoChangeTracker(_text);
    }
    // autosize sets the inline height aside (its _grow writes its own).
    if (!_resizable) _dragged = null;
    if (widget.controller == null && widget.value != old.value && widget.value != _text.text) {
      _text.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _text.removeListener(_textChanged);
    _ownFocus?.dispose();
    _ownText?.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (!mounted) return;
    final focused = _focus.hasFocus;
    if (focused == _focused) return;
    setState(() => _focused = focused);
    if (focused) {
      _change.reset();
    } else if (_change.commit()) {
      widget.onCommitted?.call(_text.text);
    }
  }

  /// The counter follows the text, whoever changed it.
  void _textChanged() {
    if (widget.counter && mounted) setState(() {});
  }

  /// A tap in the textarea but past its text (the padding, the room below
  /// the last line): focus, caret at the end.
  void _tapBelow() {
    if (widget.disabled) return;
    _focus.requestFocus();
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoTextareaSettings.of(theme.colors);
    final (padding, fontSize) = switch (widget.size) {
      KakaoTextareaSize.sm => (_smSize.padding, _smSize.font),
      KakaoTextareaSize.md => (_mdPadding, st.font.size),
      KakaoTextareaSize.lg => (_lgSize.padding, _lgSize.font),
    };
    final error = widget.error?.isNotEmpty ?? false ? widget.error : null;
    final hint = widget.hint?.isNotEmpty ?? false ? widget.hint : null;
    final placeholder = widget.placeholder?.isNotEmpty ?? false ? widget.placeholder : null;
    final name = widget.label ?? widget.semanticLabel ?? placeholder ?? KakaoTextarea.texts.name;
    final disabled = widget.disabled;
    // textarea { line-height: 1.5 }: the font setting's.
    final style = theme.text(size: fontSize, color: st.text, height: st.font.lineHeight);

    // min-height (border-box: with the padding); rows lines in a browser
    // without field-sizing.
    var minHeight = st.minHeight;
    if (widget.rows case final rows?) {
      minHeight = math.max(minHeight, math.max(1, rows) * fontSize * st.font.lineHeight + padding.vertical);
    }
    final dragged = _dragged;
    final double maxHeight = dragged != null
        ? math.max(dragged, minHeight)
        : widget.autosize
        ? math.max(widget.maxHeight ?? st.maxHeight, minHeight)
        : double.infinity;

    Widget input = KakaoFieldText(
      controller: _text,
      focusNode: _focus,
      style: style,
      placeholder: placeholder,
      placeholderColor: st.muted,
      cursorColor: st.text,
      selectionColor: st.focus.withValues(alpha: _selectionAlpha),
      enabled: !disabled,
      readOnly: widget.readOnly,
      maxLines: null,
      inputFormatters: [
        if (widget.maxLength case final max?) LengthLimitingTextInputFormatter(max),
        ...?widget.inputFormatters,
      ],
      onChanged: widget.onChanged,
      groupId: _group,
    );
    input = Semantics(
      label: name,
      hint: error ?? hint,
      enabled: !disabled,
      readOnly: widget.readOnly,
      multiline: true,
      validationResult: error != null ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
      child: ExcludeFocus(excluding: disabled, child: input),
    );

    // The textarea: its padding around the text, min-height, and the cap
    // (autosize's max-height or the dragged height) past which it scrolls.
    Widget area = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
      child: Padding(
        padding: padding,
        child: Align(alignment: AlignmentDirectional.topStart, heightFactor: 1, child: input),
      ),
    );
    if (dragged != null) area = SizedBox(height: maxHeight, child: area);
    area = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : _tapBelow,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.text,
        child: SizedBox(key: _boxKey, width: double.infinity, child: area),
      ),
    );
    if (_resizable) {
      area = Stack(
        children: [
          area,
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: _Grip(
              color: st.muted,
              onStart: disabled ? null : () => _dragStart = _boxKey.currentContext!.size!.height,
              onDrag: disabled ? null : (dy) => setState(() => _dragged = math.max(minHeight, (_dragStart += dy))),
            ),
          ),
        ],
      );
    }

    final box = KakaoFieldBox(
      // .field: the textarea's min-height and its 1 px border.
      height: minHeight + 2,
      paddingX: 0,
      radius: st.radius,
      background: st.bg,
      border: error != null
          ? st.danger
          : _focused
          ? st.focus
          : st.border,
      ring: _focused && !disabled ? (error != null ? st.danger : st.focus) : null,
      ringWidth: st.focusWidth,
      ringOffset: st.focusOffset,
      duration: _reduceMotion ? Duration.zero : _fade,
      curve: _fadeCurve,
      child: ClipRRect(borderRadius: BorderRadius.circular(math.max(0, st.radius - 1)), child: area),
    );

    Widget? counter;
    if (widget.counter) {
      final len = _text.text.length;
      final max = widget.maxLength;
      counter = Text(
        max != null ? '$len / $max' : '$len',
        maxLines: 1,
        softWrap: false,
        style: theme
            .text(size: _messageSize, height: st.font.lineHeight)
            .copyWith(
              color: max != null && len > max ? st.danger : st.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      );
    }

    return KakaoField(
      label: widget.label,
      message: error ?? hint,
      messageColor: error != null ? st.danger : st.muted,
      labelStyle: theme.text(size: _labelSize, weight: st.labelWeight, color: st.text, height: st.font.lineHeight),
      messageStyle: theme.text(size: _messageSize, height: st.font.lineHeight),
      labelGap: st.labelGap,
      messageGap: st.messageGap,
      counter: counter,
      counterGap: _counterGap,
      disabledOpacity: disabled ? st.disabledOpacity : null,
      onLabelTap: disabled ? null : _focus.requestFocus,
      child: box,
    );
  }
}

/// Chromium's textarea resizer: a long and a short diagonal stroke in the
/// bottom right corner; a vertical drag there sets the height.
class _Grip extends StatelessWidget {
  const _Grip({required this.color, required this.onStart, required this.onDrag});

  final Color color;
  final VoidCallback? onStart;
  final ValueChanged<double>? onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onDrag == null ? SystemMouseCursors.basic : SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: onStart == null ? null : (_) => onStart!(),
        onVerticalDragUpdate: onDrag == null ? null : (d) => onDrag!(d.delta.dy),
        child: CustomPaint(size: const Size.square(_gripBox), painter: _GripPainter(color)),
      ),
    );
  }
}

class _GripPainter extends CustomPainter {
  const _GripPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..strokeWidth = _gripStroke
      ..strokeCap = StrokeCap.butt;
    // Measured on Chromium at 4x: the long stroke from 2 px in at the right,
    // 9 px up to 9 px in, 2 px up; the short one 5 px long.
    canvas.drawLine(Offset(w - 2, h - 9), Offset(w - 9, h - 2), paint);
    canvas.drawLine(Offset(w - 2, h - 5), Offset(w - 5, h - 2), paint);
  }

  @override
  bool shouldRepaint(_GripPainter old) => old.color != color;
}
