import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_anchored_panel.dart';
import '../internal/kakao_option_list.dart';
import '../settings/kakao_select_settings.g.dart';
import '../theme/kakao_theme.dart';

/// `<kakao-select size>`.
enum KakaoSelectSize { sm, md, lg }

/// An entry of `list-data`: a [KakaoSelectOption] or a [KakaoSelectGroup].
@immutable
sealed class KakaoSelectEntry {
  const KakaoSelectEntry();
}

/// An option (`{ value, label?, disabled? }`, or a plain string: the value).
class KakaoSelectOption extends KakaoSelectEntry {
  const KakaoSelectOption(this.value, {String? label, this.disabled = false}) : label = label ?? value;

  final String value;

  /// Shown in the list and on the trigger; default: [value].
  final String label;

  /// Shown in the muted colour, cannot be picked, skipped by the keys.
  final bool disabled;
}

/// Options under a heading (`{ label, options }`, `<optgroup label>`).
/// [disabled] disables all of them.
class KakaoSelectGroup extends KakaoSelectEntry {
  const KakaoSelectGroup(this.label, this.options, {this.disabled = false});

  final String label;
  final List<KakaoSelectOption> options;
  final bool disabled;
}

/// `select-change` (with `input` and `change`): the user changed the selection.
@immutable
class KakaoSelectChange {
  const KakaoSelectChange._(this.values, this.previous);

  /// The selection, in list order.
  final List<String> values;

  /// The selection before.
  final List<String> previous;

  /// [values] joined with "," (the web's `value`); a single select: its value or "".
  String get value => values.join(',');
}

/// Opens and closes a [KakaoSelect]'s panel (`open()`, `close()`, `isOpen`).
class KakaoSelectController extends KakaoAnchoredPanelController {}

// select.js values outside the settings block.
const _smSize = (
  height: 36.0,
  paddingX: 10.0,
  font: 14.0,
); // --kakao-select-sm-height / -sm-padding-x; .trigger 0.875rem
const _lgSize = (height: 52.0, paddingX: 14.0, font: 16.0); // --kakao-select-lg-height / -lg-padding-x; .trigger 1rem
const _triggerGap = .6; // .trigger gap: calc(var(--_padding-x) * 0.6)
const _moreGap = .4; // .text gap: 0.4em
const _chevronTurn = Duration(milliseconds: 200); // .chevron transition: transform 200ms
const _labelSize = 13.12; // .label font-size: 0.82rem
const _messageSize = 12.48; // .hint, .error font-size: 0.78rem
const _pageStep = 8; // PAGE_STEP
const _rowPadding = EdgeInsets.symmetric(vertical: 6.4, horizontal: 9.6); // .row padding: 0.4rem 0.6rem
const _rowGap = 8.8; // .row gap: 0.55rem
const _rowLineHeight = 1.3; // .row line-height: 1.3
const _checkSize = 1.1; // .check width: 1.1em
const _selectedWeight = 600.0; // .row[aria-selected="true"] font-weight: 600
const _headingSize = 12.48; // .group-label font-size: 0.78rem
const _headingWeight = 600.0; // .group-label font-weight: 600
const _headingPadding = EdgeInsets.fromLTRB(9.6, 8.8, 9.6, 4); // .group-label padding: 0.55rem 0.6rem 0.25rem
const _searchPaddingX = 9.6; // .search padding: 0 0.6rem
const _searchGap = 7.2; // .search gap: 0.45rem
const _searchFont = .92; // .search input font-size: 0.92em
const _caretWidth = 1.0; // the browser's text caret
const _emptyPadding = EdgeInsets.symmetric(vertical: 12, horizontal: 9.6); // .empty padding: 0.75rem 0.6rem
const _emptyFont = .9; // .empty font-size: 0.9em
const _boxMark = .72; // .box svg width / height: 72%
const _entrySlide = 4.0; // @keyframes kakao-select-in: translateY(-4px), 4px when opened above
const _statusDelay = Duration(milliseconds: 400); // _announce: setTimeout(…, 400)

