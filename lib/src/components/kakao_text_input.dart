import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_field.dart';
import '../settings/kakao_text_input_settings.g.dart';
import '../theme/kakao_theme.dart';

/// `<kakao-text-input size>`.
enum KakaoTextInputSize { sm, md, lg }

/// `<kakao-text-input type>`: the keyboard, autofill and whether the text
/// shows as dots.
enum KakaoTextInputType {
  text(TextInputType.text),
  email(TextInputType.emailAddress),
  password(TextInputType.visiblePassword),
  search(TextInputType.text),
  url(TextInputType.url),
  tel(TextInputType.phone),
  number(TextInputType.numberWithOptions(decimal: true, signed: true));

  const KakaoTextInputType(this.keyboard);

  final TextInputType keyboard;
}

/// `text-input-clear`: the clear button emptied the field.
@immutable
class KakaoTextInputClear {
  const KakaoTextInputClear._(this.previous);

  /// The value now: always "".
  String get value => '';

  /// The value before.
  final String previous;
}

// text-input.js values outside the settings block.
const _smSize = (
  height: 36.0,
  paddingX: 10.0,
  font: 14.0,
); // --kakao-text-input-sm-height / -sm-padding-x; input 0.875rem
const _lgSize = (height: 52.0, paddingX: 14.0, font: 16.0); // --kakao-text-input-lg-height / -lg-padding-x; input 1rem
const _partGap = .6; // .field gap: calc(var(--_padding-x) * 0.6)
const _iconBox = 1.2; // .icon width: 1.2em (of icon-size)
const _labelSize = 13.12; // .label font-size: 0.82rem
const _messageSize = 12.48; // .hint, .error font-size: 0.78rem
const _clearFont = 12.48; // .clear font-size: 0.78rem, line-height 1
const _fade = Duration(milliseconds: 150); // .field transition: border-color 150ms ease, background-color 150ms ease
const _fadeCurve = Curves.ease; // CSS `ease`
const _selectionAlpha = .25; // the text selection: the focus colour, light

