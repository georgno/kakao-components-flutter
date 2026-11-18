import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_anchored_panel.dart';
import '../internal/kakao_date_picker.dart';
import '../internal/kakao_date_values.dart';
import '../internal/kakao_field.dart';
import '../internal/kakao_segment_field.dart';
import '../settings/kakao_date_input_settings.g.dart';
import '../settings/kakao_select_settings.g.dart';
import '../theme/kakao_theme.dart';
import '../theme/kakao_values.dart';

/// `<kakao-date-input size>`.
enum KakaoDateInputSize { sm, md, lg }

/// `<kakao-date-input type>`.
enum KakaoDateInputType {
  date(KakaoDateKind.date),
  time(KakaoDateKind.time),
  dateTimeLocal(KakaoDateKind.dateTimeLocal),
  month(KakaoDateKind.month),
  week(KakaoDateKind.week);

  const KakaoDateInputType(this._kind);
  final KakaoDateKind _kind;
}

/// Opens and closes a [KakaoDateInput]'s picker (`showPicker()`).
class KakaoDateInputController extends KakaoAnchoredPanelController {}

// date-input.js values outside the settings block.
const _smSize = (
  height: 36.0,
  paddingX: 10.0,
  font: 14.0,
); // --kakao-date-input-sm-height / -sm-padding-x; .field 0.875rem
const _lgSize = (height: 52.0, paddingX: 14.0, font: 16.0); // --kakao-date-input-lg-height / -lg-padding-x; .field 1rem
const _iconGap = .6; // ::-webkit-calendar-picker-indicator margin-left: calc(var(--_padding-x) * 0.6)
const _iconCentre = .45; // input margin-inline-end: calc(0.45em - icon-size / 2): the centre 0.45em in
const _labelSize = 13.12; // .label font-size: 0.82rem
const _messageSize = 12.48; // .hint, .error font-size: 0.78rem
const _belowGap = 12.0; // .below gap: 12px
const _todayHoverMix = 8.0; // .today:hover: color-mix(in srgb, today-text 8%, today-bg)
const _selectionAlpha = .25; // the focused part: the focus colour, light (the fields' text selection)
const _entrySlide = 4.0; // the select's panel entry (@keyframes kakao-select-in: translateY(-4px))

/// Flutter twin of `<kakao-date-input>`: a date, time, date-and-time, month
/// or week field with the browser's segmented editing and picker, dressed
/// as the library's other fields.
///
/// As date-input.js draws it from the `--kakao-date-input-*` settings:
/// [label] above (a tap on it focuses the field), [hint] below, or [error]
/// instead (danger border and outline, invalid in semantics). The box is
/// 36 / 44 / 52 px high ([size]); its border fades to the focus colour
/// while the field or its picker icon has focus, with the 2 px outline 2 px
/// away. [disabled] dims everything to `disabled-opacity`; [readOnly] keeps
/// the field focusable but not editable and the picker shut.
///
/// The field is the browser's: one part at a time ("03/04/2026" in en-US:
/// month, day, year; "02:30 PM"; "March 2026"; "Week 10, 2026"), digits
/// type into the focused part and move on, Up / Down step it, Backspace
/// empties it, Tab / Left / Right walk the parts. The order, separators, 12
/// or 24 hours and empty-part placeholders follow [locale] (else the
/// nearest [Localizations] locale) from a built-in table, as Chromium's
/// field follows the browser's language. The value is always ISO:
/// 2026-03-04 · 14:30 · 2026-03-04T14:30 · 2026-03 · 2026-W10, and '' while
/// a part is missing.
///
/// The picker icon sits on the right where the select's chevron sits
/// (`icon-size`, the muted colour, the text colour under the pointer, the
/// focus colour while it has focus; a calendar, or a clock for [type]
/// time); it is a tab stop and opens the picker, as do Alt+Down and F4 in
/// the field, a tap on the field on touch platforms, and
/// [controller]`.open()`. The picker is on an anchored panel below the
/// field (above when there is more room there), drawn in the select's
/// panel chrome: a month calendar (a week number column and the week as
/// the pick for week; time columns beside it for date and time), a year
/// of months for month (and from the calendar's header), time columns for
/// time; days outside [min] / [max] or off [step] are disabled; Clear and
/// Today at the foot.
///
/// [today] shows a small tag in the row under the field that sets the
/// current day, time ([step] counted from [min]), month or ISO week, as a
/// user edit; outside [min] / [max] it stays but is disabled and says why
/// in semantics; hidden while disabled or read only.
///
/// [onChanged] is `input` (the value changed: an edit, a pick, the tag);
/// [onCommitted] is `change` (the user left a part, picked, or used the
/// tag, and the value differs from the last commit). A new [value] from
/// the owner shows without reporting.
class KakaoDateInput extends StatefulWidget {
  const KakaoDateInput({
    super.key,
    this.value = '',
    this.type = KakaoDateInputType.date,
    this.onChanged,
    this.onCommitted,
    this.label,
    this.semanticLabel,
    this.hint,
    this.error,
    this.min,
    this.max,
    this.step,
    this.size = KakaoDateInputSize.md,
    this.disabled = false,
    this.readOnly = false,
    this.today = false,
    this.todayLabel,
    this.locale,
    this.controller,
    this.autofocus = false,
    this.focusNode,
  });