/// Flutter twin of `<kakao-select>`: a field that picks one value from a
/// list with a search field on top, or several with [multiple].
///
/// The field, as select.js draws it from the `--kakao-select-*` settings:
/// [label] above (a tap on it focuses the field), [hint] below, or [error]
/// instead (danger border and ring, invalid in semantics); the [placeholder]
/// in the muted colour while nothing is selected; the selected label (with
/// "+N" for more in a multiple select) and a chevron that turns over while
/// the panel is open. Sizes 36 / 44 / 52 px. The border takes the focus
/// colour while open or keyboard-focused; keyboard focus adds the 2 px
/// outline, 2 px away. [disabled] dims the whole field to
/// `disabled-opacity`. The field fills the width it gets.
///
/// The panel: below the field, `panel-offset` away, as wide as the field
/// (at least `panel-min-width`), at most `panel-height` and the room on its
/// side tall; above when there is no room below and more above (the side
/// is chosen when it opens, so filtering doesn't flip it); lined up with the
/// field's right edge when it would run off the right. It fades in from
/// 4 px back over `duration` and closes at once; with reduced motion it
/// appears at once. It starts on the selected option.
///
/// Keys on the field: Enter, Space, Up, Down (also with Alt) open it; a
/// letter opens it with the letter in the search; Delete / Backspace clear
/// the selection. In the panel: typing filters (case and accents ignored,
/// anywhere in the label; groups without matches hide; [emptyText] when
/// nothing matches), Up / Down / Page Up / Page Down move over the shown
/// enabled options, Enter picks, Alt+Up and Escape close with focus back on
/// the field, Tab closes and moves on from the field. A pointer down
/// outside closes it (focus stays where it went).
///
/// A single select closes on a pick and shows a check mark (and weight 600)
/// on the selected option. A multiple select shows a checkbox per row,
/// stays open, and has a "Select all" row on top that acts on the shown
/// options (checked, mixed or unchecked; "Select all N matches" while
/// filtering).
///
/// [values] is the selection the field starts with; it keeps the user's
/// picks from then on and takes a new [values] from its owner, without
/// reporting it (setting `value` from script fires no events).
class KakaoSelect extends StatefulWidget {
  const KakaoSelect({
    super.key,
    required this.options,
    this.values = const [],
    this.multiple = false,
    this.onChanged,
    this.label,
    this.semanticLabel,
    this.hint,
    this.error,
    this.placeholder,
    this.searchPlaceholder,
    this.emptyText,
    this.size = KakaoSelectSize.md,
    this.disabled = false,
    this.controller,
    this.onOpenChanged,
    this.focusNode,
    this.panelKey,
  });

  /// `list-data`: options and groups.
  final List<KakaoSelectEntry> options;

  /// `values`: the selected values (a single select uses the first).
  final List<String> values;

  /// `multiple`.
  final bool multiple;

  /// `select-change`.
  final ValueChanged<KakaoSelectChange>? onChanged;

  /// `label`: shown above the field.
  final String? label;

  /// `aria-label`: the accessible name when there is no [label].
  final String? semanticLabel;

  /// `hint`: below the field, hidden while there is an [error].
  final String? hint;

  /// `error`: below the field, danger border, invalid.
  final String? error;

  /// `placeholder`; default [texts]`.placeholder`.
  final String? placeholder;

  /// `search-placeholder`; default [texts]`.search`.
  final String? searchPlaceholder;

  /// `empty-text`; default [texts]`.empty`.
  final String? emptyText;
  final KakaoSelectSize size;

  /// `disabled`: dimmed, not focusable, does not open.
  final bool disabled;

  /// Opens and closes the panel from outside.
  final KakaoSelectController? controller;

  /// `select-open` (true) and `select-close` (false).
  final ValueChanged<bool>? onOpenChanged;

  /// The field's focus (`focus()`, `blur()`).
  final FocusNode? focusNode;

  /// Put on the open panel (tests, screenshots).
  final Key? panelKey;

  /// `KakaoSelect.texts`: select.js's built-in English texts.
  static ({
    String placeholder,
    String search,
    String empty,
    String name,
    String nothing,
    String selectAll,
    String Function(int n) selectAllMatches,
    String Function(int n) matches,
  })
  texts = (
    placeholder: 'Please select',
    search: 'Search',
    empty: 'No matches',
    name: 'Select',
    nothing: 'nothing selected',
    selectAll: 'Select all',
    selectAllMatches: (n) => 'Select all $n ${n == 1 ? 'match' : 'matches'}',
    matches: (n) => '$n ${n == 1 ? 'option' : 'options'}',
  );

  @override
  State<KakaoSelect> createState() => _KakaoSelectState();
}

/// An option flattened out of the entries (select.js `_items`).
class _Item {
  const _Item(this.option, this.disabled, this.group, this.key);
  final KakaoSelectOption option;
  final bool disabled;

  /// The index of its group in the entries, or null.
  final int? group;

  /// The folded label, for matching.
  final String key;

  String get value => option.value;
  String get label => option.label;
}

List<_Item> _flatten(List<KakaoSelectEntry> entries) => [
  for (var e = 0; e < entries.length; e++)
    ...switch (entries[e]) {
      final KakaoSelectOption o => [_Item(o, o.disabled, null, kakaoFold(o.label))],
      final KakaoSelectGroup g => [
        for (final o in g.options) _Item(o, o.disabled || g.disabled, e, kakaoFold(o.label)),
      ],
    },
];

