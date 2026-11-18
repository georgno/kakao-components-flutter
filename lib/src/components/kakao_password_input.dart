import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_field.dart';
import '../settings/kakao_password_input_settings.g.dart';
import '../theme/kakao_theme.dart';
import 'kakao_progress.dart';

/// `<kakao-password-input size>`.
enum KakaoPasswordInputSize { sm, md, lg }

/// One password requirement: a [label] and a [test] of the value
/// (password-input.js `{ label, test(value) }` or `{ label, pattern, flags }`).
@immutable
class KakaoPasswordRequirement {
  /// `{ label, test(value) → boolean }`.
  const KakaoPasswordRequirement({required this.label, required bool Function(String value) this.test});

  /// `{ label, pattern, flags }`: [pattern] is a regular expression source
  /// tested against the value (not anchored); [flags] as in JavaScript,
  /// default "u" so `\p{…}` classes work ("g" and "y" are dropped). An
  /// invalid pattern makes a requirement the field leaves out, with a debug
  /// warning.
  factory KakaoPasswordRequirement.pattern(String label, String pattern, {String flags = 'u'}) {
    try {
      final re = RegExp(
        pattern,
        caseSensitive: !flags.contains('i'),
        multiLine: flags.contains('m'),
        dotAll: flags.contains('s'),
        unicode: flags.contains('u') || flags.contains('v'),
      );
      return KakaoPasswordRequirement(label: label, test: re.hasMatch);
    } on FormatException catch (e) {
      debugPrint('KakaoPasswordInput: requirement "$label" has an invalid pattern: ${e.message}');
      return KakaoPasswordRequirement._invalid(label);
    }
  }

  const KakaoPasswordRequirement._invalid(this.label) : test = null;

  final String label;

  /// Null: an invalid pattern, left out.
  final bool Function(String value)? test;

  /// password-input.js `defaultRequirements`: at least [minLength]
  /// characters, a lowercase letter, an uppercase letter, a number, a symbol.
  static List<KakaoPasswordRequirement> defaults({int minLength = 8}) => [
    KakaoPasswordRequirement.pattern('At least $minLength characters', '.{$minLength,}'),
    KakaoPasswordRequirement.pattern('A lowercase letter', r'\p{Ll}'),
    KakaoPasswordRequirement.pattern('An uppercase letter', r'\p{Lu}'),
    KakaoPasswordRequirement.pattern('A number', r'\p{Nd}'),
    KakaoPasswordRequirement.pattern('A symbol', r'[^\p{L}\p{N}\s]'),
  ];
}

/// `password-input-requirements`, and the strength check of
/// `required-strength` (the owner keeps the form: [strengthMessage] is the
/// validation message password-input.js sets).
@immutable
class KakaoPasswordRequirements {
  const KakaoPasswordRequirements._(this.requirements, this.needed, this.empty);

  /// The requirements in use, with whether the value meets each.
  final List<({String label, bool met})> requirements;

  /// How many must be met (`required-strength`); 0: none.
  final int needed;

  /// The value was empty (only a non-empty value is checked).
  final bool empty;

  int get met => requirements.where((r) => r.met).length;
  int get total => requirements.length;

  /// The `patternMismatch` message while fewer than [needed] are met, else
  /// null.
  String? get strengthMessage {
    if (needed == 0 || empty || met >= needed) return null;
    final missing = [
      for (final r in requirements)
        if (!r.met) r.label,
    ];
    return needed == total
        ? 'Your password still needs: ${missing.join(', ')}.'
        : 'Meet at least $needed of the $total password requirements ($met so far).';
  }
}