  /// `value`: the ISO value (2026-03-04 · 14:30 · 2026-03-04T14:30 ·
  /// 2026-03 · 2026-W10).
  final String value;

  /// `type`.
  final KakaoDateInputType type;

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

  /// `min` · `max`: ISO values of [type]; the picker disables what is
  /// outside, and the today tag says so. A time range may run over midnight.
  final String? min;
  final String? max;

  /// `step`: seconds for times, days for dates, weeks, months (default
  /// 60 s / 1).
  final num? step;

  /// `size`.
  final KakaoDateInputSize size;

  /// `disabled`.
  final bool disabled;

  /// `readonly`.
  final bool readOnly;

  /// `today`: the today tag.
  final bool today;

  /// `today-label`: the tag's text; default from [locale] ("Today", "Now",
  /// "This month", "This week"; "Heute", "Jetzt" …).
  final String? todayLabel;

  /// `locale`: the field's format; default the nearest [Localizations]
  /// locale, else the platform's.
  final Locale? locale;

  /// `showPicker()`.
  final KakaoDateInputController? controller;
  final bool autofocus;

  /// The field's focus (its parts; the picker icon has its own).
  final FocusNode? focusNode;

  /// `KakaoDateInput.texts`: built-in English texts (the picker's words
  /// too: Chromium writes its picker in the browser's language).
  static ({
    String name,
    String picker,
    String setTo,
    String outOfRange,
    String clear,
    String previous,
    String next,
    String chooseMonth,
    String week,
    List<String> weekdays,
    List<String> monthsShort,
    String hours,
    String minutes,
    String seconds,
    String dayPeriod,
    String am,
    String pm,
  })
  texts = (
    name: 'Date',
    picker: 'Show picker',
    setTo: 'Set to',
    outOfRange: 'is outside the allowed range',
    clear: 'Clear',
    previous: 'Previous',
    next: 'Next',
    chooseMonth: 'Choose month and year',
    week: 'Wk',
    weekdays: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
    monthsShort: const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
    hours: 'Hours',
    minutes: 'Minutes',
    seconds: 'Seconds',
    dayPeriod: 'AM / PM',
    am: 'AM',
    pm: 'PM',
  );

  /// The clock "today" and the picker's today read (a test can fix it).
  static DateTime Function() clock = DateTime.now;

  /// `valueAsDate`: the value as a UTC [DateTime] (a time on 1970-01-01, a
  /// month's first day, a week's Monday), or null.
  static DateTime? valueAsDate(KakaoDateInputType type, String value) {
    final f = kakaoParseIso(type._kind, value, hour12: false);
    switch (type) {
      case KakaoDateInputType.date:
        return f.year == null ? null : DateTime.utc(f.year!, f.month!, f.day!);
      case KakaoDateInputType.dateTimeLocal:
        return f.year == null ? null : DateTime.utc(f.year!, f.month!, f.day!, f.hour!, f.minute!, f.second ?? 0);
      case KakaoDateInputType.time:
        return f.hour == null ? null : DateTime.utc(1970, 1, 1, f.hour!, f.minute!, f.second ?? 0);
      case KakaoDateInputType.month:
        return f.year == null ? null : DateTime.utc(f.year!, f.month!);
      case KakaoDateInputType.week:
        return f.year == null ? null : kakaoIsoWeekMonday(f.year!, f.week!);
    }
  }

