import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_field.dart';
import '../settings/kakao_code_input_settings.g.dart';
import '../theme/kakao_theme.dart';
import '../theme/kakao_tokens.g.dart';

/// `<kakao-code-input size>`.
enum KakaoCodeInputSize { sm, md, lg }

/// `<kakao-code-input type>`: which characters are taken and the keyboard.
enum KakaoCodeInputType {
  /// Digits, the numeric keyboard.
  numeric,

  /// Letters and digits (any script), the text keyboard with capitals.
  alphanumeric,
}

// code-input.js values outside the settings block.
const _minLength = 4; // MIN_LENGTH
const _maxLength = 8; // MAX_LENGTH
const _defaultLength = 6; // DEFAULT_LENGTH
final _strip = RegExp(r'[\s\-–—._/]'); // STRIP: dropped from pasted / autofilled text
const _smSize = (
  height: 36.0,
  boxWidth: 32.0,
  charSize: 16.0,
  gap: 6.0,
); // :host([size="sm"]): -sm-height, -sm-box-width, -sm-char-size 1rem, -sm-gap
const _lgSize = (
  height: 52.0,
  boxWidth: 48.0,
  charSize: 21.6,
  gap: 10.0,
); // :host([size="lg"]): -lg-height, -lg-box-width, -lg-char-size 1.35rem, -lg-gap
const _labelSize = 13.12; // .label font-size: 0.82rem
const _messageSize = 12.48; // .hint, .error font-size: 0.78rem
const _inputFont = 16.0; // input font-size: 16px (the hidden field)
const _dotSize = .5; // .box.dot::after: 0.5em
const _caretWidth = 2.0; // .box.active.empty::after width: 2px
const _caretHeight = 1.1; // .box.active.empty::after height: 1.1em
const _caretBlink = Duration(milliseconds: 530); // @keyframes blink over 1.06s, steps(1, end): half on, half off
const _sepWidth = .6; // .sep width: 0.6em (of the character size)
const _sepHeight = 2.0; // .sep height: 2px

/// Flutter twin of `<kakao-code-input>`: a one-time code or PIN, one box
/// per character ([length] 4 to 8, default 6), with the text input's label,
/// hint, error and sizes.
///
/// As code-input.js, the boxes are only drawn: ONE text field lies under
/// them, invisible but real, so SMS autofill ([autofillHints], default
/// one-time code), paste, the IME and screen readers meet a normal text
/// field with the whole value. Its selection is kept on the current box's
/// character (one character, or a caret after the last one), so typing
/// overwrites and Backspace clears; inserts are filtered and spread over
/// the boxes here.
///
/// Typing a character fills the current box and moves on; one that is not
/// allowed ([type], [pattern]) is ignored, a letter in the wrong case is
/// switched when only the other case is allowed. Backspace clears the
/// current box, on an empty box it moves back and clears that one; Delete
/// clears the current box. Left / Right / Home / End / Up / Down move
/// between the filled boxes and the first empty one; a tap lands on the box
/// under it (no further than the first empty one). A pasted or autofilled
/// text loses spaces, dashes and dots; a whole code replaces the value, a
/// shorter piece fills from the current box on. The value has no gaps.
///
/// The current box gets the focus border and the 2 px outline 2 px away;
/// an empty current box shows a blinking caret (steady with reduced
/// motion). Several characters selected (select all) tint their boxes.
/// [error] turns every border to the danger colour. [mask] shows a dot for
/// each character and makes the field a password field. [separator] puts a
/// short dash between groups of boxes: "3" after every third, "3-3" or
/// "2-3-3" the sizes in order. The row is as wide as its boxes; boxes shrink
/// alike when it does not fit.
///
/// [onChanged] is `input` (each user edit), [onCompleted] `code-complete`
/// (every box filled by a user edit), [onCommitted] `change` (the last box
/// filled, Enter, or focus leaving, when the value changed since focus came
/// or the last change); Enter also calls [onSubmitted] (the form submit).
///
/// The value is [controller]'s when given (setting its text fires no events
/// and is filtered and cut to [length]); otherwise [value] is the code the
/// field starts with, and a new [value] from the owner replaces it without
/// reporting. A focus from outside (the label, [focusNode], Tab) goes to the
/// first empty box.
class KakaoCodeInput extends StatefulWidget {
  const KakaoCodeInput({
    super.key,
    this.value = '',
    this.controller,
    this.onChanged,
    this.onCommitted,
    this.onCompleted,
    this.onSubmitted,
    this.length = _defaultLength,
    this.type = KakaoCodeInputType.numeric,
    this.pattern,
    this.mask = false,
    this.separator,
    this.label,
    this.semanticLabel,
    this.hint,
    this.error,
    this.autofillHints = const [AutofillHints.oneTimeCode],
    this.size = KakaoCodeInputSize.md,
    this.disabled = false,
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
  });