// password-input.js values outside the settings block.
const _smSize = (
  height: 36.0,
  paddingX: 10.0,
  toggle: 26.0,
  font: 14.0,
); // --kakao-password-input-sm-height / -sm-padding-x / -sm-toggle-size; input 0.875rem
const _lgSize = (
  height: 52.0,
  paddingX: 14.0,
  font: 16.0,
); // --kakao-password-input-lg-height / -lg-padding-x; input 1rem
const _partGap = .5; // .field gap: calc(var(--_padding-x) * 0.5)
const _labelSize = 13.12; // .label font-size: 0.82rem
const _messageSize = 12.48; // .caps, .hint, .error, .reqs font-size: 0.78rem
const _messagesGap = 12.0; // .messages gap: 0 0.75rem
const _messageBasis = 144.0; // .hint, .error flex: 1 1 9rem
const _capsWeight = 500.0; // .caps font-weight
const _capsIcon = 1.2; // .caps svg 1.2em, margin-block -0.1em
const _capsGap = .35; // .caps gap: 0.35em
const _listColumnGap = 16.0; // .reqs gap: var(--_list-gap) 1rem
const _reqIcon = 1.25; // .reqs svg 1.25em, margin-top 0.05em
const _reqIconTop = .05;
const _reqGap = .4; // .reqs li gap: 0.4em
const _openOpacity = .7; // .reqs .off opacity
const _announceDelay = Duration(milliseconds: 1000); // ANNOUNCE_DELAY
const _selectionAlpha = .25; // the text selection: the focus colour, light

/// Flutter twin of `<kakao-password-input>`: a password field with a show /
/// hide button, a Caps Lock warning and, opt-in, a list of requirements
/// with a segmented strength bar.
///
/// The text input's look, from the `--kakao-password-input-*` settings:
/// [label] above (a tap on it focuses the field), [hint] below, or [error]
/// instead (danger border and outline, invalid in semantics), the
/// [placeholder], sizes 36 / 44 / 52 px ([size]); the border fades
/// (`duration`, `ease`) to the focus colour while the field has focus, with
/// the 2 px outline 2 px away. [disabled] dims everything; [readOnly] keeps
/// it focusable and the toggle working.
///
/// The toggle at the end of the field (`toggle-size`, `toggle-radius`, the
/// hover fill and the text colour under the pointer) shows the password as
/// text and back; it is a real button named "Show password" that reports
/// pressed while the password shows, in the focus order with its own
/// outline. A tap on it keeps focus and the caret in the field. [hideToggle]
/// leaves it out (and hides the password). [visible] sets the state from
/// the owner; [onToggled] reports the button (`password-input-toggle`).
///
/// While the field has focus and Caps Lock is on (read on keys and pointer
/// downs in the field, as the web reads `getModifierState`), "Caps Lock is
/// on" shows at the end of the hint's line (under the hint when the hint
/// would get less than 9rem), and is announced once.
///
/// [requirements] (or [requiredStrength]) shows a [KakaoProgress] with one
/// segment per requirement (each one met fills one, the bar turns to the
/// success tone when all are) and the list in columns of at least
/// `list-min-column`: a check in the success colour or an open circle, in
/// words for assistive technology. [requirementList] replaces
/// [KakaoPasswordRequirement.defaults] (whose length follows [minLength]).
/// Changes are announced once typing pauses for a second, while the field
/// has focus. [onRequirementsChanged] reports a new set of met requirements;
/// [requiredStrength] makes its [KakaoPasswordRequirements.strengthMessage]
/// a message (0: all of them, N: at least N): the owner shows it as
/// [error] or blocks its form.
///
/// [onChanged] is `input`, [onCommitted] `change` (on blur or Enter when the
/// text changed), [onSubmitted] Enter (the web submits the field's form).
/// The text is [controller]'s when given; otherwise [value] is the text it
/// starts with, and a new [value] replaces it without reporting.
class KakaoPasswordInput extends StatefulWidget {
  const KakaoPasswordInput({
    super.key,
    this.value = '',
    this.controller,
    this.onChanged,
    this.onCommitted,
    this.onSubmitted,
    this.onToggled,
    this.onRequirementsChanged,
    this.label,
    this.semanticLabel,
    this.hint,
    this.error,
    this.placeholder,
    this.minLength,
    this.maxLength,
    this.autofillHints,
    this.size = KakaoPasswordInputSize.md,
    this.requirements = false,
    this.requirementList,
    this.requiredStrength,
    this.hideToggle = false,
    this.visible,
    this.disabled = false,
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
  });