const _foldFrom = 'àáâãäåāăąçćĉċčďèéêëēĕėęěĝğġģĥìíîïĩīĭįĵķĺļľñńņňòóôõöōŏőŕŗřśŝşšţťùúûüũūŭůűųŵýÿŷźżž';
const _foldTo = 'aaaaaaaaacccccdeeeeeeeeegggghiiiiiiiijklllnnnnoooooooorrrssssttuuuuuuuuuuwyyyzzz';

/// select.js `fold`: lower case without accents (NFD, combining marks
/// dropped), for matching.
@visibleForTesting
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

class _KakaoSelectState extends State<KakaoSelect> {
  KakaoSelectController? _own;
  KakaoSelectController get _ctl => widget.controller ?? (_own ??= KakaoSelectController());
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'KakaoSelect'));
  final _searchFocus = FocusNode(debugLabel: 'KakaoSelect search');

  late List<_Item> _items = _flatten(widget.options);
  late List<String> _sel = _clean(widget.values);
  bool _open = false;
  bool _focusVisible = false;

  /// The letter the panel opens with in its search.
  String _initial = '';

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(_openChanged);
  }

  @override
  void didUpdateWidget(KakaoSelect old) {
    super.didUpdateWidget(old);
    final before = old.controller ?? _own;
    if (before != _ctl) {
      before?.removeListener(_openChanged);
      _ctl.addListener(_openChanged);
    }
    if (!identical(old.options, widget.options)) _items = _flatten(widget.options);
    if (!listEquals(old.values, widget.values)) {
      _sel = _clean(widget.values);
    } else if (!identical(old.options, widget.options) || old.multiple != widget.multiple) {
      _sel = _clean(_sel);
    }
  }

  @override
  void dispose() {
    (widget.controller ?? _own)?.removeListener(_openChanged);
    _own?.dispose();
    _ownFocus?.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// select.js `_cleanSel`: unknown values dropped (kept while there are no
  /// options), no doubles, one at most in a single select.
  List<String> _clean(List<String> values) {
    var next = [...LinkedHashSet<String>.of(values)];
    if (_items.isNotEmpty) {
      final known = {for (final it in _items) it.value};
      next = next.where(known.contains).toList();
    }
    return widget.multiple ? next : next.take(1).toList();
  }

  List<_Item> get _chosen {
    final set = _sel.toSet();
    return [
      for (final it in _items)
        if (set.contains(it.value)) it,
    ];
  }

  void _openChanged() {
    final open = _ctl.isOpen;
    if (!mounted || open == _open) return;
    if (open && widget.disabled) return; // the panel closes it again
    if (!open) _initial = '';
    setState(() => _open = open);
    widget.onOpenChanged?.call(open);
  }

  void _openWith(String initial) {
    if (widget.disabled || _ctl.isOpen) return;
    _initial = initial;
    _ctl.open();
  }

  void _close({required bool returnFocus}) {
    _ctl.close();
    if (returnFocus) _focus.requestFocus();
  }

  void _toggle() {
    if (widget.disabled) return;
    if (_ctl.isOpen) {
      _close(returnFocus: true);
    } else {
      _focus.requestFocus();
      _openWith('');
    }
  }

  void _commit(List<String> next) {
    final previous = _sel;
    setState(() => _sel = next);
    widget.onChanged?.call(KakaoSelectChange._(List.unmodifiable(next), List.unmodifiable(previous)));
  }

  List<String> _ordered(Iterable<String> values) {
    final set = values.toSet();
    return [
      for (final it in _items)
        if (set.contains(it.value)) it.value,
    ];
  }

  void _pick(int item) {
    final it = _items[item];
    if (it.disabled) return;
    if (widget.multiple) {
      final next = _sel.contains(it.value) ? _sel.where((v) => v != it.value) : [..._sel, it.value];
      _commit(_ordered(next));
    } else {
      _close(returnFocus: true);
      if (_sel.isEmpty || _sel.first != it.value) _commit([it.value]);
    }
  }

  /// select.js `_toggleAll`: all or none of the shown enabled options.
  void _toggleAll(List<String> shown) {
    if (shown.isEmpty) return;
    final allOn = shown.every(_sel.contains);
    final next = allOn ? _sel.where((v) => !shown.contains(v)) : [..._sel, ...shown.where((v) => !_sel.contains(v))];
    _commit(_ordered(next));
  }

  void _tab({required bool back}) {
    // Back on the field first, so focus moves on from where the select sits.
    _close(returnFocus: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => back ? _focus.previousFocus() : _focus.nextFocus());
  }

  /// select.js `_onTriggerKey`, on the closed field.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (widget.disabled || _ctl.isOpen) return KeyEventResult.ignored;
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowUp) {
      _openWith('');
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) {
      if (_sel.isNotEmpty) _commit(const []);
      return KeyEventResult.handled;
    }
    final keys = HardwareKeyboard.instance;
    final c = e.character;
    if (c != null &&
        c.runes.length == 1 &&
        c.runes.first >= 0x20 &&
        c.runes.first != 0x7f &&
        !keys.isControlPressed &&
        !keys.isMetaPressed &&
        !keys.isAltPressed) {
      _openWith(c);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoSelectSettings.of(theme.colors);
    final (height, paddingX, fontSize) = switch (widget.size) {
      KakaoSelectSize.sm => (_smSize.height, _smSize.paddingX, _smSize.font),
      KakaoSelectSize.md => (st.height, st.paddingX, st.font.size),
      KakaoSelectSize.lg => (_lgSize.height, _lgSize.paddingX, _lgSize.font),
    };
    final reduce = _reduceMotion;
    final error = widget.error?.isNotEmpty ?? false ? widget.error : null;
    final hint = widget.hint?.isNotEmpty ?? false ? widget.hint : null;
    final name = widget.label ?? widget.semanticLabel ?? KakaoSelect.texts.name;
    final chosen = _chosen;
    final empty = chosen.isEmpty;
    final text = theme.text(size: fontSize, color: st.text, height: st.font.lineHeight);

    // .text: the current label (or the placeholder, muted) and "+N".
    final current = Text(
      empty ? widget.placeholder ?? KakaoSelect.texts.placeholder : chosen.first.label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: empty ? text.copyWith(color: st.muted) : text,
    );
    final chevron = st.chevronSize.of(fontSize);
    final content = Row(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: current),
              if (chosen.length > 1) ...[
                SizedBox(width: _moreGap * fontSize),
                Text(
                  '+${chosen.length - 1}',
                  style: theme.text(size: fontSize, color: st.muted, height: st.font.lineHeight, tabular: true),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: paddingX * _triggerGap),
        AnimatedRotation(
          turns: _open ? .5 : 0,
          duration: reduce ? Duration.zero : _chevronTurn,
          curve: st.ease,
          child: CustomPaint(size: Size.square(chevron), painter: _ChevronPainter(st.muted)),
        ),
      ],
    );

    Widget trigger = _FieldBox(
      height: height,
      paddingX: paddingX,
      radius: st.radius,
      background: st.bg,
      // :host([error]) wins over focus and open.
      border: error != null
          ? st.danger
          : _open || _focusVisible
          ? st.focus
          : st.border,
      ring: _focusVisible ? (error != null ? st.danger : st.focus) : null,
      ringWidth: st.focusWidth,
      ringOffset: st.focusOffset,
      duration: reduce ? Duration.zero : st.duration,
      curve: st.ease,
      child: content,
    );

    final spoken = empty ? KakaoSelect.texts.nothing : chosen.map((c) => c.label).join(', ');
    trigger = Semantics(
      button: true,
      enabled: !widget.disabled,
      expanded: _open,
      focusable: !widget.disabled,
      focused: _focus.hasFocus,
      label: '$name, $spoken',
      hint: error ?? hint,
      validationResult: error != null ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
      onTap: widget.disabled ? null : _toggle,
      excludeSemantics: true,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _onKey,
        child: FocusableActionDetector(
          focusNode: _focus,
          enabled: !widget.disabled,
          mouseCursor: widget.disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
          onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.disabled ? null : _toggle,
            child: trigger,
          ),
        ),
      ),
    );

    final field = KakaoAnchoredPanel(
      controller: _ctl,
      enabled: !widget.disabled,
      // select.js _place: below, panel-offset away, from the field's left
      // edge (its right edge without room, else pushed 8 px inside); above
      // when there is no room below and more above, chosen on open; as wide
      // as the field or panel-min-width; capped by max(120, room).
      placement: KakaoPanelPlacement(
        side: KakaoPanelSide.bottom,
        align: KakaoPanelAlign.start,
        offset: st.panelOffset,
        flip: KakaoPanelFlip.towardMoreRoom,
        capToRoom: true,
        keepSide: true,
        matchAnchorWidth: true,
        minWidth: st.panelMinWidth,
      ),
      motion: KakaoPanelMotion(duration: st.duration, curve: st.ease, slide: _entrySlide),
      // Focus goes back to the field on a pick, Escape and Tab, not after a
      // pointer down outside (select.js close(false)).
      returnFocus: false,
      onDismiss: (why) {
        if (why == KakaoPanelDismiss.escape) {
          _focus.requestFocus();
        } else if (_searchFocus.hasFocus) {
          // Flutter would hand focus back to the field when the search goes;
          // the web leaves it where the pointer went.
          _searchFocus.unfocus();
        }
      },
      panelBuilder: (context, side) => _SelectPanel(
        key: widget.panelKey,
        entries: widget.options,
        items: _items,
        selected: _sel.toSet(),
        multiple: widget.multiple,
        initial: _initial,
        searchFocus: _searchFocus,
        name: name,
        searchPlaceholder: widget.searchPlaceholder ?? KakaoSelect.texts.search,
        emptyText: widget.emptyText ?? KakaoSelect.texts.empty,
        onPick: _pick,
        onToggleAll: _toggleAll,
        onClose: () => _close(returnFocus: true),
        onTab: (back) => _tab(back: back),
        onFocusLost: () {
          if (_ctl.isOpen) _close(returnFocus: false);
        },
      ),
      child: trigger,
    );

    return _Field(
      label: widget.label,
      message: error ?? hint,
      messageColor: error != null ? st.danger : st.muted,
      labelStyle: theme.text(size: _labelSize, weight: st.labelWeight, color: st.text, height: st.font.lineHeight),
      messageStyle: theme.text(size: _messageSize, height: st.font.lineHeight),
      labelGap: st.labelGap,
      messageGap: st.messageGap,
      disabledOpacity: widget.disabled ? st.disabledOpacity : null,
      onLabelTap: widget.disabled ? null : _focus.requestFocus,
      child: field,
    );
  }
}