  /// `value`: the code it starts with (ignored with a [controller]).
  final String value;

  /// Holds the code instead of [value] (`value` get / set, `clear()`).
  final TextEditingController? controller;

  /// `input`: the code after each user edit.
  final ValueChanged<String>? onChanged;

  /// `change`: the code when the last box is filled, on Enter or when focus
  /// leaves, if it changed.
  final ValueChanged<String>? onCommitted;

  /// `code-complete`: every box filled after a user edit.
  final ValueChanged<String>? onCompleted;

  /// Enter (after [onCommitted]): the surrounding form's submit.
  final ValueChanged<String>? onSubmitted;

  /// `length`: the number of boxes, clamped to 4-8.
  final int length;

  /// `type`.
  final KakaoCodeInputType type;

  /// `pattern`: one character's allowed set as a regular expression, e.g.
  /// `[0-9A-F]`; overrides [type] for what is accepted ([type] still picks
  /// the keyboard). Not a valid expression: [type]'s rule.
  final String? pattern;

  /// `mask`: dots instead of the characters (PINs).
  final bool mask;

  /// `separator`: group sizes, "3" (repeats) or "3-3", "2-3-3" (in order).
  final String? separator;

  /// `label`: shown above the boxes.
  final String? label;

  /// `aria-label`: the name without a visible [label]; default
  /// [texts]`.name`.
  final String? semanticLabel;

  /// `hint`: below, hidden while there is an [error].
  final String? hint;

  /// `error`: danger borders and outline, the message below, invalid.
  final String? error;

  /// `autocomplete`: default one-time code (SMS autofill); empty for a PIN
  /// (`autocomplete="off"`).
  final Iterable<String> autofillHints;

  /// `size`.
  final KakaoCodeInputSize size;

  /// `disabled`.
  final bool disabled;

  /// `readonly`.
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;

  /// The number of boxes: [length] clamped to 4-8 (`length` getter).
  int get boxes => length.clamp(_minLength, _maxLength);

  /// `KakaoCodeInput.texts`: code-input.js's built-in English texts (the
  /// name without a label, and the count read with the field).
  static ({String name, String Function(int n) digits, String Function(int n) characters}) texts = (
    name: 'Code',
    digits: (n) => '$n digits',
    characters: (n) => '$n characters',
  );

  /// code-input.js `_clean`: [text] as it may stand in the value: spaces,
  /// dashes, dots, underscores and slashes dropped, other characters not
  /// allowed dropped (a letter in the other case taken when only that case
  /// is allowed), cut to [length] (clamped to 4-8).
  static String clean(
    String text, {
    int length = _defaultLength,
    KakaoCodeInputType type = KakaoCodeInputType.numeric,
    String? pattern,
  }) {
    final rule = _charRule(type, pattern);
    final n = length.clamp(_minLength, _maxLength);
    final out = StringBuffer();
    var count = 0;
    for (final r in text.replaceAll(_strip, '').runes) {
      final ch = String.fromCharCode(r);
      final ok = [ch, ch.toUpperCase(), ch.toLowerCase()].where(rule.hasMatch).firstOrNull;
      if (ok != null) {
        out.write(ok);
        count++;
      }
      if (count == n) break;
    }
    return out.toString();
  }

  /// code-input.js `_groups`: the group sizes [separator] gives for [n]
  /// boxes.
  static List<int> groups(int n, String? separator) {
    final raw = (separator ?? '').trim();
    if (raw.isEmpty) return [n];
    final parts = raw.split(RegExp('[^0-9]+')).map((p) => int.tryParse(p) ?? 0).where((p) => p > 0).toList();
    if (parts.isEmpty) return [n];
    final sizes = <int>[];
    var left = n;
    var i = 0;
    while (left > 0) {
      final size = parts.length == 1 ? parts[0] : (i < parts.length ? parts[i] : left);
      sizes.add(size < left ? size : left);
      left -= size;
      i++;
    }
    return sizes;
  }