/// Flutter twin of `<kakao-text-input>`: a one-line text field with a
/// label, an optional leading icon and clear button, hint and error text,
/// in three sizes.
///
/// As text-input.js draws it from the `--kakao-text-input-*` settings:
/// [label] above (a tap on it focuses the field), [hint] below, or [error]
/// instead (danger border and outline, invalid in semantics); the
/// [placeholder] in the muted colour while empty. The box is 36 / 44 / 52 px
/// high ([size]); its border fades (150 ms) to the focus colour while the
/// field has focus, which also draws the 2 px outline 2 px away (an input
/// matches `:focus-visible` whenever it is focused). [disabled] dims
/// everything to `disabled-opacity` and takes the field out of the focus
/// order; [readOnly] keeps it focusable and selectable. The field fills the
/// width it gets.
///
/// [icon] sits in front of the text in the muted colour, `icon-size` big in
/// a box 1.2 times as wide (an [Icon] or anything that reads [IconTheme]);
/// no icon, no space. [clearable] shows a round ✕ button (`clear-size`, on
/// the hover fill) while the field has a value: a tap empties the field,
/// puts focus in it and reports [onChanged], [onCommitted] and [onCleared].
/// Like the web's `tabindex="-1"` button it is not in the focus order.
///
/// [onChanged] is the `input` event (every edit); [onCommitted] the
/// `change` event: when focus leaves, or on Enter, if the text differs from
/// the text when focus came (or the last change).
///
/// The text is [controller]'s when given; otherwise [value] is the text the
/// field starts with, and a new [value] from the owner replaces the text,
/// without reporting it.
class KakaoTextInput extends StatefulWidget {
  const KakaoTextInput({
    super.key,
    this.value = '',
    this.controller,
    this.onChanged,
    this.onCommitted,
    this.onCleared,
    this.label,
    this.semanticLabel,
    this.hint,
    this.error,
    this.placeholder,
    this.type = KakaoTextInputType.text,
    this.icon,
    this.clearable = false,
    this.maxLength,
    this.autofillHints,
    this.inputFormatters,
    this.size = KakaoTextInputSize.md,
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

  /// `change`: the text when focus leaves or Enter is pressed, if it changed.
  final ValueChanged<String>? onCommitted;

  /// `text-input-clear`.
  final ValueChanged<KakaoTextInputClear>? onCleared;

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

  /// `type`: [KakaoTextInputType.password] shows dots; the others pick the
  /// keyboard.
  final KakaoTextInputType type;

  /// The `icon` slot.
  final Widget? icon;

  /// `clearable`.
  final bool clearable;

  /// `maxlength`: limits typing.
  final int? maxLength;

  /// `autocomplete`.
  final Iterable<String>? autofillHints;

  /// More input formatters, after [maxLength]'s (the `pattern` and
  /// `inputmode` of a form library).
  final List<TextInputFormatter>? inputFormatters;

  /// `size`.
  final KakaoTextInputSize size;

  /// `disabled`.
  final bool disabled;

  /// `readonly`.
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;

  /// `KakaoTextInput.texts`: text-input.js's built-in English texts.
  static ({String name, String clear}) texts = (name: 'Text', clear: 'Clear');

  @override
  State<KakaoTextInput> createState() => _KakaoTextInputState();
}

class _KakaoTextInputState extends State<KakaoTextInput> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'KakaoTextInput'));
  TextEditingController? _ownText;
  TextEditingController get _text => widget.controller ?? (_ownText ??= TextEditingController(text: widget.value));
  late KakaoChangeTracker _change = KakaoChangeTracker(_text);

  /// The clear button's tap region: a tap on it keeps the editing going.
  final _group = Object();
  bool _focused = false;
  bool _hasValue = false;

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
    _text.addListener(_textChanged);
    _hasValue = _text.text.isNotEmpty;
    if (widget.autofocus && !widget.disabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(KakaoTextInput old) {
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
      _hasValue = _text.text.isNotEmpty;
    }
    // A new value from the owner (the `value` attribute) shows without
    // reporting.
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
    } else {
      _commit();
    }
  }

  void _textChanged() {
    final has = _text.text.isNotEmpty;
    if (has != _hasValue && mounted) setState(() => _hasValue = has);
  }

  /// The input's `change`.
  void _commit() {
    if (_change.commit()) widget.onCommitted?.call(_text.text);
  }

  /// text-input.js `_clear`: empty, focus, then `input`, `change` and
  /// `text-input-clear`.
  void _clear() {
    final previous = _text.text;
    if (previous.isEmpty) return;
    _text.value = TextEditingValue.empty;
    _change.reset();
    _focus.requestFocus();
    widget.onChanged?.call('');
    widget.onCommitted?.call('');
    widget.onCleared?.call(KakaoTextInputClear._(previous));
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoTextInputSettings.of(theme.colors);
    final (height, paddingX, fontSize) = switch (widget.size) {
      KakaoTextInputSize.sm => (_smSize.height, _smSize.paddingX, _smSize.font),
      KakaoTextInputSize.md => (st.height, st.paddingX, st.font.size),
      KakaoTextInputSize.lg => (_lgSize.height, _lgSize.paddingX, _lgSize.font),
    };
    final error = widget.error?.isNotEmpty ?? false ? widget.error : null;
    final hint = widget.hint?.isNotEmpty ?? false ? widget.hint : null;
    final placeholder = widget.placeholder?.isNotEmpty ?? false ? widget.placeholder : null;
    final name = widget.label ?? widget.semanticLabel ?? placeholder ?? KakaoTextInput.texts.name;
    final disabled = widget.disabled;
    final gap = paddingX * _partGap;

    Widget input = KakaoFieldText(
      controller: _text,
      focusNode: _focus,
      style: theme.text(size: fontSize, color: st.text, height: st.font.lineHeight),
      placeholder: placeholder,
      placeholderColor: st.muted,
      cursorColor: st.text,
      selectionColor: st.focus.withValues(alpha: _selectionAlpha),
      enabled: !disabled,
      readOnly: widget.readOnly,
      keyboardType: widget.type.keyboard,
      obscureText: widget.type == KakaoTextInputType.password,
      autofillHints: widget.autofillHints,
      textInputAction: widget.type == KakaoTextInputType.search ? TextInputAction.search : null,
      inputFormatters: [
        if (widget.maxLength case final max?) LengthLimitingTextInputFormatter(max),
        ...?widget.inputFormatters,
      ],
      onChanged: widget.onChanged,
      // Enter: the input's implicit change; focus stays.
      onSubmitted: (_) {
        _commit();
        if (!_focus.hasFocus) _focus.requestFocus();
      },
      groupId: _group,
    );
    input = Semantics(
      label: name,
      hint: error ?? hint,
      enabled: !disabled,
      readOnly: widget.readOnly,
      validationResult: error != null ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
      child: ExcludeFocus(excluding: disabled, child: input),
    );

    final icon = widget.icon;
    final row = Row(
      children: [
        if (icon != null) ...[
          // .icon: aria-hidden, the muted colour, icon-size.
          ExcludeSemantics(
            child: SizedBox(
              width: st.iconSize * _iconBox,
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(color: st.muted, size: st.iconSize),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: st.muted, fontSize: st.iconSize),
                    child: icon,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: gap),
        ],
        // input height: calc(var(--_height) - 2px).
        Expanded(
          child: SizedBox(
            height: height - 2,
            child: Align(alignment: AlignmentDirectional.centerStart, child: input),
          ),
        ),
        if (widget.clearable && _hasValue) ...[
          SizedBox(width: gap),
          KakaoFieldButton(
            size: st.clearSize,
            background: st.hoverBg,
            color: st.muted,
            hoverColor: st.text,
            semanticLabel: KakaoTextInput.texts.clear,
            groupId: _group,
            // The web button stays live on a disabled or read-only field;
            // here it only shows there.
            onTap: disabled || widget.readOnly ? null : _clear,
            child: Text('✕', style: theme.text(size: _clearFont, height: 1)),
          ),
        ],
      ],
    );

    final box = KakaoFieldBox(
      height: height,
      paddingX: paddingX,
      radius: st.radius,
      background: st.bg,
      // :host([error]) wins over focus.
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
      child: row,
    );

    return KakaoField(
      label: widget.label,
      message: error ?? hint,
      messageColor: error != null ? st.danger : st.muted,
      labelStyle: theme.text(size: _labelSize, weight: st.labelWeight, color: st.text, height: st.font.lineHeight),
      messageStyle: theme.text(size: _messageSize, height: st.font.lineHeight),
      labelGap: st.labelGap,
      messageGap: st.messageGap,
      disabledOpacity: disabled ? st.disabledOpacity : null,
      // <label for>: focuses the input.
      onLabelTap: disabled ? null : _focus.requestFocus,
      child: box,
    );
  }
}
