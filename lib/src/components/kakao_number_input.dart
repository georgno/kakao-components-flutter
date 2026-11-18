import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_field.dart';
import '../settings/kakao_number_input_settings.g.dart';
import '../theme/kakao_theme.dart';

/// `<kakao-number-input size>`.
enum KakaoNumberInputSize { sm, md }

/// Where a stepper sits in the touch layout (`plus` / `minus`), or
/// [none] to leave it out (`"false"`). The sides are physical, as on the web.
enum KakaoStepperSide { left, right, none }

// number-input.css / number-input.js values outside the settings block.
const _lineHeight = 1.5; // input line-height: 1.5
const _touchMinFont = 16.0; // [data-touch] input font-size: max(16px, 1em)
const _touchPadX = 12.0; // [data-touch] input padding-left / -right: calc(steps * touch-size + 12px)
const _touchGap = 4.0; // [data-touch] .arrows gap: 4px (0 when grouped)
const _touchGlyphWeight = 500.0; // [data-touch] span::before font-weight: 500
const _fade = Duration(milliseconds: 150); // input transition: border-color .15s ease
const _fadeCurve = Curves.ease; // CSS `ease`
const _repeatDelay = Duration(milliseconds: 400); // _onPress: setTimeout(…, 400)
const _repeatEvery = Duration(milliseconds: 70); // _onPress: setInterval(…, 70)
const _selectionAlpha = .25; // the text selection: the focus colour, light
// The characters Chromium lets into an <input type="number">.
final _allowed = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,eE+\-]'));
// A valid floating-point number (HTML): what input.value keeps of the text.
final _validNumber = RegExp(r'^-?(\d+(\.\d+)?|\.\d+)([eE][+-]?\d+)?$');

/// Flutter twin of `<kakao-number-input>`: a number field with its own
/// stepper buttons, stepping by [step] between [min] and [max].
///
/// As number-input.css draws it from the `--kakao-number-input-*`
/// settings: the input with `input-padding` (`input-padding-right` on the
/// right, room for the steppers), line height 1.5, `input-radius`; its
/// border fades (150 ms) to `focus-color` while it has focus, which also
/// draws the `focus-width` outline `focus-offset` away. [disabled] dims it
/// to `disabled-opacity`, steppers included.
///
/// With a mouse the steppers are the stacked ▲ / ▼ strip on the right
/// (`arrow-width` wide, `arrow-size` glyphs, a line between; hover and
/// pressed fills). On a touch platform (`pointer: coarse`: Android, iOS,
/// Fuchsia), or always with [touchSteppers], they are 44 px − and +
/// buttons (`touch-size`, `touch-glyph-size`) and the field is at least as
/// tall, with `touch-radius` corners. [plus] and [minus] put them on a side
/// or leave them out; [grouped] (the default) keeps two visible buttons
/// together as one joined pair on [groupPosition]; a divider in the
/// `divider` colour separates each button from the value. The default is
/// | value | − + |. With a mouse only the leaving out applies.
///
/// A press on a stepper steps at once, then every 70 ms after 400 ms while
/// held; the mouse wheel over the steppers steps up (wheel up) or down.
/// Arrow Up / Down in the field step too. A step adds [step] to the value
/// (an empty or invalid text counts as 0), clamps to [min] / [max] and
/// rounds to the decimals of [step]; it reports [onChanged] and
/// [onCommitted] at once. A press keeps focus where it is. Steppers are not
/// in the focus order or in semantics (aria-hidden); the field reports
/// increase and decrease actions instead.
///
/// [onChanged] is the `input` event (the number, or null when the text is
/// empty or not a number); [onCommitted] the `change` event: when focus
/// leaves or on Enter, if the text changed. The text is [controller]'s when
/// given; otherwise [value] is the number the field starts with, and a new
/// [value] from the owner shows without being reported.
class KakaoNumberInput extends StatefulWidget {
  const KakaoNumberInput({
    super.key,
    this.value,
    this.controller,
    this.min,
    this.max,
    this.step = 1,
    this.onChanged,
    this.onCommitted,
    this.semanticLabel,
    this.placeholder,
    this.size = KakaoNumberInputSize.md,
    this.touchSteppers = false,
    this.plus = KakaoStepperSide.right,
    this.minus = KakaoStepperSide.right,
    this.grouped = true,
    this.groupPosition = KakaoStepperSide.right,
    this.disabled = false,
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
  });