  @override
  State<KakaoCodeInput> createState() => _KakaoCodeInputState();
}

/// code-input.js `_charRule`: one allowed character.
RegExp _charRule(KakaoCodeInputType type, String? pattern) {
  if (pattern != null && pattern.isNotEmpty) {
    try {
      return RegExp('^(?:$pattern)\$', unicode: true);
    } on FormatException {
      // Fall through to the type's rule.
    }
  }
  return type == KakaoCodeInputType.alphanumeric ? RegExp(r'^[\p{L}\p{N}]$', unicode: true) : RegExp(r'^[0-9]$');
}

class _KakaoCodeInputState extends State<KakaoCodeInput> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'KakaoCodeInput'));
  TextEditingController? _ownText;
  TextEditingController get _text =>
      widget.controller ?? (_ownText ??= TextEditingController(text: _clean(widget.value)));
  late KakaoChangeTracker _change = KakaoChangeTracker(_text);
  final _editable = GlobalKey<EditableTextState>();

  /// The field's tap region: a tap on the boxes keeps the editing going.
  final _group = Object();
  late final _formatter = _CodeFormatter(this);

  bool _focused = false;

  /// The current box (`_caret`).
  int _caret = 0;

  /// The box a tap asked for, taken when focus comes.
  int? _tapped;

  /// The text the formatter made from a user edit (its events are due).
  String? _userText;
  String _lastText = '';

  /// The right edges of the boxes in the row, for taps; and the gap.
  List<double> _rights = const [];
  double _gap = 0;

  int get _n => widget.boxes;
  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  String _clean(String text) =>
      KakaoCodeInput.clean(text, length: widget.length, type: widget.type, pattern: widget.pattern);

  @override
  void initState() {
    super.initState();
    _normalise();
    _focus.addListener(_focusChanged);
    _text.addListener(_textChanged);
    _lastText = _text.text;
    _change.reset();
    if (widget.autofocus && !widget.disabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(KakaoCodeInput old) {
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
      _lastText = _text.text;
    }
    // A new value from the owner (the `value` attribute) shows without
    // reporting.
    if (widget.controller == null && widget.value != old.value) {
      final next = _clean(widget.value);
      if (next != _text.text) _text.text = next;
    }
    // length, type or pattern changed: re-filter what is there.
    if (widget.length != old.length || widget.type != old.type || widget.pattern != old.pattern) _normalise();
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _text.removeListener(_textChanged);
    _ownFocus?.dispose();
    _ownText?.dispose();
    super.dispose();
  }

  /// A text that breaks the rules (set from outside) is filtered and cut.
  void _normalise() {
    final clean = _clean(_text.text);
    if (clean != _text.text) {
      _text.value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }
  }

  void _focusChanged() {
    if (!mounted) return;
    final focused = _focus.hasFocus;
    if (focused == _focused) return;
    setState(() => _focused = focused);
    if (focused) {
      _change.reset();
      // focus(): the first empty box; a tap: its box.
      _placeCaret(_tapped ?? _text.text.length);
      _tapped = null;
    } else {
      _commit();
    }
  }

  void _textChanged() {
    if (!mounted) return;
    final text = _text.text;
    if (text != _lastText) {
      final user = _userText == text;
      _userText = null;
      if (!user) {
        // `value` set from outside: filtered, no events, the base of the
        // next change.
        final clean = _clean(text);
        if (clean != text) {
          _text.value = TextEditingValue(
            text: clean,
            selection: TextSelection.collapsed(offset: clean.length),
          );
          return;
        }
        _lastText = text;
        _change.reset();
      } else {
        _lastText = text;
        widget.onChanged?.call(text);
        if (text.length == _n) {
          widget.onCompleted?.call(text);
          _commit();
        }
      }
    }
    _followSelection();
  }

  /// code-input.js `_onSelectionChange`: a bare caret snaps to a box; a
  /// selection of several characters is shown as it is.
  void _followSelection() {
    final sel = _text.selection;
    if (!_focus.hasFocus) {
      setState(() {});
    } else if (!sel.isValid) {
      _placeCaret(_text.text.length);
    } else if (sel.isCollapsed) {
      _placeCaret(sel.start);
    } else {
      setState(() {
        if (sel.end - sel.start == 1) _caret = sel.start;
      });
    }
  }

  /// code-input.js `_placeCaret`: the current box at [index] (no further
  /// than the first empty box and the last box); a filled box is selected
  /// as one character.
  void _placeCaret(int index) {
    final len = _text.text.length;
    final c = index.clamp(0, len < _n - 1 ? len : _n - 1);
    setState(() => _caret = c);
    if (_focus.hasFocus) {
      final want = TextSelection(baseOffset: c, extentOffset: c < len ? c + 1 : c);
      if (_text.selection != want) _text.selection = want;
    }
  }

  /// The input's `change`.
  void _commit() {
    if (_change.commit()) widget.onCommitted?.call(_text.text);
  }

  void _submit() {
    _commit();
    widget.onSubmitted?.call(_text.text);
  }

  /// code-input.js `_onBeforeInput` / `_insert` / `_onNativeInput`: what a
  /// user edit makes of the value. [next] is what the field would hold.
  TextEditingValue _edit(TextEditingValue old, TextEditingValue next) {
    if (old.text == next.text) return next;
    final prev = old.text;
    final n = _n;
    final sel = old.selection;
    final s = sel.isValid ? (sel.start < prev.length ? sel.start : prev.length) : prev.length;
    final e = sel.isValid ? (sel.end < prev.length ? sel.end : prev.length) : prev.length;
    final tail = prev.length - e;
    String text;
    int caret;
    final inserted =
        next.text.length >= s + tail &&
            next.text.startsWith(prev.substring(0, s)) &&
            next.text.endsWith(prev.substring(e))
        ? next.text.substring(s, next.text.length - tail)
        : null;
    if (inserted != null && inserted.isNotEmpty) {
      // An insert over the selection: typed, pasted, autofilled.
      final clean = _clean(inserted);
      if (clean.isEmpty) return old;
      if (inserted.runes.length > 1 && clean.length >= n) {
        // A whole code (as a paste) replaces the value.
        text = clean;
        caret = n;
      } else {
        // A selection wider than one box is removed first; then overwrite.
        final base = e - s > 1 ? prev.substring(0, s) + prev.substring(e) : prev;
        final start = s < base.length ? s : base.length;
        final after = start + clean.length < base.length ? base.substring(start + clean.length) : '';
        text = base.substring(0, start) + clean + after;
        if (text.length > n) text = text.substring(0, n);
        caret = start + clean.length;
      }
    } else {
      // Deletions and anything else: normalise what the field did.
      final raw = next.text;
      text = _clean(raw);
      caret = next.selection.isValid ? next.selection.start : text.length;
      if (text != raw) caret = text.length >= n ? text.length : (caret < text.length ? caret : text.length);
    }
    if (text == prev) return old;
    _userText = text;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret > text.length ? text.length : caret),
    );
  }

  /// code-input.js `_onKeydown`.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    if (keys.isAltPressed || keys.isMetaPressed || keys.isControlPressed) return KeyEventResult.ignored;
    final len = _text.text.length;
    final last = len < _n - 1 ? len : _n - 1;
    final key = event.logicalKey;
    int? to;
    if (key == LogicalKeyboardKey.arrowLeft) {
      to = _caret > 0 ? _caret - 1 : 0;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      to = _caret + 1 < last ? _caret + 1 : last;
    } else if (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.arrowUp) {
      to = 0;
    } else if (key == LogicalKeyboardKey.end || key == LogicalKeyboardKey.arrowDown) {
      to = last;
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
    _placeCaret(to);
    return KeyEventResult.handled;
  }

  /// code-input.js `_onClick`: the box under the pointer (no further than
  /// the first empty one).
  void _onTap(TapUpDetails details) {
    if (widget.disabled) return;
    final x = details.localPosition.dx;
    var index = _rights.length - 1;
    for (var i = 0; i < _rights.length; i++) {
      if (x < _rights[i] + _gap / 2) {
        index = i;
        break;
      }
    }
    if (_focus.hasFocus) {
      _placeCaret(index);
      _editable.currentState?.requestKeyboard();
    } else {
      _tapped = index;
      _focus.requestFocus();
    }
  }

  /// `focus()`: the first empty box.
  void _focusFirstEmpty() {
    if (_focus.hasFocus) {
      _placeCaret(_text.text.length);
    } else {
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoCodeInputSettings.of(theme.colors);
    final (height, boxWidth, charSize, gap) = switch (widget.size) {
      KakaoCodeInputSize.sm => (_smSize.height, _smSize.boxWidth, _smSize.charSize, _smSize.gap),
      KakaoCodeInputSize.md => (st.height, st.boxWidth, st.charSize, st.gap),
      KakaoCodeInputSize.lg => (_lgSize.height, _lgSize.boxWidth, _lgSize.charSize, _lgSize.gap),
    };
    final n = _n;
    final error = widget.error?.isNotEmpty ?? false ? widget.error : null;
    final hint = widget.hint?.isNotEmpty ?? false ? widget.hint : null;
    final label = widget.label?.isNotEmpty ?? false ? widget.label : null;
    final disabled = widget.disabled;
    final alnum = widget.type == KakaoCodeInputType.alphanumeric;
    final characters = alnum || (widget.pattern?.isNotEmpty ?? false);
    final count = characters ? KakaoCodeInput.texts.characters(n) : KakaoCodeInput.texts.digits(n);
    final name = label ?? widget.semanticLabel ?? KakaoCodeInput.texts.name;
    final value = _text.text;
    final focused = _focused && !disabled;
    final sel = _text.selection;
    final wide = focused && sel.isValid && sel.end - sel.start > 1;
    final duration = _reduceMotion ? Duration.zero : st.duration;

    // The real field: under the boxes, transparent (code-input.js `input`).
    const clear = Color(0x00000000);
    Widget input = EditableText(
      key: _editable,
      controller: _text,
      focusNode: _focus,
      readOnly: disabled || widget.readOnly,
      style: theme.text(size: _inputFont, color: clear, height: 1),
      cursorColor: clear,
      backgroundCursorColor: clear,
      selectionColor: clear,
      showCursor: false,
      obscureText: widget.mask,
      keyboardType: alnum ? TextInputType.text : TextInputType.number,
      textCapitalization: alnum ? TextCapitalization.characters : TextCapitalization.none,
      autofillHints: widget.autofillHints.isEmpty ? null : widget.autofillHints,
      autocorrect: false,
      enableSuggestions: false,
      rendererIgnoresPointer: true,
      textInputAction: TextInputAction.done,
      inputFormatters: [_formatter],
      selectAllOnFocus: false,
      groupId: _group,
      onTapOutside: (_) => _focus.unfocus(),
      // Done on a soft keyboard: Enter.
      onEditingComplete: () {},
      onSubmitted: (_) => _submit(),
    );
    input = Semantics(
      label: name,
      // aria-describedby: hint, error, count.
      hint: [?hint, ?error, count].join(' '),
      enabled: !disabled,
      readOnly: widget.readOnly,
      validationResult: error != null ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
      child: ExcludeFocus(
        excluding: disabled,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          onKeyEvent: _onKey,
          child: input,
        ),
      ),
    );

    final groups = KakaoCodeInput.groups(n, widget.separator);
    final seps = groups.length - 1;
    final sepWidth = charSize * _sepWidth;
    final sepMargin = st.groupGap - gap > 0 ? st.groupGap - gap : 0.0;
    final boxStyle = theme.text(size: charSize, weight: st.charWeight, color: st.text, height: 1, tabular: true);

    Widget box(int i, double width) {
      final ch = i < value.length ? value[i] : '';
      final active = focused && !wide && i == _caret;
      final selected = wide && i >= sel.start && i < sel.end;
      final Widget? content = ch.isEmpty
          ? (active
                ? _Caret(key: ValueKey(i), color: st.text, height: charSize * _caretHeight, blink: !_reduceMotion)
                : null)
          : widget.mask
          ? Container(
              width: charSize * _dotSize,
              height: charSize * _dotSize,
              decoration: BoxDecoration(color: st.text, shape: BoxShape.circle),
            )
          : Text(ch, style: boxStyle, maxLines: 1, overflow: TextOverflow.clip, softWrap: false);
      return SizedBox(
        width: width,
        child: KakaoFieldBox(
          height: height,
          paddingX: 0,
          radius: st.radius,
          background: selected ? st.selectedBg : st.bg,
          // :host([error]) wins over the focus border.
          border: error != null
              ? st.danger
              : active
              ? st.focus
              : st.border,
          ring: active ? (error != null ? st.danger : st.focus) : null,
          ringWidth: st.focusWidth,
          ringOffset: st.focusOffset,
          duration: duration,
          curve: st.ease,
          child: SizedBox(
            height: height - 2,
            child: Center(child: content),
          ),
        ),
      );
    }

    final row = LayoutBuilder(
      builder: (context, constraints) {
        // .row: max-content wide, at most the width it gets; boxes `flex: 0
        // 1 box-width` with min-width 0 shrink alike.
        final fixed = (n + seps - 1) * gap + seps * (sepWidth + 2 * sepMargin);
        var width = boxWidth;
        if (constraints.maxWidth.isFinite && n * width + fixed > constraints.maxWidth) {
          width = (constraints.maxWidth - fixed) / n;
          if (width < 0) width = 0;
        }
        final children = <Widget>[];
        final rights = <double>[];
        var x = 0.0;
        var i = 0;
        void add(Widget child, double w) {
          if (children.isNotEmpty) {
            children.add(SizedBox(width: gap));
            x += gap;
          }
          children.add(child);
          x += w;
        }

        for (var g = 0; g < groups.length; g++) {
          if (g > 0) {
            add(
              Container(
                width: sepWidth,
                height: _sepHeight,
                margin: EdgeInsets.symmetric(horizontal: sepMargin),
                decoration: BoxDecoration(
                  color: st.muted,
                  borderRadius: BorderRadius.circular(KakaoSharedTokens.radiusXs),
                ),
              ),
              sepWidth + 2 * sepMargin,
            );
          }
          for (var k = 0; k < groups[g]; k++, i++) {
            add(box(i, width), width);
            rights.add(x);
          }
        }
        _rights = rights;
        _gap = gap;
        return Stack(
          children: [
            Positioned.fill(child: input),
            ExcludeSemantics(
              child: Row(mainAxisSize: MainAxisSize.min, children: children),
            ),
            Positioned.fill(
              child: MouseRegion(
                cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.text,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTapUp: disabled ? null : _onTap,
                ),
              ),
            ),
          ],
        );
      },
    );

    return KakaoField(
      label: label,
      message: error ?? hint,
      messageColor: error != null ? st.danger : st.muted,
      labelStyle: theme.text(size: _labelSize, weight: st.labelWeight, color: st.text, height: st.font.lineHeight),
      messageStyle: theme.text(size: _messageSize, height: st.font.lineHeight),
      labelGap: st.labelGap,
      messageGap: st.messageGap,
      disabledOpacity: disabled ? st.disabledOpacity : null,
      // <label for>: focus(), the first empty box.
      onLabelTap: disabled ? null : _focusFirstEmpty,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TapRegion(groupId: _group, child: row),
      ),
    );
  }
}

/// Every user edit goes through [_KakaoCodeInputState._edit].
class _CodeFormatter extends TextInputFormatter {
  _CodeFormatter(this._state);

  final _KakaoCodeInputState _state;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      _state._edit(oldValue, newValue);
}

/// `.box.active.empty::after`: a 2 px caret, 1.1em high, blinking (1.06 s,
/// half on and half off) unless [blink] is false; it starts on.
class _Caret extends StatefulWidget {
  const _Caret({super.key, required this.color, required this.height, required this.blink});

  final Color color;
  final double height;
  final bool blink;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> {
  Timer? _timer;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Caret old) {
    super.didUpdateWidget(old);
    if (old.blink != widget.blink) _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    _on = true;
    if (widget.blink) _timer = Timer.periodic(_caretBlink, (_) => setState(() => _on = !_on));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: _on ? 1 : 0,
    child: Container(
      width: _caretWidth,
      height: widget.height,
      decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(KakaoSharedTokens.radiusXs)),
    ),
  );
}