  /// `value`: the text it starts with (ignored with a [controller]).
  final String value;

  /// Holds the text instead of [value].
  final TextEditingController? controller;

  /// `input`: the text after each edit.
  final ValueChanged<String>? onChanged;

  /// `change`: the text when focus leaves or Enter is pressed, if it changed.
  final ValueChanged<String>? onCommitted;

  /// Enter in the field (the web's `requestSubmit` of its form).
  final ValueChanged<String>? onSubmitted;

  /// `password-input-toggle`: the button was used; whether the password
  /// shows now.
  final ValueChanged<bool>? onToggled;

  /// `password-input-requirements`: the set of met requirements changed (on
  /// edits and when the requirements change).
  final ValueChanged<KakaoPasswordRequirements>? onRequirementsChanged;

  /// `label`: shown above the field.
  final String? label;

  /// `aria-label`: the name without a visible [label]; default
  /// [texts]`.name`.
  final String? semanticLabel;

  /// `hint`: below the field, hidden while there is an [error].
  final String? hint;

  /// `error`: the danger border and outline, the message below.
  final String? error;

  /// `placeholder`.
  final String? placeholder;

  /// `minlength`: the length of the default length requirement (8 without).
  final int? minLength;

  /// `maxlength`: limits typing.
  final int? maxLength;

  /// `autocomplete`; default new password with requirements, else password.
  final Iterable<String>? autofillHints;

  /// `size`.
  final KakaoPasswordInputSize size;

  /// `requirements`: shows the strength bar and the list.
  final bool requirements;

  /// `list-data` / the `requirements` property; null: the defaults.
  final List<KakaoPasswordRequirement>? requirementList;

  /// `required-strength`: null off; [allRequirements] (0) every one; N at
  /// least N. Implies [requirements].
  final int? requiredStrength;

  /// `required-strength` without a number.
  static const allRequirements = 0;

  /// `hide-toggle`.
  final bool hideToggle;

  /// `visible`: a new value from the owner shows or hides the password.
  final bool? visible;

  /// `disabled`.
  final bool disabled;

  /// `readonly`.
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;

  /// `KakaoPasswordInput.texts`: password-input.js's built-in English texts.
  static ({String name, String show, String caps, String requirements, String met, String notMet}) texts = (
    name: 'Password',
    show: 'Show password',
    caps: 'Caps Lock is on',
    requirements: 'Password requirements',
    met: 'met',
    notMet: 'not met',
  );

  /// The requirements of [requirementList] (else the defaults with
  /// [minLength]) tested against [value], with the [requiredStrength] check.
  static KakaoPasswordRequirements evaluate(
    String value, {
    List<KakaoPasswordRequirement>? requirementList,
    int? minLength,
    int? requiredStrength,
  }) {
    final reqs = _usable(requirementList, minLength);
    return _evaluate(value, reqs, requiredStrength);
  }

  @override
  State<KakaoPasswordInput> createState() => _KakaoPasswordInputState();
}

/// password-input.js `_readRequirements`: blank labels and invalid patterns
/// left out, labels trimmed.
List<KakaoPasswordRequirement> _usable(List<KakaoPasswordRequirement>? list, int? minLength) {
  final source =
      list ?? KakaoPasswordRequirement.defaults(minLength: minLength != null && minLength > 0 ? minLength : 8);
  return [
    for (final r in source)
      if (r.test != null && r.label.trim().isNotEmpty) KakaoPasswordRequirement(label: r.label.trim(), test: r.test!),
  ];
}

KakaoPasswordRequirements _evaluate(String value, List<KakaoPasswordRequirement> reqs, int? requiredStrength) {
  bool meets(KakaoPasswordRequirement r) {
    if (value.isEmpty) return false;
    try {
      return r.test!(value);
    } catch (_) {
      return false;
    }
  }

  final total = reqs.length;
  final needed = requiredStrength == null
      ? 0
      : requiredStrength > 0
      ? (requiredStrength < total ? requiredStrength : total)
      : total;
  return KakaoPasswordRequirements._([for (final r in reqs) (label: r.label, met: meets(r))], needed, value.isEmpty);
}