  /// The input's `value` (ignored with a [controller]); null: empty.
  final double? value;

  /// Holds the text instead of [value].
  final TextEditingController? controller;

  /// The input's `min` / `max`; null: no limit.
  final double? min;
  final double? max;

  /// The input's `step`; not above 0 counts as 1.
  final double step;

  /// `input`: the number after each edit or step (null: empty or invalid).
  final ValueChanged<double?>? onChanged;

  /// `change`: after a step, and when focus leaves or Enter is pressed if
  /// the text changed.
  final ValueChanged<double?>? onCommitted;

  /// The input's `aria-label`; default the [placeholder], else
  /// [texts]`.name`.
  final String? semanticLabel;

  /// The input's `placeholder`.
  final String? placeholder;

  /// `size`.
  final KakaoNumberInputSize size;

  /// `touch-steppers`: the touch layout with any pointer.
  final bool touchSteppers;

  /// `plus` / `minus`: the button's side in the touch layout, or none.
  final KakaoStepperSide plus;
  final KakaoStepperSide minus;

  /// `grouped`: two visible buttons as one pair on [groupPosition].
  final bool grouped;

  /// `group-position`: [KakaoStepperSide.left] or right.
  final KakaoStepperSide groupPosition;

  /// The input's `disabled`.
  final bool disabled;

  /// The input's `readonly`: focusable and selectable; neither typing nor
  /// the steppers change it.
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;

  /// `KakaoNumberInput.texts`: the default name.
  static ({String name}) texts = (name: 'Number');

