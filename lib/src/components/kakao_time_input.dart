import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_anchored_panel.dart';
import '../internal/kakao_date_parts.dart';
import '../internal/kakao_date_picker.dart';
import '../internal/kakao_date_values.dart';
import '../internal/kakao_field.dart';
import '../internal/kakao_segment_field.dart';
import '../settings/kakao_select_settings.g.dart';
import '../settings/kakao_time_input_settings.g.dart';
import '../theme/kakao_theme.dart';
import '../theme/kakao_values.dart';

/// `<kakao-time-input size>`.
enum KakaoTimeInputSize { sm, md, lg }

/// Opens and closes a [KakaoTimeInput]'s picker (`showPicker()`).
class KakaoTimeInputController extends KakaoAnchoredPanelController {}

// time-input.js values outside the settings block.
const _smSize = (
  height: 36.0,
  paddingX: 10.0,
  font: 14.0,
); // --kakao-time-input-sm-height / -sm-padding-x; .field 0.875rem
const _lgSize = (height: 52.0, paddingX: 14.0, font: 16.0); // --kakao-time-input-lg-height / -lg-padding-x; .field 1rem
const _iconGap = .6; // ::-webkit-calendar-picker-indicator margin-left: calc(var(--_padding-x) * 0.6)
const _iconCentre = .45; // input margin-inline-end: calc(0.45em - icon-size / 2): the centre 0.45em in
const _labelSize = 13.12; // .label font-size: 0.82rem
const _messageSize = 12.48; // .hint, .error font-size: 0.78rem
const _belowGap = 12.0; // .below gap: 12px
const _nowHoverMix = 8.0; // .now:hover: color-mix(in srgb, now-text 8%, now-bg)
const _selectionAlpha = .25; // the focused part: the focus colour, light (the fields' text selection)
const _entrySlide = 4.0; // the select's panel entry (@keyframes kakao-select-in: translateY(-4px))

/// Flutter twin of `<kakao-time-input>`: a time field with the browser's
/// segmented editing and picker, dressed as the library's other fields. The
/// sibling of [KakaoDateInput]'s time type, with its own settings and the
/// "now" tag.
///
/// As time-input.js draws it from the `--kakao-time-input-*` settings:
/// [label] above (a tap on it focuses the field), [hint] below, or [error]
/// instead (danger border and outline, invalid in semantics). The box is
/// 36 / 44 / 52 px high ([size]); its border fades to the focus colour
/// while the field or its picker icon has focus, with the 2 px outline 2 px
/// away. [disabled] dims everything to `disabled-opacity`; [readOnly] keeps
/// the field focusable but not editable and the picker shut.
///
/// The field is the browser's: one part at a time ("02:30 PM" in en-US,
/// "14:30" in de), digits type into the focused part and move on, Up / Down
/// step it (minutes and seconds by [step]), Backspace empties it, Tab /
/// Left / Right walk the parts, "a" / "p" set AM / PM. 12 or 24 hours
/// follow [locale] (else the nearest [Localizations] locale) from a
/// built-in table, as Chromium's field follows the browser's language. A
/// [step] below 60 or not whole minutes shows seconds. The value is always
/// ISO 24-hour: 14:30 · 14:30:15, and '' while a part is missing.
///
/// The clock icon sits on the right where the select's chevron sits
/// (`icon-size`, the muted colour, the text colour under the pointer, the
/// focus colour while it has focus); it is a tab stop and opens the picker,
/// as do Alt+Down and F4 in the field, a tap on the field on touch
/// platforms, and [controller]`.open()`. Disabled and read-only fields show
/// no icon. The picker is on an anchored panel below the field (above when
/// there is more room there), drawn in the select's panel chrome: time
/// columns (hours, minutes by [step], seconds, AM / PM); rows outside
/// [min] / [max] are dimmed and cannot be picked.
///
/// [now] shows a small tag in the row under the field that sets the current
/// time ([step] counted from [min]; without step the minute) as a user
/// edit; outside [min] / [max] it stays but is disabled and says why in
/// semantics; hidden while disabled or read only.
///
/// [onChanged] is `input` (the value changed: an edit, a pick, the tag);
/// [onCommitted] is `change` (the user left a part, picked, or used the
/// tag, and the value differs from the last commit). A new [value] from
/// the owner shows without reporting.
class KakaoTimeInput extends StatefulWidget {
  const KakaoTimeInput({
    super.key,
    this.value = '',
    this.onChanged,
    this.onCommitted,
    this.label,
    this.semanticLabel,
    this.hint,
    this.error,
    this.min,
    this.max,
    this.step,
    this.size = KakaoTimeInputSize.md,
    this.disabled = false,
    this.readOnly = false,
    this.now = false,
    this.nowLabel,
    this.locale,
    this.controller,
    this.autofocus = false,
    this.focusNode,
  });