class _KakaoPasswordInputState extends State<KakaoPasswordInput> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'KakaoPasswordInput'));
  TextEditingController? _ownText;
  TextEditingController get _text => widget.controller ?? (_ownText ??= TextEditingController(text: widget.value));
  late KakaoChangeTracker _change = KakaoChangeTracker(_text);
  final _toggleFocus = FocusNode(debugLabel: 'KakaoPasswordInput toggle');

  /// The field and its toggle: a tap on the toggle keeps the editing going.
  final _group = Object();
  bool _focused = false;
  bool _visible = false;
  bool _caps = false;

  List<KakaoPasswordRequirement> _reqs = const [];
  late KakaoPasswordRequirements _result;

  /// The met state last announced (null: not focused yet).
  List<bool>? _announced;
  Timer? _announceTimer;
  String _status = '';

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  bool get _shows => widget.requirements || widget.requiredStrength != null;
  List<bool> get _met => [for (final r in _result.requirements) r.met];

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
    _text.addListener(_textChanged);
    _visible = (widget.visible ?? false) && !widget.hideToggle;
    _reqs = _usable(widget.requirementList, widget.minLength);
    _result = _evaluate(_text.text, _reqs, widget.requiredStrength);
    if (widget.autofocus && !widget.disabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(KakaoPasswordInput old) {
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
    // A new value from the owner (the `value` property) shows without
    // reporting input or change.
    if (widget.controller == null && widget.value != old.value && widget.value != _text.text) {
      _text.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
    if (widget.visible != old.visible && widget.visible != null) _visible = widget.visible!;
    if (widget.hideToggle) _visible = false;
    if (widget.requirementList != old.requirementList ||
        widget.minLength != old.minLength ||
        widget.requiredStrength != old.requiredStrength) {
      _reqs = _usable(widget.requirementList, widget.minLength);
      _reevaluate(typing: false);
      if (_announced != null && _announced!.length != _reqs.length) _announced = _met;
    }
  }

  @override
  void dispose() {
    _announceTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    _focus.removeListener(_focusChanged);
    _text.removeListener(_textChanged);
    _ownFocus?.dispose();
    _ownText?.dispose();
    _toggleFocus.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (!mounted) return;
    final focused = _focus.hasFocus;
    if (focused == _focused) return;
    setState(() => _focused = focused);
    if (focused) {
      _change.reset();
      _announced = _met;
      HardwareKeyboard.instance.addHandler(_onKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_onKey);
      _setCaps(false);
      _flushAnnounce(speak: false);
      _commit();
    }
  }

  /// The input's keydown / keyup: read Caps Lock.
  bool _onKey(KeyEvent event) {
    _readCaps();
    return false;
  }

  void _readCaps() => _setCaps(HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock));

  void _setCaps(bool on) {
    final show = on && _focus.hasFocus;
    if (show == _caps || !mounted) return;
    setState(() {
      _caps = show;
      if (show) _status = '${KakaoPasswordInput.texts.caps}.';
    });
  }

  String _lastText = '';

  void _textChanged() {
    // Selection moves call listeners too; only the text matters here.
    if (_text.text == _lastText) return;
    _lastText = _text.text;
    _reevaluate(typing: _focus.hasFocus);
  }

  void _reevaluate({required bool typing}) {
    final before = _met;
    final next = _evaluate(_text.text, _reqs, widget.requiredStrength);
    final after = [for (final r in next.requirements) r.met];
    final changed = !listEquals(before, after);
    if (mounted) {
      setState(() => _result = next);
    } else {
      _result = next;
    }
    if (changed) widget.onRequirementsChanged?.call(next);
    if (typing && _shows) {
      _announceTimer?.cancel();
      _announceTimer = Timer(_announceDelay, () => _flushAnnounce(speak: true));
    }
  }

  /// password-input.js `_flushAnnounce`: what changed since the last
  /// announcement, only while the field has focus.
  void _flushAnnounce({required bool speak}) {
    _announceTimer?.cancel();
    _announceTimer = null;
    final prev = _announced;
    final now = _met;
    _announced = now;
    if (!speak || prev == null || prev.length != now.length || !_focus.hasFocus || !mounted) return;
    final gained = <String>[];
    final lost = <String>[];
    for (var i = 0; i < now.length; i++) {
      if (now[i] && !prev[i]) gained.add(_reqs[i].label);
      if (!now[i] && prev[i]) lost.add(_reqs[i].label);
    }
    if (gained.isEmpty && lost.isEmpty) return;
    final total = now.length;
    final met = _result.met;
    setState(() {
      _status = [
        if (gained.isNotEmpty) 'Met: ${gained.join(', ')}.',
        if (lost.isNotEmpty) 'No longer met: ${lost.join(', ')}.',
        met == total ? 'All $total requirements met.' : '$met of $total requirements met.',
      ].join(' ');
    });
  }

  /// The input's `change`.
  void _commit() {
    if (_change.commit()) widget.onCommitted?.call(_text.text);
  }

  void _toggle() {
    // Pointer: focus and the caret stay in the field (the web prevents the
    // button's pointerdown); from elsewhere the button takes focus, as a
    // clicked button does.
    if (!_focus.hasFocus && !_toggleFocus.hasFocus) _toggleFocus.requestFocus();
    setState(() => _visible = !_visible);
    widget.onToggled?.call(_visible);
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoPasswordInputSettings.of(theme.colors);
    final (height, paddingX, toggleSize, fontSize) = switch (widget.size) {
      KakaoPasswordInputSize.sm => (_smSize.height, _smSize.paddingX, _smSize.toggle, _smSize.font),
      KakaoPasswordInputSize.md => (st.height, st.paddingX, st.toggleSize, st.font.size),
      KakaoPasswordInputSize.lg => (_lgSize.height, _lgSize.paddingX, st.toggleSize, _lgSize.font),
    };
    final error = widget.error?.isNotEmpty ?? false ? widget.error : null;
    final hint = widget.hint?.isNotEmpty ?? false ? widget.hint : null;
    final placeholder = widget.placeholder?.isNotEmpty ?? false ? widget.placeholder : null;
    final label = widget.label?.isNotEmpty ?? false ? widget.label : null;
    final name = label ?? widget.semanticLabel ?? KakaoPasswordInput.texts.name;
    final disabled = widget.disabled;
    final duration = _reduceMotion ? Duration.zero : st.duration;
    final showToggle = !widget.hideToggle;
    final showStrength = _shows && _reqs.isNotEmpty;
    final lineHeight = st.font.lineHeight;

    Widget input = KakaoFieldText(
      controller: _text,
      focusNode: _focus,
      style: theme.text(size: fontSize, color: st.text, height: lineHeight),
      placeholder: placeholder,
      placeholderColor: st.muted,
      cursorColor: st.text,
      selectionColor: st.focus.withValues(alpha: _selectionAlpha),
      enabled: !disabled,
      readOnly: widget.readOnly,
      keyboardType: TextInputType.visiblePassword,
      obscureText: !_visible,
      autofillHints:
          widget.autofillHints ?? (_shows ? const [AutofillHints.newPassword] : const [AutofillHints.password]),
      inputFormatters: [if (widget.maxLength case final max?) LengthLimitingTextInputFormatter(max)],
      onChanged: widget.onChanged,
      onSubmitted: (v) {
        _commit();
        if (!_focus.hasFocus) _focus.requestFocus();
        widget.onSubmitted?.call(v);
      },
      groupId: _group,
    );
    input = Semantics(
      label: name,
      hint: error ?? hint,
      enabled: !disabled,
      readOnly: widget.readOnly,
      obscured: !_visible,
      validationResult: error != null ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
      child: ExcludeFocus(
        excluding: disabled,
        // pointerdown in the field reads Caps Lock too.
        child: Listener(onPointerDown: (_) => _readCaps(), child: input),
      ),
    );

    // .toggle margin-inline-end: -(padding-x - (height - toggle-size) / 2):
    // as far from the end as from the top.
    final endPadding = showToggle ? (height - toggleSize) / 2 : paddingX;
    final row = Padding(
      padding: EdgeInsetsDirectional.only(start: paddingX, end: endPadding),
      child: Row(
        children: [
          // input height: calc(var(--_height) - 2px).
          Expanded(
            child: SizedBox(
              height: height - 2,
              child: Align(alignment: AlignmentDirectional.centerStart, child: input),
            ),
          ),
          if (showToggle) ...[
            SizedBox(width: paddingX * _partGap),
            _Toggle(
              size: toggleSize,
              iconSize: st.iconSize,
              radius: st.toggleRadius,
              hoverBackground: st.toggleHoverBg,
              color: st.muted,
              hoverColor: st.text,
              ring: st.focus,
              ringWidth: st.focusWidth,
              ringOffset: st.focusOffset,
              duration: duration,
              curve: st.ease,
              pressed: _visible,
              label: KakaoPasswordInput.texts.show,
              focusNode: _toggleFocus,
              groupId: _group,
              onTap: disabled ? null : _toggle,
            ),
          ],
        ],
      ),
    );

    final box = KakaoFieldBox(
      height: height,
      paddingX: 0,
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
      duration: duration,
      curve: st.ease,
      child: row,
    );

    final messageStyle = theme.text(size: _messageSize, height: lineHeight);
    Widget? caps;
    if (_caps) {
      final em = _messageSize;
      caps = ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // One line box high: the icon never makes the line taller.
            SizedBox(
              width: em * _capsIcon,
              height: em,
              child: OverflowBox(
                maxHeight: em * _capsIcon,
                child: CustomPaint(size: Size.square(em * _capsIcon), painter: _GlyphPainter(_Glyph.caps, st.warning)),
              ),
            ),
            SizedBox(width: em * _capsGap),
            Text(
              KakaoPasswordInput.texts.caps,
              maxLines: 1,
              softWrap: false,
              style: theme.text(size: _messageSize, weight: _capsWeight, color: st.text, height: lineHeight),
            ),
          ],
        ),
      );
    }

    Widget field = KakaoField(
      label: label,
      message: error ?? hint,
      messageColor: error != null ? st.danger : st.muted,
      labelStyle: theme.text(size: _labelSize, weight: st.labelWeight, color: st.text, height: lineHeight),
      messageStyle: messageStyle,
      labelGap: st.labelGap,
      messageGap: st.messageGap,
      disabledOpacity: null,
      onLabelTap: disabled ? null : _focus.requestFocus,
      counter: caps,
      counterGap: _messagesGap,
      messageMinWidth: _messageBasis,
      child: box,
    );

    final total = _reqs.length;
    final met = _result.met;
    field = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        if (showStrength) ...[
          SizedBox(height: st.strengthGap),
          // aria-hidden: the list says it all.
          ExcludeSemantics(
            child: KakaoProgress(
              size: KakaoProgressSize.sm,
              value: met.toDouble(),
              max: total.toDouble(),
              segments: total,
              tone: met == total ? KakaoProgressTone.success : KakaoProgressTone.primary,
            ),
          ),
          SizedBox(height: st.listOffset),
          Semantics(
            container: true,
            label: KakaoPasswordInput.texts.requirements,
            child: _RequirementList(
              requirements: _result.requirements,
              minColumn: st.listMinColumn,
              rowGap: st.listGap,
              style: messageStyle,
              muted: st.muted,
              text: st.text,
              success: st.success,
              duration: duration,
              curve: st.ease,
            ),
          ),
        ],
        // The polite status: Caps Lock, requirement changes.
        Semantics(liveRegion: true, label: _status, child: const SizedBox.shrink()),
      ],
    );
    if (disabled) field = Opacity(opacity: st.disabledOpacity, child: field);
    return field;
  }
}