  /// The text number-input.js writes for [value] (`input.value = number`):
  /// no decimal point for a whole number.
  static String format(double value) {
    if (value.isFinite && value == value.truncateToDouble() && value.abs() < 1e21) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  /// What `parseFloat(input.value)` gives for [text]: null when the text is
  /// empty or not a valid number (the input's value is then "").
  static double? parse(String text) {
    final t = text.trim();
    if (!_validNumber.hasMatch(t)) return null;
    return double.tryParse(t);
  }

  @override
  State<KakaoNumberInput> createState() => _KakaoNumberInputState();
}

class _KakaoNumberInputState extends State<KakaoNumberInput> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'KakaoNumberInput'));
  TextEditingController? _ownText;
  TextEditingController get _text =>
      widget.controller ??
      (_ownText ??= TextEditingController(text: widget.value == null ? '' : KakaoNumberInput.format(widget.value!)));
  late KakaoChangeTracker _change = KakaoChangeTracker(_text);

  /// The steppers' tap region: a press keeps the editing going.
  final _group = Object();
  bool _focused = false;
  Timer? _repeat;

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  bool get _inert => widget.disabled || widget.readOnly;

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
  void didUpdateWidget(KakaoNumberInput old) {
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
    // A new value from the owner shows without reporting.
    final value = widget.value;
    if (widget.controller == null && value != old.value && value != KakaoNumberInput.parse(_text.text)) {
      final text = value == null ? '' : KakaoNumberInput.format(value);
      _text.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    if (_inert) _stopRepeat();
  }

  @override
  void dispose() {
    _stopRepeat();
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
    } else {
      _commit();
    }
  }

  /// The increase / decrease values in semantics follow the text.
  void _textChanged() {
    if (mounted) setState(() {});
  }

  void _commit() {
    if (_change.commit()) widget.onCommitted?.call(KakaoNumberInput.parse(_text.text));
  }

  double get _step => widget.step.isFinite && widget.step > 0 ? widget.step : 1;

  /// number-input.js `_decimals`: the decimals of the step.
  int get _decimals {
    final s = _step;
    if (s % 1 == 0) return 0;
    final parts = s.toString().split('.');
    return parts.length > 1 ? parts[1].length : 0;
  }

  /// number-input.js `_adjust`: step, clamp, round; then `input` and
  /// `change`.
  void _adjust(int direction) {
    if (_inert) return;
    final base = KakaoNumberInput.parse(_text.text) ?? 0;
    final next = base + direction * _step;
    final clamped = math.min(widget.max ?? double.infinity, math.max(widget.min ?? double.negativeInfinity, next));
    final value = double.parse(clamped.toStringAsFixed(_decimals));
    final text = KakaoNumberInput.format(value);
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _change.reset();
    widget.onChanged?.call(value);
    widget.onCommitted?.call(value);
  }

  /// `_onPress`: one step at once, then repeat while held.
  void _press(int direction) {
    _stopRepeat();
    if (_inert) return;
    _adjust(direction);
    _repeat = Timer(_repeatDelay, () {
      _repeat = Timer.periodic(_repeatEvery, (_) => _adjust(direction));
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  /// `_onWheel`: on the steppers, wheel up steps up.
  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _inert) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      _adjust((e as PointerScrollEvent).scrollDelta.dy < 0 ? 1 : -1);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowUp && key != LogicalKeyboardKey.arrowDown) return KeyEventResult.ignored;
    if (_inert) return KeyEventResult.handled;
    _adjust(key == LogicalKeyboardKey.arrowUp ? 1 : -1);
    return KeyEventResult.handled;
  }

  /// The stepper's events (`pointerdown` / `pointerup` / `pointerleave` /
  /// `pointercancel` / `wheel` on the strip).
  Widget _pointer({required Widget child, int? direction}) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: direction == null ? null : (_) => _press(direction),
    onPointerUp: (_) => _stopRepeat(),
    onPointerCancel: (_) => _stopRepeat(),
    onPointerSignal: _wheel,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoNumberInputSettings.of(theme.colors);
    final touch =
        widget.touchSteppers ||
        switch (defaultTargetPlatform) {
          TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => true,
          _ => false,
        };
    final sm = widget.size == KakaoNumberInputSize.sm;
    // --_font-size: inherit (the surrounding DefaultTextStyle's size),
    // sm-font-size for sm; the touch layout at least 16 px.
    final baseFont = sm ? st.smFontSize : DefaultTextStyle.of(context).style.fontSize ?? theme.tokens.fontSize;
    final fontSize = touch ? math.max(_touchMinFont, baseFont) : baseFont;
    final disabled = widget.disabled;
    final placeholder = widget.placeholder?.isNotEmpty ?? false ? widget.placeholder : null;
    final name = widget.semanticLabel ?? placeholder ?? KakaoNumberInput.texts.name;

    // _applyLayout: the sides after grouping.
    var plus = widget.plus;
    var minus = widget.minus;
    final bothShown = plus != KakaoStepperSide.none && minus != KakaoStepperSide.none;
    if (widget.grouped && bothShown) {
      plus = minus = widget.groupPosition == KakaoStepperSide.left ? KakaoStepperSide.left : KakaoStepperSide.right;
    }
    final grouped = widget.grouped && plus != KakaoStepperSide.none && plus == minus;
    int count(KakaoStepperSide side) => [plus, minus].where((s) => s == side).length;

    final pad = st.inputPadding;
    final padding = touch
        ? EdgeInsets.fromLTRB(
            count(KakaoStepperSide.left) * st.touchSize + _touchPadX,
            pad.top,
            count(KakaoStepperSide.right) * st.touchSize + _touchPadX,
            pad.bottom,
          )
        : pad.copyWith(right: sm ? st.smInputPaddingRight : st.inputPaddingRight);
    final radius = touch ? st.touchRadius : st.inputRadius;

    Widget input = KakaoFieldText(
      controller: _text,
      focusNode: _focus,
      style: theme.text(size: fontSize, color: st.inputColor, height: _lineHeight),
      placeholder: placeholder,
      placeholderColor: theme.colors.muted,
      cursorColor: st.inputColor,
      selectionColor: st.focusColor.withValues(alpha: _selectionAlpha),
      enabled: !disabled,
      readOnly: widget.readOnly,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [_allowed],
      onChanged: (t) => widget.onChanged?.call(KakaoNumberInput.parse(t)),
      // Enter: the input's implicit change; focus stays.
      onSubmitted: (_) {
        _commit();
        if (!_focus.hasFocus) _focus.requestFocus();
      },
      groupId: _group,
    );
    final value = KakaoNumberInput.parse(_text.text);
    final canStep = !_inert;
    input = Semantics(
      label: name,
      enabled: !disabled,
      readOnly: widget.readOnly,
      onIncrease: canStep ? () => _adjust(1) : null,
      onDecrease: canStep ? () => _adjust(-1) : null,
      // Flutter wants these only beside a value (the text).
      increasedValue: canStep && _text.text.isNotEmpty ? KakaoNumberInput.format(_peek(value, 1)) : null,
      decreasedValue: canStep && _text.text.isNotEmpty ? KakaoNumberInput.format(_peek(value, -1)) : null,
      child: ExcludeFocus(
        excluding: disabled,
        child: Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: _onKey, child: input),
      ),
    );

    // The touch layout's min-height: the text centred in it.
    final field = ConstrainedBox(
      constraints: BoxConstraints(minHeight: touch ? st.touchSize - 2 : 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: Padding(padding: padding, child: input),
      ),
    );
    final steppers = ExcludeSemantics(
      child: TapRegion(
        groupId: _group,
        child: touch ? _touchSteppers(st, theme, plus, minus, grouped) : _arrowStrip(st, theme, sm, radius),
      ),
    );

    // Touch, ungrouped: the strip runs to the field's outer edges (left /
    // right 0, not 1), so the buttons start on the border.
    final outset = touch && !grouped ? -1.0 : 0.0;
    Widget box = KakaoFieldBox(
      height: touch ? st.touchSize : 0,
      paddingX: 0,
      radius: radius,
      background: st.inputBg,
      border: _focused ? st.focusColor : st.inputBorder,
      ring: _focused && !disabled ? st.focusColor : null,
      ringWidth: st.focusWidth,
      ringOffset: st.focusOffset,
      duration: _reduceMotion ? Duration.zero : _fade,
      curve: _fadeCurve,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          field,
          if (touch)
            Positioned(left: outset, right: outset, top: 0, bottom: 0, child: steppers)
          else
            Positioned(right: 0, top: 0, bottom: 0, width: sm ? st.smArrowWidth : st.arrowWidth, child: steppers),
        ],
      ),
    );
    // Its own height, whatever height it is offered (the field box aligns
    // its content, so it would fill a bounded height).
    box = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [box]);
    if (disabled) {
      box = Opacity(
        opacity: st.disabledOpacity,
        child: IgnorePointer(child: box),
      );
    }
    return box;
  }

  double _peek(double? value, int direction) {
    final next = (value ?? 0) + direction * _step;
    final clamped = math.min(widget.max ?? double.infinity, math.max(widget.min ?? double.negativeInfinity, next));
    return double.parse(clamped.toStringAsFixed(_decimals));
  }

  /// The stacked ▲ / ▼ strip (`.kakao-number-input-arrows`).
  Widget _arrowStrip(KakaoNumberInputSettings st, KakaoThemeValues theme, bool sm, double radius) {
    final glyph = sm ? st.smArrowSize : st.arrowSize;
    Widget arrow(int direction, {required bool topLine}) => _Arrow(
      glyph: direction > 0 ? '▲' : '▼',
      style: theme.text(size: glyph, height: 1),
      color: st.arrowColor,
      hoverColor: st.arrowHoverColor,
      hoverBackground: st.arrowHoverBg,
      activeBackground: st.arrowActiveBg,
      line: topLine ? st.arrowBorder : null,
      enabled: !_inert,
      pointer: (child) => _pointer(direction: direction, child: child),
    );
    final up = widget.plus != KakaoStepperSide.none;
    final down = widget.minus != KakaoStepperSide.none;
    return MouseRegion(
      // pointerleave on the strip ends a repeat.
      onExit: (_) => _stopRepeat(),
      child: _pointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: st.arrowBorder)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 1),
            child: ClipRRect(
              borderRadius: BorderRadius.horizontal(right: Radius.circular(radius)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (up) Expanded(child: arrow(1, topLine: false)),
                  if (down) Expanded(child: arrow(-1, topLine: up)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The touch layout's − / + buttons (`[data-touch]`).
  Widget _touchSteppers(
    KakaoNumberInputSettings st,
    KakaoThemeValues theme,
    KakaoStepperSide plus,
    KakaoStepperSide minus,
    bool grouped,
  ) {
    Widget button(int direction, KakaoStepperSide side) {
      final divider = BorderSide(color: st.divider);
      return MouseRegion(
        cursor: _inert ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onExit: (_) => _stopRepeat(),
        child: _pointer(
          direction: direction,
          child: Container(
            width: st.touchSize,
            alignment: Alignment.center,
            // The divider on the inner edge, in the field's border colour.
            decoration: BoxDecoration(
              border: side == KakaoStepperSide.left ? Border(right: divider) : Border(left: divider),
            ),
            child: Text(
              direction > 0 ? '+' : '−',
              style: theme.text(size: st.touchGlyphSize, weight: _touchGlyphWeight, color: st.arrowColor, height: 1),
            ),
          ),
        ),
      );
    }

    // − before + within a side, the left side first.
    List<Widget> side(KakaoStepperSide s) {
      final items = [if (minus == s) button(-1, s), if (plus == s) button(1, s)];
      return [
        for (var i = 0; i < items.length; i++) ...[if (i > 0 && !grouped) const SizedBox(width: _touchGap), items[i]],
      ];
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...side(KakaoStepperSide.left),
        // Not a hit target: pointer-events: none on the strip.
        const Spacer(),
        ...side(KakaoStepperSide.right),
      ],
    );
  }
}

/// One stacked arrow: the glyph centred, hover and pressed fills.
class _Arrow extends StatefulWidget {
  const _Arrow({
    required this.glyph,
    required this.style,
    required this.color,
    required this.hoverColor,
    required this.hoverBackground,
    required this.activeBackground,
    required this.line,
    required this.enabled,
    required this.pointer,
  });

  final String glyph;
  final TextStyle style;
  final Color color;
  final Color hoverColor;
  final Color hoverBackground;
  final Color activeBackground;

  /// The line above (`span + span { border-top }`), or null.
  final Color? line;
  final bool enabled;
  final Widget Function(Widget child) pointer;

  @override
  State<_Arrow> createState() => _ArrowState();
}

class _ArrowState extends State<_Arrow> {
  bool _hover = false;
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final hover = _hover && widget.enabled;
    final line = widget.line;
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = _active = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _active = true),
        onPointerUp: (_) => setState(() => _active = false),
        onPointerCancel: (_) => setState(() => _active = false),
        child: widget.pointer(
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _active && widget.enabled
                  ? widget.activeBackground
                  : hover
                  ? widget.hoverBackground
                  : null,
              border: line == null ? null : Border(top: BorderSide(color: line)),
            ),
            child: Text(widget.glyph, style: widget.style.copyWith(color: hover ? widget.hoverColor : widget.color)),
          ),
        ),
      ),
    );
  }
}