  /// `value`: the ISO 24-hour value (14:30 · 14:30:15).
  final String value;

  /// `input`: the ISO value ('' while incomplete) after each change.
  final ValueChanged<String>? onChanged;

  /// `change`: the value when the user commits it.
  final ValueChanged<String>? onCommitted;

  /// `label`: shown above the field.
  final String? label;

  /// `aria-label`: the name without a visible [label]; default
  /// [texts]`.name`.
  final String? semanticLabel;

  /// `hint`: below the field, hidden while there is an [error].
  final String? hint;

  /// `error`: the danger border and outline, the message below.
  final String? error;

  /// `min` · `max`: ISO times; min after max is a range over midnight
  /// (22:00 to 06:00). The picker dims what is outside, the now tag says so.
  final String? min;
  final String? max;

  /// `step`: seconds (default 60). Below 60, or not whole minutes, the field
  /// shows seconds.
  final num? step;

  /// `size`.
  final KakaoTimeInputSize size;

  /// `disabled`.
  final bool disabled;

  /// `readonly`.
  final bool readOnly;

  /// `now`: the now tag.
  final bool now;

  /// `now-label`: the tag's text; default from [locale] ("Now", "Jetzt" …).
  final String? nowLabel;

  /// `locale`: the field's format; default the nearest [Localizations]
  /// locale, else the platform's.
  final Locale? locale;

  /// `showPicker()`.
  final KakaoTimeInputController? controller;
  final bool autofocus;

  /// The field's focus (its parts; the picker icon has its own).
  final FocusNode? focusNode;

  /// `KakaoTimeInput.texts`: built-in English texts (the picker's words
  /// too: Chromium writes its picker in the browser's language).
  static ({
    String name,
    String picker,
    String setTo,
    String outOfRange,
    String hours,
    String minutes,
    String seconds,
    String dayPeriod,
    String am,
    String pm,
  })
  texts = (
    name: 'Time',
    picker: 'Show picker',
    setTo: 'Set to',
    outOfRange: 'is outside the allowed range',
    hours: 'Hours',
    minutes: 'Minutes',
    seconds: 'Seconds',
    dayPeriod: 'AM / PM',
    am: 'AM',
    pm: 'PM',
  );

  /// The clock the now tag reads (a test can fix it).
  static DateTime Function() clock = DateTime.now;

  /// `valueAsNumber`: milliseconds since midnight, or null.
  static int? valueAsNumber(String value) {
    final m = RegExp(r'^(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?$').firstMatch(value);
    if (m == null) return null;
    final secs = int.parse(m.group(1)!) * 3600 + int.parse(m.group(2)!) * 60 + int.parse(m.group(3) ?? '0');
    return secs * 1000 + int.parse((m.group(4) ?? '0').padRight(3, '0'));
  }

  /// `valueAsDate`: the time on 1970-01-01 UTC, or null.
  static DateTime? valueAsDate(String value) {
    final n = valueAsNumber(value);
    return n == null ? null : DateTime.fromMillisecondsSinceEpoch(n, isUtc: true);
  }

  /// time-input.js `nowLabel` for the languages it is checked against here
  /// (Intl's relative-time word for "now" in English, German, French,
  /// Spanish, Italian, capitalised); other languages get English.
  static String nowLabelFor(Locale? locale) => switch (locale?.languageCode.toLowerCase()) {
    'de' => 'Jetzt',
    'fr' => 'Maintenant',
    'es' => 'Ahora',
    'it' => 'Ora',
    _ => 'Now',
  };

  @override
  State<KakaoTimeInput> createState() => _KakaoTimeInputState();
}