/// `.reqs`: `grid-template-columns: repeat(auto-fill, minmax(min(100%,
/// list-min-column), 1fr))`, gap `list-gap` 1rem.
class _RequirementList extends StatelessWidget {
  const _RequirementList({
    required this.requirements,
    required this.minColumn,
    required this.rowGap,
    required this.style,
    required this.muted,
    required this.text,
    required this.success,
    required this.duration,
    required this.curve,
  });

  final List<({String label, bool met})> requirements;
  final double minColumn;
  final double rowGap;
  final TextStyle style;
  final Color muted;
  final Color text;
  final Color success;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    // The icon is an inline svg in a block (`.reqs .off` / `.on` spans are
    // the flex items): it stands on the text's baseline, so the item reaches
    // the line's descent below it.
    final em = style.fontSize!;
    final probe = TextPainter(
      text: TextSpan(text: 'x', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final line = probe.computeLineMetrics().first;
    probe.dispose();
    final iconTop = em * (_reqIconTop + _reqIcon);
    final iconBox = (iconTop > line.ascent ? iconTop : line.ascent) + line.descent;
    final iconShift = iconTop < line.ascent ? line.ascent - iconTop : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final column = minColumn < width ? minColumn : width;
        var n = ((width + _listColumnGap) / (column + _listColumnGap)).floor();
        if (n < 1) n = 1;
        final rows = <Widget>[];
        for (var start = 0; start < requirements.length; start += n) {
          if (rows.isNotEmpty) rows.add(SizedBox(height: rowGap));
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = start; i < start + n; i++) ...[
                  if (i > start) const SizedBox(width: _listColumnGap),
                  Expanded(
                    child: i < requirements.length
                        ? _item(requirements[i], iconBox, iconShift)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: rows);
      },
    );
  }