  /// date-input.js `todayLabel` for the languages it is checked against
  /// here (Intl's relative-time words for "now" in English, German,
  /// French, Spanish, Italian); other languages get English.
  static String todayLabelFor(KakaoDateInputType type, Locale? locale) {
    final i = switch (type) {
      KakaoDateInputType.date => 0,
      KakaoDateInputType.time || KakaoDateInputType.dateTimeLocal => 1,
      KakaoDateInputType.month => 2,
      KakaoDateInputType.week => 3,
    };
    final words = switch (locale?.languageCode.toLowerCase()) {
      'de' => const ['Heute', 'Jetzt', 'Diesen Monat', 'Diese Woche'],
      'fr' => const ['Aujourd’hui', 'Maintenant', 'Ce mois-ci', 'Cette semaine'],
      'es' => const ['Hoy', 'Ahora', 'Este mes', 'Esta semana'],
      'it' => const ['Oggi', 'Ora', 'Questo mese', 'Questa settimana'],
      _ => const ['Today', 'Now', 'This month', 'This week'],
    };
    return words[i];
  }

  @override
  State<KakaoDateInput> createState() => _KakaoDateInputState();
}

class _KakaoDateInputState extends State<KakaoDateInput> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'KakaoDateInput'));
  final _iconFocus = FocusNode(debugLabel: 'KakaoDateInput picker icon');

  /// Holds focus while the field or its icon has it.
  final _within = FocusNode(debugLabel: 'KakaoDateInput field', canRequestFocus: false, skipTraversal: true);
  KakaoDateInputController? _ownCtl;
  KakaoAnchoredPanelController get _ctl => widget.controller ?? (_ownCtl ??= KakaoDateInputController());

  /// The field and its picker: a pointer down elsewhere blurs the field.
  final _group = Object();
  final _segments = GlobalKey<KakaoSegmentFieldState>();

  KakaoDateFields _fields = KakaoDateFields.empty;
  KakaoDateFormat? _format;

  /// The value the owner last gave, the last reported (`input`) and committed (`change`).
  late String _reported = widget.value;
  late String _committed = widget.value;
  bool _focused = false;
  bool _open = false;

  KakaoDateKind get _kind => widget.type._kind;
  KakaoDateFormat get _fmt => _format ?? KakaoDateFormat.enUS;
  bool get _seconds => _kind.hasTime && kakaoShowsSeconds(widget.step, widget.value);
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
    final fmt = KakaoDateFormat.forLocale(_locale);
    if (fmt == _format) return;
    final value = _format == null ? widget.value : _value;
    _format = fmt;
    _fields = kakaoParseIso(_kind, value, hour12: fmt.hour12);
  }

  @override
  void didUpdateWidget(KakaoDateInput old) {
    super.didUpdateWidget(old);
    final oldCtl = old.controller ?? _ownCtl;
    if (oldCtl != _ctl) {
      oldCtl?.removeListener(_openChanged);
      _ctl.addListener(_openChanged);
      _open = _ctl.isOpen;
    }
    final fmt = KakaoDateFormat.forLocale(_locale);
    if (fmt != _format || old.type != widget.type) {
      final value = old.type != widget.type
          ? kakaoIsoValue(old.type._kind, _fields, hour12: _fmt.hour12, seconds: _seconds)
          : _value;
      _format = fmt;
      _fields = kakaoParseIso(_kind, value, hour12: fmt.hour12);
    }
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

  /* ---- today tag ---- */

  /// date-input.js `_todayTarget`: the value the tag sets now and whether
  /// min and max allow it.
  ({String value, bool allowed}) _todayTarget() {
    final values = kakaoTodayValues(_kind, widget.step, widget.min, KakaoDateInput.clock());
    for (final v in values) {
      if (kakaoInRange(_kind, v, widget.min, widget.max)) return (value: v, allowed: true);
    }
    return (value: values.first, allowed: false);
  }

  void _applyToday() {
    final t = _todayTarget();
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
    final st = KakaoDateInputSettings.of(theme.colors);
    final sel = KakaoSelectSettings.of(theme.colors);
    final (height, paddingX, fontSize) = switch (widget.size) {
      KakaoDateInputSize.sm => (_smSize.height, _smSize.paddingX, _smSize.font),
      KakaoDateInputSize.md => (st.height, st.paddingX, st.font.size),
      KakaoDateInputSize.lg => (_lgSize.height, _lgSize.paddingX, _lgSize.font),
    };
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final error = widget.error?.isNotEmpty ?? false ? widget.error : null;
    final hint = widget.hint?.isNotEmpty ?? false ? widget.hint : null;
    final name = widget.label ?? widget.semanticLabel ?? KakaoDateInput.texts.name;
    final disabled = widget.disabled;
    final touch = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => true,
      _ => false,
    };
    final texts = KakaoDateInput.texts;
    final dayPeriods = (texts.am, texts.pm);
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
      now: KakaoDateInput.clock,
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
      onTap: disabled || widget.readOnly ? null : _openPicker,
      excludeSemantics: true,
      child: ExcludeFocus(
        excluding: disabled,
        child: MouseRegion(cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.text, child: segments),
      ),
    );

    // The picker icon: icon-size, centred 0.45em in from the padding edge.
    final iconSize = st.iconSize.of(fontSize);
    final icon = _PickerIcon(
      focusNode: _iconFocus,
      size: iconSize,
      clock: _kind == KakaoDateKind.time,
      color: st.muted,
      hoverColor: st.text,
      focusColor: st.focus,
      enabled: !disabled && !widget.readOnly,
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
        if (!disabled && !widget.readOnly) ...[
          SizedBox(width: paddingX * _iconGap),
          // A negative end margin (icon-size above 0.9em) moves the icon into
          // the padding.
          if (endMargin < 0)
            Transform.translate(
              offset: Offset(Directionality.of(context) == TextDirection.rtl ? endMargin : -endMargin, 0),
              child: ExcludeFocus(excluding: disabled, child: icon),
            )
          else ...[
            ExcludeFocus(excluding: disabled, child: icon),
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

    final pickerStyle = KakaoPickerStyle(
      text: theme.text(size: fontSize, color: st.text, height: st.font.lineHeight, tabular: true),
      // As the field's label: label-weight.
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
    final months = _fmt.monthNames ?? KakaoDateFormat.englishMonths;
    final field = KakaoAnchoredPanel(
      controller: _ctl,
      enabled: !disabled && !widget.readOnly,
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
        texts: (
          clear: texts.clear,
          today: widget.todayLabel ?? KakaoDateInput.todayLabelFor(widget.type, _locale),
          previous: texts.previous,
          next: texts.next,
          chooseMonth: texts.chooseMonth,
          week: texts.week,
          weekdays: texts.weekdays,
          months: months,
          monthsShort: texts.monthsShort,
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
        now: KakaoDateInput.clock,
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
    if (widget.today && !disabled && !widget.readOnly) {
      final label = widget.todayLabel ?? KakaoDateInput.todayLabelFor(widget.type, _locale);
      final target = _todayTarget();
      final english = widget.todayLabel == null && (_locale?.languageCode ?? 'en') == 'en';
      final range = widget.min != null && widget.max != null
          ? '${widget.min} to ${widget.max}'
          : widget.min != null
          ? '${widget.min} or later'
          : '${widget.max} or earlier';
      tag = _TodayTag(
        label: label,
        semanticLabel: english ? '${texts.setTo} ${label.toLowerCase()}' : label,
        reason: target.allowed ? null : '$label (${target.value}) ${texts.outOfRange}: $range.',
        style: theme.text(size: st.todayFontSize, weight: st.todayFontWeight, color: st.todayText, height: 1),
        height: st.todayHeight,
        paddingX: st.todayPaddingX,
        radius: st.todayRadius,
        background: st.todayBg,
        hoverBackground: kakaoMix(st.todayText, _todayHoverMix, st.todayBg, null),
        focus: st.focus,
        focusWidth: st.focusWidth,
        focusOffset: st.focusOffset,
        disabledOpacity: st.disabledOpacity,
        duration: reduce ? Duration.zero : st.duration,
        curve: st.ease,
        onTap: target.allowed ? _applyToday : null,
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
      // .today margin-inline-start: auto: always at the end.
      messageMinWidth: 0,
      child: field,
    );
  }
}

/// The picker icon (Chromium's `::-webkit-calendar-picker-indicator`,
/// redrawn): a tab stop of its own, the muted colour, the text colour under
/// the pointer, the focus colour while it has focus.
class _PickerIcon extends StatefulWidget {
  const _PickerIcon({
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
  State<_PickerIcon> createState() => _PickerIconState();
}

class _PickerIconState extends State<_PickerIcon> {
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

/// date-input.js `CALENDAR` / `CLOCK`: 24-unit glyphs, stroke 2, round caps
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

/// The today tag (`.today`): the chip's neutral tag as a real button,
/// today-height high, its hover fill, the focus outline, disabled (out of
/// range) at disabled-opacity with the reason in semantics.
class _TodayTag extends StatefulWidget {
  const _TodayTag({
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
  State<_TodayTag> createState() => _TodayTagState();
}

class _TodayTagState extends State<_TodayTag> {
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