class _KakaoTimeInputState extends State<KakaoTimeInput> {
  static const _kind = KakaoDateKind.time;

  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'KakaoTimeInput'));
  final _iconFocus = FocusNode(debugLabel: 'KakaoTimeInput picker icon');

  /// Holds focus while the field or its icon has it.
  final _within = FocusNode(debugLabel: 'KakaoTimeInput field', canRequestFocus: false, skipTraversal: true);
  KakaoTimeInputController? _ownCtl;
  KakaoAnchoredPanelController get _ctl => widget.controller ?? (_ownCtl ??= KakaoTimeInputController());

  /// The field and its picker: a pointer down elsewhere blurs the field.
  final _group = Object();
  final _segments = GlobalKey<KakaoSegmentFieldState>();

  KakaoDateFields _fields = KakaoDateFields.empty;
  KakaoDateFormat? _format;

  /// The value last reported (`input`) and committed (`change`).
  late String _reported = widget.value;
  late String _committed = widget.value;
  bool _focused = false;
  bool _open = false;

  KakaoDateFormat get _fmt => _format ?? KakaoDateFormat.enUS;
  bool get _seconds => kakaoShowsSeconds(widget.step, widget.value);
  double get _step => kakaoStep(_kind, widget.step);
  String get _value => kakaoIsoValue(_kind, _fields, hour12: _fmt.hour12, seconds: _seconds);

  Locale? get _locale =>
      widget.locale ?? Localizations.maybeLocaleOf(context) ?? WidgetsBinding.instance.platformDispatcher.locale;

  @override
  void initState() {
    super.initState();
    _within.addListener(_focusChanged);
    _ctl.addListener(_openChanged);
    if (widget.autofocus && !widget.disabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFormat(_format == null ? widget.value : _value);
  }

  /// The locale's format; the parts re-read for its clock (12 / 24 hours).
  void _syncFormat(String value) {
    final fmt = KakaoDateFormat.forLocale(_locale);
    if (fmt == _format) return;
    _format = fmt;
    _fields = kakaoParseIso(_kind, value, hour12: fmt.hour12);
  }

  @override
  void didUpdateWidget(KakaoTimeInput old) {
    super.didUpdateWidget(old);
    final oldCtl = old.controller ?? _ownCtl;
    if (oldCtl != _ctl) {
      oldCtl?.removeListener(_openChanged);
      _ctl.addListener(_openChanged);
      _open = _ctl.isOpen;
    }
    _syncFormat(_value);
    // A new value from the owner shows without reporting.
    if (widget.value != old.value && widget.value != _value) {
      _fields = kakaoParseIso(_kind, widget.value, hour12: _fmt.hour12);
      _reported = _committed = _value;
    }
  }

  @override
  void dispose() {
    _within.removeListener(_focusChanged);
    _ctl.removeListener(_openChanged);
    _ownFocus?.dispose();
    _iconFocus.dispose();
    _within.dispose();
    _ownCtl?.dispose();
    super.dispose();
  }

  void _focusChanged() {
    final f = _within.hasFocus;
    if (f != _focused && mounted) setState(() => _focused = f);
  }

  void _openChanged() {
    if (_ctl.isOpen != _open && mounted) setState(() => _open = _ctl.isOpen);
  }

  /// An edit of the parts: `input` when the value changed.
  void _edit(KakaoDateFields f) {
    setState(() => _fields = f);
    final v = _value;
    if (v != _reported) {
      _reported = v;
      widget.onChanged?.call(v);
    }
  }

  /// `change`: when the value differs from the last commit.
  void _commit() {
    final v = _value;
    if (v == _committed) return;
    _committed = v;
    widget.onCommitted?.call(v);
  }

  void _openPicker() {
    if (widget.disabled || widget.readOnly) return;
    _ctl.open();
  }

  void _togglePicker() {
    if (_ctl.isOpen) {
      _ctl.close();
    } else {
      _openPicker();
    }
  }

  /* ---- now tag ---- */

  /// time-input.js `_nowTarget`: the value the tag sets now and whether min
  /// and max allow it (`nowValues` and `inRange`, shared with date-input).
  ({String value, bool allowed}) _nowTarget() {
    final values = kakaoTodayValues(_kind, widget.step, widget.min, KakaoTimeInput.clock());
    for (final v in values) {
      if (kakaoInRange(_kind, v, widget.min, widget.max)) return (value: v, allowed: true);
    }
    return (value: values.first, allowed: false);
  }

  void _applyNow() {
    final t = _nowTarget();
    if (!t.allowed || widget.disabled || widget.readOnly) return;
    setState(() => _fields = kakaoParseIso(_kind, t.value, hour12: _fmt.hour12));
    final v = _value;
    _reported = v;
    widget.onChanged?.call(v);
    _committed = v;
    widget.onCommitted?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoTimeInputSettings.of(theme.colors);
    final sel = KakaoSelectSettings.of(theme.colors);
    final (height, paddingX, fontSize) = switch (widget.size) {
      KakaoTimeInputSize.sm => (_smSize.height, _smSize.paddingX, _smSize.font),
      KakaoTimeInputSize.md => (st.height, st.paddingX, st.font.size),
      KakaoTimeInputSize.lg => (_lgSize.height, _lgSize.paddingX, _lgSize.font),
    };
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final error = widget.error?.isNotEmpty ?? false ? widget.error : null;
    final hint = widget.hint?.isNotEmpty ?? false ? widget.hint : null;
    final texts = KakaoTimeInput.texts;
    final name = widget.label ?? widget.semanticLabel ?? texts.name;
    final disabled = widget.disabled;
    final active = !disabled && !widget.readOnly;
    final touch = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => true,
      _ => false,
    };
    final dayPeriods = (texts.am, texts.pm);
    // .field input: font: inherit; font-variant-numeric: tabular-nums.
    final textStyle = theme.text(size: fontSize, color: st.text, height: st.font.lineHeight, tabular: true);

    final segments = KakaoSegmentField(
      key: _segments,
      layout: _fmt.layout(_kind, seconds: _seconds),
      fields: _fields,
      format: _fmt,
      focusNode: _focus,
      style: textStyle,
      highlight: st.focus.withValues(alpha: _selectionAlpha),
      step: _step,
      enabled: !disabled,
      readOnly: widget.readOnly,
      dayPeriods: dayPeriods,
      onChanged: _edit,
      onCommit: _commit,
      onOpenPicker: _openPicker,
      tapOpensPicker: touch,
      now: KakaoTimeInput.clock,
    );
    final spoken = _value.isEmpty ? '' : (_segments.currentState?.text ?? _value);
    final input = Semantics(
      label: name,
      value: spoken,
      hint: error ?? hint,
      enabled: !disabled,
      readOnly: widget.readOnly,
      focusable: !disabled,
      focused: _focus.hasFocus,
      expanded: _open,
      validationResult: error != null ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
      onTap: active ? _openPicker : null,
      excludeSemantics: true,
      child: ExcludeFocus(
        excluding: disabled,
        child: MouseRegion(cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.text, child: segments),
      ),
    );

    // The clock icon: icon-size, centred 0.45em in from the padding edge.
    final iconSize = st.iconSize.of(fontSize);
    final icon = KakaoPickerIcon(
      focusNode: _iconFocus,
      size: iconSize,
      clock: true,
      color: st.muted,
      hoverColor: st.text,
      focusColor: st.focus,
      enabled: active,
      semanticLabel: texts.picker,
      onTap: _togglePicker,
    );
    final endMargin = _iconCentre * fontSize - iconSize / 2;

    final row = Row(
      children: [
        // input height: calc(var(--_height) - 2px).
        Expanded(
          child: SizedBox(
            height: height - 2,
            child: Align(alignment: AlignmentDirectional.centerStart, child: input),
          ),
        ),
        // Chromium draws no picker icon on a disabled or read-only field.
        if (active) ...[
          SizedBox(width: paddingX * _iconGap),
          // A negative end margin (icon-size above 0.9em) moves the icon into
          // the padding.
          if (endMargin < 0)
            Transform.translate(
              offset: Offset(Directionality.of(context) == TextDirection.rtl ? endMargin : -endMargin, 0),
              child: icon,
            )
          else ...[
            icon,
            SizedBox(width: endMargin),
          ],
        ],
      ],
    );

    Widget box = KakaoFieldBox(
      height: height,
      paddingX: paddingX,
      radius: st.radius,
      background: st.bg,
      // :host([error]) wins over focus.
      border: error != null
          ? st.danger
          : _focused || _open
          ? st.focus
          : st.border,
      ring: _focused && !disabled ? (error != null ? st.danger : st.focus) : null,
      ringWidth: st.focusWidth,
      ringOffset: st.focusOffset,
      duration: reduce ? Duration.zero : st.duration,
      curve: st.ease,
      child: row,
    );
    box = TapRegion(
      groupId: _group,
      onTapOutside: (_) {
        if (_within.hasFocus && !_ctl.isOpen) FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Focus(
        focusNode: _within,
        includeSemantics: false,
        child: GestureDetector(
          // A tap beside the parts focuses the field (its first part).
          onTap: disabled || _within.hasFocus ? null : _focus.requestFocus,
          child: box,
        ),
      ),
    );

    // The browser draws the picker; here it is the select's panel chrome
    // around time columns, in the field's colours.
    final pickerStyle = KakaoPickerStyle(
      text: textStyle,
      heading: theme.text(size: fontSize, weight: st.labelWeight, color: st.text, height: st.font.lineHeight),
      small: theme.text(size: _messageSize, color: st.muted, height: st.font.lineHeight),
      textColor: st.text,
      muted: st.muted,
      background: sel.panelBg,
      hover: sel.hoverBg,
      selected: sel.boxCheckedBg,
      onSelected: sel.mark,
      focus: st.focus,
      radius: sel.panelRadius,
      cellRadius: sel.optionRadius,
      cell: sel.optionHeight,
      padding: sel.panelPadding,
      shadow: sel.panelShadow,
      disabledOpacity: st.disabledOpacity,
      focusWidth: st.focusWidth,
    );
    final field = KakaoAnchoredPanel(
      controller: _ctl,
      enabled: active,
      tapRegionGroup: _group,
      // The select's panel: below, panel-offset away, from the field's left
      // edge; above when there is no room below and more above.
      placement: KakaoPanelPlacement(
        side: KakaoPanelSide.bottom,
        align: KakaoPanelAlign.start,
        offset: sel.panelOffset,
        flip: KakaoPanelFlip.towardMoreRoom,
        keepSide: true,
      ),
      motion: KakaoPanelMotion(duration: st.duration, curve: st.ease, slide: _entrySlide),
      panelBuilder: (context, side) => KakaoDatePicker(
        kind: _kind,
        fields: _fields,
        format: _fmt,
        style: pickerStyle,
        // The time columns use only their names; the calendar's words stay empty.
        texts: (
          clear: '',
          today: '',
          previous: '',
          next: '',
          chooseMonth: '',
          week: '',
          weekdays: const [],
          months: KakaoDateFormat.englishMonths,
          monthsShort: const [],
          hours: texts.hours,
          minutes: texts.minutes,
          seconds: texts.seconds,
          dayPeriod: texts.dayPeriod,
        ),
        min: widget.min,
        max: widget.max,
        step: _step,
        seconds: _seconds,
        dayPeriods: dayPeriods,
        now: KakaoTimeInput.clock,
        onPick: (f, {required done}) {
          _edit(f);
          _commit();
          if (done) _ctl.close();
        },
        onClear: () {
          _edit(KakaoDateFields.empty);
          _commit();
          _ctl.close();
        },
        onClose: _ctl.close,
      ),
      child: box,
    );

    Widget? tag;
    if (widget.now && active) {
      final label = widget.nowLabel ?? KakaoTimeInput.nowLabelFor(_locale);
      final target = _nowTarget();
      // "Set to now" where the words are English; elsewhere the label alone.
      final english = widget.nowLabel == null && (_locale?.languageCode ?? 'en') == 'en';
      final range = widget.min != null && widget.max != null
          ? '${widget.min} to ${widget.max}'
          : widget.min != null
          ? '${widget.min} or later'
          : '${widget.max} or earlier';
      tag = KakaoTodayTag(
        label: label,
        semanticLabel: english ? '${texts.setTo} ${label.toLowerCase()}' : label,
        reason: target.allowed ? null : '$label (${target.value}) ${texts.outOfRange}: $range.',
        style: theme.text(size: st.nowFontSize, weight: st.nowFontWeight, color: st.nowText, height: 1),
        height: st.nowHeight,
        paddingX: st.nowPaddingX,
        radius: st.nowRadius,
        background: st.nowBg,
        hoverBackground: kakaoMix(st.nowText, _nowHoverMix, st.nowBg, null),
        focus: st.focus,
        focusWidth: st.focusWidth,
        focusOffset: st.focusOffset,
        disabledOpacity: st.disabledOpacity,
        duration: reduce ? Duration.zero : st.duration,
        curve: st.ease,
        onTap: target.allowed ? _applyNow : null,
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
      disabledOpacity: disabled ? st.disabledOpacity : null,
      // <label for>: focuses the field.
      onLabelTap: disabled ? null : _focus.requestFocus,
      counter: tag,
      counterGap: _belowGap,
      // .now margin-inline-start: auto: always at the end.
      messageMinWidth: 0,
      child: field,
    );
  }
}