  Widget _item(({String label, bool met}) r, double iconBox, double iconShift) {
    final em = style.fontSize!;
    final words = r.met ? KakaoPasswordInput.texts.met : KakaoPasswordInput.texts.notMet;
    return Semantics(
      container: true,
      label: '${r.label}: $words.',
      excludeSemantics: true,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: r.met ? text : muted),
        duration: duration,
        curve: curve,
        builder: (context, color, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: iconBox,
              child: Padding(
                padding: EdgeInsets.only(top: iconShift + em * _reqIconTop),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: CustomPaint(
                    size: Size.square(em * _reqIcon),
                    painter: r.met
                        ? _GlyphPainter(_Glyph.check, success)
                        : _GlyphPainter(_Glyph.open, color!.withValues(alpha: color.a * _openOpacity)),
                  ),
                ),
              ),
            ),
            SizedBox(width: em * _reqGap),
            Expanded(
              child: Text(r.label, style: style.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.toggle`: the show / hide button at the end of the field.
class _Toggle extends StatefulWidget {
  const _Toggle({
    required this.size,
    required this.iconSize,
    required this.radius,
    required this.hoverBackground,
    required this.color,
    required this.hoverColor,
    required this.ring,
    required this.ringWidth,
    required this.ringOffset,
    required this.duration,
    required this.curve,
    required this.pressed,
    required this.label,
    required this.focusNode,
    required this.groupId,
    required this.onTap,
  });

  final double size;
  final double iconSize;
  final double radius;
  final Color hoverBackground;
  final Color color;
  final Color hoverColor;
  final Color ring;
  final double ringWidth;
  final double ringOffset;
  final Duration duration;
  final Curve curve;
  final bool pressed;
  final String label;
  final FocusNode focusNode;
  final Object groupId;

  /// Null: disabled.
  final VoidCallback? onTap;

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  bool _hover = false;
  bool _focusVisible = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final hover = _hover && enabled;
    final box = AnimatedContainer(
      duration: widget.duration,
      curve: widget.curve,
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hover ? widget.hoverBackground : widget.hoverBackground.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: hover ? widget.hoverColor : widget.color),
        duration: widget.duration,
        curve: widget.curve,
        builder: (context, color, _) => CustomPaint(
          size: Size.square(widget.iconSize),
          painter: _GlyphPainter(widget.pressed ? _Glyph.eyeOff : _Glyph.eye, color!),
        ),
      ),
    );
    return TapRegion(
      groupId: widget.groupId,
      child: Semantics(
        button: true,
        enabled: enabled,
        toggled: widget.pressed,
        label: widget.label,
        excludeSemantics: true,
        child: FocusableActionDetector(
          enabled: enabled,
          focusNode: widget.focusNode,
          mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
          onShowHoverHighlight: (v) => setState(() => _hover = v),
          onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
          actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap?.call())},
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: KakaoRing(
              color: _focusVisible && enabled ? widget.ring : null,
              width: widget.ringWidth,
              offset: widget.ringOffset,
              radius: widget.radius,
              child: box,
            ),
          ),
        ),
      ),
    );
  }
}

enum _Glyph { eye, eyeOff, caps, check, open }

/// password-input.js's icons: 24 px view box, stroke 2, round caps and joins.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);

  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (glyph) {
      case _Glyph.eye:
        // M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z
        canvas.drawPath(
          Path()
            ..moveTo(2.5, 12)
            ..cubicTo(2.5, 12, 6, 5.5, 12, 5.5)
            ..cubicTo(18, 5.5, 21.5, 12, 21.5, 12)
            ..cubicTo(21.5, 12, 18, 18.5, 12, 18.5)
            ..cubicTo(6, 18.5, 2.5, 12, 2.5, 12)
            ..close(),
          paint,
        );
        canvas.drawCircle(const Offset(12, 12), 3, paint);
      case _Glyph.eyeOff:
        // M10.6 5.6c.46-.07.92-.1 1.4-.1 6 0 9.5 6.5 9.5 6.5a17.6 17.6 0 0 1-2.5 3.4
        // M6.6 6.6C3.97 8.3 2.5 12 2.5 12S6 18.5 12 18.5c1.9 0 3.6-.65 5-1.6
        canvas.drawPath(
          Path()
            ..moveTo(10.6, 5.6)
            ..cubicTo(11.06, 5.53, 11.52, 5.5, 12, 5.5)
            ..cubicTo(18, 5.5, 21.5, 12, 21.5, 12)
            ..arcToPoint(const Offset(19, 15.4), radius: const Radius.circular(17.6))
            ..moveTo(6.6, 6.6)
            ..cubicTo(3.97, 8.3, 2.5, 12, 2.5, 12)
            ..cubicTo(2.5, 12, 6, 18.5, 12, 18.5)
            ..cubicTo(13.9, 18.5, 15.6, 17.85, 17, 16.9),
          paint,
        );
        // M9.9 9.9a3 3 0 0 0 4.2 4.2
        canvas.drawPath(
          Path()
            ..moveTo(9.9, 9.9)
            ..arcToPoint(const Offset(14.1, 14.1), radius: const Radius.circular(3), clockwise: false),
          paint,
        );
        canvas.drawLine(const Offset(3, 3), const Offset(21, 21), paint);
      case _Glyph.caps:
        // M12 4 4.5 12H9v4h6v-4h4.5L12 4Z  M9 19.5h6
        canvas.drawPath(
          Path()
            ..moveTo(12, 4)
            ..lineTo(4.5, 12)
            ..lineTo(9, 12)
            ..lineTo(9, 16)
            ..lineTo(15, 16)
            ..lineTo(15, 12)
            ..lineTo(19.5, 12)
            ..close(),
          paint,
        );
        canvas.drawLine(const Offset(9, 19.5), const Offset(15, 19.5), paint);
      case _Glyph.check:
        // M5 12.5l4.5 4.5L19 7.5
        canvas.drawPath(
          Path()
            ..moveTo(5, 12.5)
            ..lineTo(9.5, 17)
            ..lineTo(19, 7.5),
          paint,
        );
      case _Glyph.open:
        canvas.drawCircle(const Offset(12, 12), 4.5, paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph || old.color != color;
}