/// The field chrome around the trigger, as select.js draws it (`.label`,
/// `.hint`, `.error`, `:host([disabled])`): the label above, the hint or
/// error below, the whole dimmed when disabled. The text input's field
/// (ROADMAP step 2, "field chrome") is the same; this and [_FieldBox] move
/// to `lib/src/internal/` with it.
class _Field extends StatelessWidget {
  const _Field({
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
  final String? message;
  final Color messageColor;
  final TextStyle labelStyle;
  final TextStyle messageStyle;
  final double labelGap;
  final double messageGap;

  /// Not null: disabled, at this opacity.
  final double? disabledOpacity;
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
            // The trigger's accessible name carries the label.
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
            // aria-describedby: the trigger's semantics hint carries it.
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

/// The bordered field box (`.trigger`): min height, side padding, 1 px
/// border fading between colours, and the keyboard focus outline [ring]
/// [ringWidth] wide, [ringOffset] outside the border.
class _FieldBox extends StatelessWidget {
  const _FieldBox({
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
    return _Ring(color: ring, width: ringWidth, offset: ringOffset, radius: radius, child: box);
  }
}

/// A CSS `outline`: [width] wide, [offset] outside [child], following its
/// corner [radius]. Nothing when [color] is null.
class _Ring extends StatelessWidget {
  const _Ring({
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

/// The open panel (`.panel`): the search field, the "Select all" row of a
/// multiple select, the options on the shared option list, the empty text
/// and the polite status.
class _SelectPanel extends StatefulWidget {
  const _SelectPanel({
    super.key,
    required this.entries,
    required this.items,
    required this.selected,
    required this.multiple,
    required this.initial,
    required this.searchFocus,
    required this.name,
    required this.searchPlaceholder,
    required this.emptyText,
    required this.onPick,
    required this.onToggleAll,
    required this.onClose,
    required this.onTab,
    required this.onFocusLost,
  });

  final List<KakaoSelectEntry> entries;
  final List<_Item> items;
  final Set<String> selected;
  final bool multiple;
  final String initial;

  /// The search field's focus, kept by the select across openings.
  final FocusNode searchFocus;
  final String name;
  final String searchPlaceholder;
  final String emptyText;
  final ValueChanged<int> onPick;
  final ValueChanged<List<String>> onToggleAll;
  final VoidCallback onClose;
  final ValueChanged<bool> onTab;
  final VoidCallback onFocusLost;

  @override
  State<_SelectPanel> createState() => _SelectPanelState();
}

/// [_SelectPanel]'s shown rows: option list entries and, per row, its item.
typedef _Shown = ({List<KakaoOptionEntry> entries, List<int> rows});

class _SelectPanelState extends State<_SelectPanel> {
  late final _query = TextEditingController(text: widget.initial);
  late final _search = widget.searchFocus;
  final _list = KakaoOptionListController();

  /// "Select all" is the active row (select.js `_active === 'all'`).
  bool _allActive = false;
  String _status = '';
  Timer? _statusTimer;

  /// The search has had focus: losing it now closes the panel.
  bool _ready = false;

  String get _q => kakaoFold(_query.text.trim());

  @override
  void initState() {
    super.initState();
    _search.onKeyEvent = _onKey;
    _search.addListener(_focusChanged);
    _list.addListener(_listChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ready = true;
      _search.requestFocus();
      _resetActive();
      // select.js _open: start on the first selected option when it is shown.
      if (widget.initial.isEmpty) {
        final rows = _shown().rows;
        for (var r = 0; r < rows.length; r++) {
          final it = widget.items[rows[r]];
          if (!it.disabled && widget.selected.contains(it.value)) {
            _activate(r);
            break;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _search.removeListener(_focusChanged);
    _list.removeListener(_listChanged);
    _search.onKeyEvent = null;
    _query.dispose();
    _list.dispose();
    super.dispose();
  }

  void _focusChanged() {
    // select.js focusout: focus moved to something outside the select. Not
    // when it went nowhere (the text input connection closing, a window
    // blur): the field would come back focused, the panel gone.
    if (!_ready || _search.hasFocus) return;
    final now = FocusManager.instance.primaryFocus;
    if (now != null && now is! FocusScopeNode) widget.onFocusLost();
  }

  void _listChanged() {
    if (_list.highlighted != null && _allActive) setState(() => _allActive = false);
  }

  _Shown _shown() {
    final q = _q;
    final items = widget.items;
    final rows = <int>[];
    final entries = <KakaoOptionEntry>[];
    KakaoOption option(int i) {
      rows.add(i);
      final it = items[i];
      return KakaoOption(label: it.label, disabled: it.disabled, checked: widget.selected.contains(it.value));
    }

    var i = 0;
    for (final e in widget.entries) {
      switch (e) {
        case KakaoSelectOption():
          if (q.isEmpty || items[i].key.contains(q)) entries.add(option(i));
          i++;
        case KakaoSelectGroup():
          final options = <KakaoOption>[];
          for (var n = 0; n < e.options.length; n++, i++) {
            if (q.isEmpty || items[i].key.contains(q)) options.add(option(i));
          }
          // Groups without (matching) options hide.
          if (options.isNotEmpty) entries.add(KakaoOptionGroup(options, label: e.label));
      }
    }
    return (entries: entries, rows: rows);
  }

  /// The shown enabled options (select.js `_shownEnabled`).
  List<String> _shownEnabled(List<int> rows) => [
    for (final i in rows)
      if (!widget.items[i].disabled) widget.items[i].value,
  ];

  /// The keys the arrows reach, in order: -1 for "Select all", else rows.
  List<int> _nav() {
    final rows = _shown().rows;
    return [
      if (widget.multiple && _shownEnabled(rows).isNotEmpty) -1,
      for (var r = 0; r < rows.length; r++)
        if (!widget.items[rows[r]].disabled) r,
    ];
  }

  void _activate(int key, {bool keyboard = true}) {
    if (key == -1) {
      setState(() => _allActive = true);
      _list.highlight(null);
    } else {
      _allActive = false;
      _list.highlight(key, keyboard: keyboard);
    }
  }

  /// select.js `_filter(false)`: after the text changed, the first shown
  /// option is active (else "Select all", else none).
  void _filter() {
    setState(() {});
    // After the list took the new rows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resetActive();
    });
    final shown = _shown().rows.length;
    final text = _q.isEmpty
        ? ''
        : shown > 0
        ? KakaoSelect.texts.matches(shown)
        : widget.emptyText;
    _statusTimer?.cancel();
    _statusTimer = Timer(_statusDelay, () {
      if (mounted) setState(() => _status = text);
    });
  }

  void _resetActive() {
    final nav = _nav();
    final first = nav.where((k) => k != -1);
    if (first.isNotEmpty) {
      _activate(first.first);
    } else if (nav.isNotEmpty) {
      _activate(nav.first);
    } else {
      setState(() => _allActive = false);
      _list.highlight(null);
    }
  }

  /// select.js `_move`: clamped at both ends.
  void _move(int delta) {
    final nav = _nav();
    if (nav.isEmpty) return;
    final current = _allActive ? -1 : _list.highlighted;
    var i = current == null ? -1 : nav.indexOf(current);
    if (i == -1) i = delta > 0 ? -1 : nav.length;
    _activate(nav[(i + delta).clamp(0, nav.length - 1)]);
  }

  void _pickRow(int row) {
    final rows = _shown().rows;
    if (row < 0 || row >= rows.length) return;
    widget.onPick(rows[row]);
  }

  void _toggleAll() => widget.onToggleAll(_shownEnabled(_shown().rows));

  /// select.js `_onSearchKey`.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final keys = HardwareKeyboard.instance;
    if (k == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      keys.isAltPressed ? widget.onClose() : _move(-1);
    } else if (k == LogicalKeyboardKey.pageDown) {
      _move(_pageStep);
    } else if (k == LogicalKeyboardKey.pageUp) {
      _move(-_pageStep);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (e is KeyDownEvent) {
        if (_allActive) {
          _toggleAll();
        } else if (_list.highlighted case final row?) {
          _pickRow(row);
        }
      }
    } else if (k == LogicalKeyboardKey.escape) {
      // The panel closes on Escape itself (the newest open panel only); the
      // text field's own Escape handling must not see it.
    } else if (k == LogicalKeyboardKey.tab) {
      if (e is KeyDownEvent) widget.onTab(keys.isShiftPressed);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoSelectSettings.of(theme.colors);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final size = st.font.size;
    final text = theme.text(size: size, color: st.text, height: _rowLineHeight);
    final duration = reduce ? Duration.zero : st.duration;
    final multiple = widget.multiple;
    Widget box(bool? on) => _Box(state: on, settings: st, duration: duration);

    final style = KakaoOptionListStyle(
      text: text,
      rowMinHeight: st.optionHeight,
      rowPadding: _rowPadding,
      rowRadius: st.optionRadius,
      gap: _rowGap,
      trailingGap: 0,
      leadSize: multiple ? st.boxSize : _checkSize * size,
      highlight: st.hoverBg,
      check: st.check,
      icon: st.muted,
      heading: theme.text(size: _headingSize, weight: _headingWeight, color: st.muted, height: st.font.lineHeight),
      headingPadding: _headingPadding,
      separator: st.line,
      separatorMargin: 0,
      // The panel's padding is around everything, search included.
      padding: EdgeInsets.zero,
      duration: st.duration,
      curve: st.ease,
      // A multiple select's rows keep their weight.
      checkedWeight: multiple ? null : _selectedWeight,
      disabledColor: st.muted,
      checkBuilder: multiple ? box : null,
    );

    final shown = _shown();
    final enabled = _shownEnabled(shown.rows);
    final filtering = _query.text.trim().isNotEmpty;

    Widget? all;
    if (multiple && enabled.isNotEmpty) {
      final on = enabled.where(widget.selected.contains).length;
      final bool? state = on == 0
          ? false
          : on == enabled.length
          ? true
          : null;
      all = _AllRow(
        label: filtering ? KakaoSelect.texts.selectAllMatches(enabled.length) : KakaoSelect.texts.selectAll,
        state: state,
        active: _allActive,
        box: box(state),
        settings: st,
        text: text,
        duration: duration,
        onHover: () {
          if (!_allActive) _activate(-1, keyboard: false);
        },
        onTap: () {
          _activate(-1, keyboard: false);
          _toggleAll();
        },
      );
    }

    final search = _SearchField(
      controller: _query,
      focusNode: _search,
      settings: st,
      placeholder: widget.searchPlaceholder,
      label: '${KakaoSelect.texts.search} ${widget.name}',
      onChanged: (_) => _filter(),
    );

    return ConstrainedBox(
      // max-height: min(panel-height, room); the room is the anchored panel's.
      constraints: BoxConstraints(maxHeight: st.panelHeight),
      child: Container(
        padding: EdgeInsets.all(st.panelPadding),
        decoration: BoxDecoration(
          color: st.panelBg,
          borderRadius: BorderRadius.circular(st.panelRadius),
          boxShadow: st.panelShadow,
        ),
        child: DefaultTextStyle(
          style: theme.text(size: size, color: st.text, height: st.font.lineHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: st.panelPadding),
                child: search,
              ),
              ?all,
              Flexible(
                child: KakaoOptionList(
                  entries: shown.entries,
                  style: style,
                  controller: _list,
                  onActivate: _pickRow,
                  semanticsRole: SemanticsRole.list,
                  semanticsLabel: widget.name,
                ),
              ),
              if (shown.rows.isEmpty)
                Padding(
                  padding: _emptyPadding,
                  child: Text(
                    widget.emptyText,
                    textAlign: TextAlign.center,
                    style: theme.text(size: size * _emptyFont, color: st.muted, height: st.font.lineHeight),
                  ),
                ),
              Semantics(liveRegion: true, label: _status, child: const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.search`: the search icon and a text field in a small bordered box; it
/// always has keyboard focus while shown, so it shows the focus border and
/// outline (an input matches `:focus-visible` whenever focused).
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.settings,
    required this.placeholder,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final KakaoSelectSettings settings;
  final String placeholder;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_changed);
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_changed);
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = widget.settings;
    final size = st.font.size;
    final focused = widget.focusNode.hasFocus;
    final style = theme.text(size: size * _searchFont, color: st.text, height: st.font.lineHeight);
    final field = Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        if (widget.controller.text.isEmpty)
          ExcludeSemantics(
            child: Text(widget.placeholder, maxLines: 1, style: style.copyWith(color: st.muted)),
          ),
        Semantics(
          label: widget.label,
          hint: widget.placeholder,
          child: EditableText(
            controller: widget.controller,
            focusNode: widget.focusNode,
            style: style,
            cursorColor: st.text,
            cursorWidth: _caretWidth,
            backgroundCursorColor: st.muted,
            selectionColor: st.focus.withValues(alpha: .25),
            maxLines: 1,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            // Taps in the panel leave focus here (select.js prevents the mousedown).
            onTapOutside: (_) {},
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );
    return _Ring(
      color: focused ? st.focus : null,
      width: st.focusWidth,
      offset: st.focusOffset,
      radius: st.optionRadius,
      child: Container(
        height: st.searchHeight,
        padding: const EdgeInsets.symmetric(horizontal: _searchPaddingX),
        decoration: BoxDecoration(
          color: st.bg,
          border: Border.all(color: focused ? st.focus : st.border),
          borderRadius: BorderRadius.circular(st.optionRadius),
        ),
        child: Row(
          children: [
            CustomPaint(size: Size.square(size), painter: _SearchPainter(st.muted)),
            const SizedBox(width: _searchGap),
            Expanded(child: field),
          ],
        ),
      ),
    );
  }
}

/// `.row.all`: "Select all" with a tri-state box, on top of the list
/// (sticky on the web), with a line below it.
class _AllRow extends StatelessWidget {
  const _AllRow({
    required this.label,
    required this.state,
    required this.active,
    required this.box,
    required this.settings,
    required this.text,
    required this.duration,
    required this.onHover,
    required this.onTap,
  });

  final String label;
  final bool? state;
  final bool active;
  final Widget box;
  final KakaoSelectSettings settings;
  final TextStyle text;
  final Duration duration;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st = settings;
    final r = Radius.circular(st.optionRadius);
    return Semantics(
      container: true,
      checked: state ?? false,
      mixed: state == null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: (_) => onHover(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            // margin-bottom: 1px, under the line.
            padding: const EdgeInsets.only(bottom: 1),
            child: AnimatedContainer(
              duration: duration,
              curve: st.ease,
              constraints: BoxConstraints(minHeight: st.optionHeight),
              padding: _rowPadding,
              alignment: AlignmentDirectional.centerStart,
              decoration: BoxDecoration(
                color: active ? st.hoverBg : st.panelBg,
                borderRadius: BorderRadius.only(topLeft: r, topRight: r),
                // box-shadow: 0 1px 0 var(--_line).
                boxShadow: [BoxShadow(color: st.line, offset: const Offset(0, 1))],
              ),
              child: Row(
                children: [
                  box,
                  const SizedBox(width: _rowGap),
                  Expanded(child: Text(label, style: text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.box`: the checkbox look of a multiple select's rows; [state] null is
/// mixed (the dash).
class _Box extends StatelessWidget {
  const _Box({required this.state, required this.settings, required this.duration});

  final bool? state;
  final KakaoSelectSettings settings;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final st = settings;
    final on = state != false;
    final inner = st.boxSize - 2;
    return AnimatedContainer(
      duration: duration,
      curve: st.ease,
      width: st.boxSize,
      height: st.boxSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? st.boxCheckedBg : st.boxBg,
        border: Border.all(color: on ? st.boxCheckedBg : st.boxBorder),
        borderRadius: BorderRadius.circular(st.boxRadius),
      ),
      child: on
          ? CustomPaint(
              size: Size.square(inner * _boxMark),
              painter: _MarkPainter(st.mark, dash: state == null),
            )
          : null,
    );
  }
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// select.js CHEVRON: `M6 9l6 6 6-6` in a 24 box, stroke 2.4, round.
class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.drawPath(
      Path()
        ..moveTo(6 * k, 9 * k)
        ..lineTo(12 * k, 15 * k)
        ..lineTo(18 * k, 9 * k),
      _stroke(color, 2.4 * k),
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}

/// select.js SEARCH: a circle r 6.5 at 11,11 and `M16 16l4.5 4.5`, stroke
/// 2.2, round caps.
class _SearchPainter extends CustomPainter {
  const _SearchPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = _stroke(color, 2.2 * k);
    canvas.drawCircle(Offset(11 * k, 11 * k), 6.5 * k, paint);
    canvas.drawLine(Offset(16 * k, 16 * k), Offset(20.5 * k, 20.5 * k), paint);
  }

  @override
  bool shouldRepaint(_SearchPainter old) => old.color != color;
}

/// select.js BOX: the tick `M5 12.5l4.5 4.5L19 7.5` or the dash `M6 12h12`,
/// stroke 3.2, round.
class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color, {required this.dash});
  final Color color;
  final bool dash;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = _stroke(color, 3.2 * k);
    if (dash) {
      canvas.drawLine(Offset(6 * k, 12 * k), Offset(18 * k, 12 * k), paint);
      return;
    }
    canvas.drawPath(
      Path()
        ..moveTo(5 * k, 12.5 * k)
        ..lineTo(9.5 * k, 17 * k)
        ..lineTo(19 * k, 7.5 * k),
      paint,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color || old.dash != dash;
}
