import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_field.dart';
import '../internal/kakao_option_list.dart';
import '../settings/kakao_command_palette_settings.g.dart';
import '../theme/kakao_theme.dart';
import '../theme/kakao_values.dart';

/// A command of a [KakaoCommandPalette] (an entry of `list-data`; a plain
/// string there is `KakaoCommand(text)`).
@immutable
class KakaoCommand {
  const KakaoCommand(
    this.label, {
    this._id,
    this._value,
    this.group,
    this.keywords = const [],
    this.shortcut,
    this.icon,
    this.disabled = false,
  });

  /// The text that is searched and shown.
  final String label;
  final String? _id;
  final Object? _value;

  /// Reported in [KakaoCommandSelect] and kept for `recent`. Default: the
  /// value, else the label.
  String get id => _id ?? _value?.toString() ?? label;

  /// Reported in [KakaoCommandSelect]. Default: the id.
  Object get value => _value ?? id;

  /// The heading of the group the command is listed under; null or empty:
  /// listed without one.
  final String? group;

  /// More words that find the command (not shown).
  final List<String> keywords;

  /// A hint such as "Mod+S" at the end of the row. The palette does not bind it.
  final String? shortcut;

  /// Drawn before the label at the icon size, in the icon colour (an
  /// [Icon] takes both from the surrounding [IconTheme]).
  final Widget? icon;

  /// Listed dimmed, skipped by the keys, cannot be run.
  final bool disabled;
}

/// `command-select`: a command was run (after the palette closed).
@immutable
class KakaoCommandSelect {
  const KakaoCommandSelect._(this.command);

  final KakaoCommand command;
  String get id => command.id;
  Object get value => command.value;
}

/// Opens and closes a [KakaoCommandPalette] (`open(query?)`, `close()`,
/// `toggle()`, `isOpen`, `recentIds`). Listeners hear about opening and
/// closing.
class KakaoCommandPaletteController extends ChangeNotifier {
  _KakaoCommandPaletteState? _state;

  /// True while open (always for an inline palette).
  bool get isOpen => _state?._isOpen ?? false;

  /// Ids of the remembered commands, newest first.
  List<String> get recentIds => List.unmodifiable(_state?._recent ?? const <String>[]);

  /// Opens with [query] in the field (empty by default).
  void open([String query = '']) => _state?._open(query);
  void close() => _state?._close();
  void toggle() => isOpen ? close() : open();

  void _changed() => notifyListeners();
}

// command-palette.js values outside the settings block.
const _pageStep = 8; // PAGE_STEP
const _defaultHotkey = 'Mod+K'; // hotkey default
const _sideInset = 16.0; // .overlay padding: var(--_top) 1rem 1rem
const _phoneWidth = 640.0; // @media (max-width: 40rem)
const _entrySlide = 6.0; // @keyframes kakao-command-palette-in: translateY(-6px)
const _entryScale = .99; // … scale(.99)
const _rowPaddingY = 6.4; // .option padding: 0.4rem var(--_option-padding-x)
const _rowLineHeight = 1.3; // .option line-height: 1.3
const _headingPadding = (top: 8.8, bottom: 4.0); // .group-label padding: 0.55rem var(--_option-padding-x) 0.25rem
const _emptyPaddingY = 20.0; // .empty padding: 1.25rem var(--_input-padding-x)
const _emptyFont = .9; // .empty font-size: 0.9em
const _hintsPaddingY = 8.0; // .hints padding: 0.5rem var(--_input-padding-x)
const _hintsGap = (row: 5.6, column: 17.6); // .hints gap: 0.35rem 1.1rem
const _hintGap = 4.8; // .hint gap: 0.3rem
const _searchStroke = 1.6; // SEARCH svg stroke-width
const _selectionAlpha = .25; // the text selection: the focus colour, light (the browser's own on the web)

/// Flutter twin of `<kakao-command-palette>`: a search over the app's
/// actions, opened with a hotkey (Mod+K by default): type a few letters,
/// pick a command with the arrows, run it with Enter.
///
/// Put it anywhere in the tree (usually around the page, as [child], which
/// it shows unchanged). Modal like the dialog: it opens on the root
/// navigator over a scrim (`scrim`, fading in over `duration` / `ease`), the
/// page is out of reach, focus sits in the search field and goes back
/// where it was when it closes. The panel (`bg`, `radius`, `shadow`) is
/// `width` wide at most, `top` from the top, at most `max-height` tall, and
/// fades in while it drops 6 px and grows from 99 %; it closes at once, and
/// appears at once with reduced motion. Below 640 px of screen width it is
/// a full-width sheet at the top (`sheet-max-height`, bottom corners round).
///
/// Opens on [hotkey] (anywhere in the app while this widget is mounted, as
/// the web one listens on the document; "Mod" is Command on Apple
/// platforms and Ctrl elsewhere; null, "" or "none": no hotkey; a key
/// without Ctrl, Meta or Alt does nothing while a text field has focus) and
/// on [KakaoCommandPaletteController.open]; closes on the hotkey, Escape, a
/// tap on the scrim and [KakaoCommandPaletteController.close].
///
/// The panel: the search row (a magnifier, the field, a line below that
/// takes the focus colour and `focus-width`), the results, and a row of
/// key hints (not with [noHints], not on touch platforms). Results stay
/// grouped under their [KakaoCommand.group] headings; a row shows the
/// command's icon (the column is kept for every row once any command has
/// one), its label and its shortcut (`shortcut-size`, muted,
/// `shortcut-gap` away). Rows are `option-height` tall
/// (`touch-option-height` on touch platforms); the active row has the
/// `hover-bg` background. [emptyText] shows when nothing matches.
///
/// Search: case and accents are ignored; every word of the query has to
/// match the label (as a piece of it, else its letters in order from the
/// start of a word, "nwf" finds "New file") or a keyword. Matched letters
/// take the `match` colour and `match-weight`. The group with the best
/// match comes first, the best command first in it. With [recent] the last
/// run commands are listed first under "Recent" while the query is empty
/// (in memory, for as long as this widget lives).
///
/// Keys in the field: Down / Up move (wrapping), Home / End to the first /
/// last, Page Down / Up eight on, disabled commands skipped; Enter runs the
/// active command; Tab stays in the field; Escape closes. The first result
/// is active after every change of the query. A pointer over a row makes it
/// active, a tap runs it. Running closes the palette, then calls
/// [onSelect].
///
/// [inline]: shown in place (as a preview), always open: no scrim, no
/// hotkey, no key hints; Escape clears the query, Tab moves on.
class KakaoCommandPalette extends StatefulWidget {
  const KakaoCommandPalette({
    super.key,
    required this.commands,
    this.controller,
    this.hotkey = _defaultHotkey,
    this.recent = 0,
    this.label,
    this.placeholder,
    this.emptyText,
    this.noHints = false,
    this.inline = false,
    this.onSelect,
    this.onOpen,
    this.onClose,
    this.panelKey,
    this.child,
  });

  final List<KakaoCommand> commands;
  final KakaoCommandPaletteController? controller;

  /// `hotkey`: "Mod+K", "Ctrl+Shift+P", "/", "F1"; null, "" or "none": none.
  final String? hotkey;

  /// `recent`: how many run commands to remember; 0: none (the web
  /// attribute without a number is 5).
  final int recent;

  /// Accessible name; default [texts]`.label`.
  final String? label;

  /// The field's placeholder; default [texts]`.placeholder`.
  final String? placeholder;

  /// `empty-text`; default [texts]`.empty`.
  final String? emptyText;

  /// `no-hints`: no key hint row.
  final bool noHints;

  /// `inline`: shown in place, always open.
  final bool inline;

  /// `command-select`.
  final ValueChanged<KakaoCommandSelect>? onSelect;

  /// `command-palette-open` / `command-palette-close`.
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  /// A key on the panel (for tests and the look-alike check).
  final Key? panelKey;

  /// Shown unchanged (not for [inline]).
  final Widget? child;

  /// `KakaoCommandPalette.texts`: command-palette.js's built-in English texts.
  static ({
    String label,
    String placeholder,
    String empty,
    String recent,
    String listbox,
    String Function(int n) count,
    String move,
    String run,
    String close,
  })
  texts = (
    label: 'Command palette',
    placeholder: 'Search commands…',
    empty: 'No matching commands',
    recent: 'Recent',
    listbox: 'Commands',
    count: (n) => n == 1 ? '1 command' : '$n commands',
    move: 'to move',
    run: 'to run',
    close: 'to close',
  );

  @override
  State<KakaoCommandPalette> createState() => _KakaoCommandPaletteState();
}

class _KakaoCommandPaletteState extends State<KakaoCommandPalette> {
  KakaoCommandPaletteController? _own;
  KakaoCommandPaletteController get _ctl => widget.controller ?? (_own ??= KakaoCommandPaletteController());

  final _rev = ValueNotifier<int>(0);
  List<String> _recent = [];
  _PaletteRoute? _route;
  String _query = '';
  FocusNode? _returnFocus;
  _Hotkey? _hotkey;

  bool get _isOpen => widget.inline || _route != null;

  @override
  void initState() {
    super.initState();
    _ctl._state = this;
    _hotkey = _Hotkey.parse(widget.hotkey);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didUpdateWidget(KakaoCommandPalette old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller!._state = null;
      _ctl._state = this;
    }
    if (old.hotkey != widget.hotkey) _hotkey = _Hotkey.parse(widget.hotkey);
    if (old.commands != widget.commands || old.recent != widget.recent) {
      final ids = {for (final c in widget.commands) c.id};
      _recent = _recent.where(ids.contains).take(widget.recent).toList();
    }
    if (widget.inline && !old.inline) _close();
    _rev.value++;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    final r = _route;
    _route = null;
    if (r != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (r.isActive) r.navigator?.removeRoute(r);
      });
    }
    if (_ctl._state == this) _ctl._state = null;
    _own?.dispose();
    _rev.dispose();
    super.dispose();
  }

  /// command-palette.js `_onDocKeydown`.
  bool _onKey(KeyEvent e) {
    final combo = _hotkey;
    if (combo == null || widget.inline || e is! KeyDownEvent || !mounted) return false;
    if (!combo.matches(e)) return false;
    if (!combo.ctrl && !combo.meta && !combo.alt && _route == null && _editing()) return false;
    _ctl.toggle();
    return true;
  }

  static bool _editing() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    return ctx != null && (ctx.widget is EditableText || ctx.findAncestorStateOfType<EditableTextState>() != null);
  }

  void _open(String query) {
    if (widget.inline || _route != null || !mounted) return;
    final theme = KakaoTheme.of(context);
    final st = KakaoCommandPaletteSettings.of(theme.colors);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _query = query;
    _returnFocus = FocusManager.instance.primaryFocus;
    final route = _PaletteRoute(
      scrim: st.scrim,
      curve: st.ease,
      duration: reduce ? Duration.zero : st.duration,
      label: widget.label ?? KakaoCommandPalette.texts.label,
      builder: (context) => ValueListenableBuilder<int>(valueListenable: _rev, builder: (context, _, _) => _view()),
    );
    _route = route;
    Navigator.of(context, rootNavigator: true).push(route).whenComplete(() {
      // Closed by the route itself (a tap on the scrim, the system back).
      if (_route == route) {
        _route = null;
        _closed();
      }
    });
    _ctl._changed();
    widget.onOpen?.call();
  }

  void _close() {
    final r = _route;
    if (r == null) return;
    _route = null;
    if (r.isCurrent) {
      r.navigator?.pop();
    } else if (r.isActive) {
      r.navigator?.removeRoute(r);
    }
    _closed();
  }

  void _closed() {
    // Focus goes back to where it was (command-palette.js `_returnFocus`).
    final back = _returnFocus;
    _returnFocus = null;
    if (back != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (back.context != null && back.canRequestFocus) back.requestFocus();
      });
    }
    _ctl._changed();
    if (mounted) widget.onClose?.call();
  }

  /// command-palette.js `_run`.
  void _run(KakaoCommand cmd) {
    if (cmd.disabled) return;
    final limit = widget.recent;
    if (limit > 0) {
      setState(() => _recent = [cmd.id, ..._recent.where((id) => id != cmd.id)].take(limit).toList());
    }
    if (!widget.inline) _close();
    widget.onSelect?.call(KakaoCommandSelect._(cmd));
  }

  Widget _view() => _PaletteView(
    key: widget.inline ? null : ValueKey(_route),
    commands: widget.commands,
    recent: widget.recent > 0 ? _recent : const [],
    label: widget.label ?? KakaoCommandPalette.texts.label,
    placeholder: widget.placeholder ?? KakaoCommandPalette.texts.placeholder,
    emptyText: widget.emptyText ?? KakaoCommandPalette.texts.empty,
    hints: !widget.noHints && !widget.inline,
    inline: widget.inline,
    initialQuery: widget.inline ? '' : _query,
    panelKey: widget.panelKey,
    onRun: _run,
    onClose: _close,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.inline) return _view();
    return widget.child ?? const SizedBox.shrink();
  }
}

/// The modal route: scrim, focus scope, no exit motion (the web palette
/// closes at once).
class _PaletteRoute extends PopupRoute<void> {
  _PaletteRoute({
    required this.scrim,
    required this.curve,
    required this.duration,
    required this.label,
    required this.builder,
  });

  final Color scrim;
  final Curve curve;
  final Duration duration;
  final String label;
  final WidgetBuilder builder;

  @override
  Color? get barrierColor => scrim;

  @override
  Curve get barrierCurve => curve;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => label;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      builder(context);
}

/// The panel and what it shows, modal or [inline].
class _PaletteView extends StatefulWidget {
  const _PaletteView({
    super.key,
    required this.commands,
    required this.recent,
    required this.label,
    required this.placeholder,
    required this.emptyText,
    required this.hints,
    required this.inline,
    required this.initialQuery,
    required this.panelKey,
    required this.onRun,
    required this.onClose,
  });

  final List<KakaoCommand> commands;
  final List<String> recent;
  final String label;
  final String placeholder;
  final String emptyText;
  final bool hints;
  final bool inline;
  final String initialQuery;
  final Key? panelKey;
  final ValueChanged<KakaoCommand> onRun;
  final VoidCallback onClose;

  @override
  State<_PaletteView> createState() => _PaletteViewState();
}

class _PaletteViewState extends State<_PaletteView> {
  late final _text = TextEditingController(text: widget.initialQuery)
    ..selection = TextSelection.collapsed(offset: widget.initialQuery.length);
  final _focus = FocusNode();
  final _list = KakaoOptionListController();
  final _group = Object();
  late List<_Command> _all = _prepareAll(widget.commands);
  String _query = '';

  /// A new list (scrolled to the top, first row active) for every query.
  int _rev = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _query = _text.text;
    _focus.addListener(_focusChanged);
    // The field gets focus when the palette opens.
    if (!widget.inline) _focus.requestFocus();
  }

  @override
  void didUpdateWidget(_PaletteView old) {
    super.didUpdateWidget(old);
    if (old.commands != widget.commands) {
      _all = _prepareAll(widget.commands);
      _rev++;
    } else if (!listEquals(old.recent, widget.recent)) {
      _rev++;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _list.dispose();
    super.dispose();
  }

  void _focusChanged() => setState(() {});

  static List<_Command> _prepareAll(List<KakaoCommand> commands) => [
    for (var i = 0; i < commands.length; i++) _Command(commands[i], i),
  ];

  void _onInput(String text) {
    if (text == _query) return;
    setState(() {
      _query = text;
      _rev++;
      final n = _results().rows.length;
      _status = KakaoCommandPalette.texts.count(n);
    });
  }

  ({List<_Group> groups, List<_Command> rows}) _results() =>
      _arrange(_all, _query, widget.recent, KakaoCommandPalette.texts.recent);

  void _activate(int index, List<_Command> rows) {
    if (index < 0 || index >= rows.length || rows[index].command.disabled) return;
    final cmd = rows[index].command;
    if (widget.inline) {
      _text.clear();
      setState(() {
        _query = '';
        _rev++;
      });
    }
    widget.onRun(cmd);
  }

  /// command-palette.js `_jump`: [count] enabled rows on, not wrapping.
  void _jump(int dir, int count) {
    final rows = _list.rows;
    var index = _list.highlighted ?? -1;
    for (var k = 0; k < count; k++) {
      var next = index + dir;
      while (next >= 0 && next < rows.length && rows[next].disabled) {
        next += dir;
      }
      if (next < 0 || next >= rows.length) break;
      index = next;
    }
    if (index >= 0) _list.highlight(index, keyboard: true);
  }

  /// command-palette.js `_onKeydown`, on the field.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_text.value.composing.isValid) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final keys = HardwareKeyboard.instance;
    if (k == LogicalKeyboardKey.escape) {
      if (e is! KeyDownEvent) return KeyEventResult.handled;
      if (widget.inline) {
        if (_text.text.isEmpty) return KeyEventResult.ignored;
        _text.clear();
        _onInput('');
        return KeyEventResult.handled;
      }
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.tab) {
      // The field is the only focus stop of the modal palette.
      return widget.inline ? KeyEventResult.ignored : KeyEventResult.handled;
    }
    if (keys.isAltPressed || keys.isControlPressed || keys.isMetaPressed) return KeyEventResult.ignored;
    if ((k == LogicalKeyboardKey.home || k == LogicalKeyboardKey.end) && keys.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (k == LogicalKeyboardKey.pageDown || k == LogicalKeyboardKey.pageUp) {
      _jump(k == LogicalKeyboardKey.pageDown ? 1 : -1, _pageStep);
      return KeyEventResult.handled;
    }
    return _list.handleKey(e, typeAhead: false, space: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoCommandPaletteSettings.of(theme.colors);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final touch = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => true,
      _ => false,
    };
    final phone = !widget.inline && MediaQuery.sizeOf(context).width < _phoneWidth;
    final fontSize = st.font.size;
    final results = _results();
    final rows = results.rows;
    final anyIcon = _all.any((c) => c.command.icon != null);
    final matchStyle = TextStyle(
      color: st.match,
      fontWeight: FontWeight.values[((st.matchWeight / 100).round() - 1).clamp(0, 8)],
      fontVariations: [FontVariation.weight(st.matchWeight)],
    );
    final shortcutStyle = theme.text(size: st.shortcutSize, color: st.muted, height: _rowLineHeight);

    KakaoOption option(_Hit hit) {
      final c = hit.command.command;
      return KakaoOption(
        label: c.label,
        disabled: c.disabled,
        // .list.has-lead: the icon column shows on every row once any command has an icon.
        leading: anyIcon ? (c.icon ?? const SizedBox.shrink()) : null,
        trailing: c.shortcut == null || c.shortcut!.isEmpty
            ? null
            : Text(c.shortcut!, style: shortcutStyle, softWrap: false),
        labelSpans: hit.marks.isEmpty ? null : _marked(hit.command, hit.marks, matchStyle),
      );
    }

    final entries = <KakaoOptionEntry>[
      for (final g in results.groups)
        if (g.heading.isEmpty)
          ...g.hits.map(option)
        else
          KakaoOptionGroup([for (final h in g.hits) option(h)], label: g.heading),
    ];
    final first = rows.indexWhere((r) => !r.command.disabled);

    final style = KakaoOptionListStyle(
      text: theme.text(size: fontSize, color: st.text, height: _rowLineHeight),
      // @media (pointer: coarse): touch-option-height.
      rowMinHeight: touch ? st.touchOptionHeight : st.optionHeight,
      rowPadding: EdgeInsets.symmetric(vertical: _rowPaddingY, horizontal: st.optionPaddingX),
      rowRadius: st.optionRadius,
      gap: st.gap,
      trailingGap: st.shortcutGap,
      leadSize: st.iconSize.of(fontSize),
      highlight: st.hoverBg,
      check: st.match,
      icon: st.icon,
      heading: theme.text(size: st.groupSize, weight: st.groupWeight, color: st.muted, height: st.font.lineHeight),
      headingPadding: EdgeInsets.fromLTRB(
        st.optionPaddingX,
        _headingPadding.top,
        st.optionPaddingX,
        _headingPadding.bottom,
      ),
      separator: st.line,
      separatorMargin: 0,
      padding: EdgeInsets.all(st.padding),
      duration: st.duration,
      curve: st.ease,
      disabledOpacity: st.disabledOpacity,
      groupGap: st.padding,
    );

    // ---- Search row ----
    final focused = _focus.hasFocus;
    final iconSize = st.iconSize.of(st.inputFontSize); // .search-icon font-size: input-font-size
    Widget field = KakaoFieldText(
      controller: _text,
      focusNode: _focus,
      style: theme.text(size: st.inputFontSize, color: st.text, height: st.font.lineHeight),
      placeholder: widget.placeholder,
      placeholderColor: st.muted,
      cursorColor: st.text,
      selectionColor: st.focus.withValues(alpha: _selectionAlpha),
      onChanged: _onInput,
      groupId: _group,
      // The caret goes after a query given to open() (command-palette.js
      // fills the input, then calls input.focus()).
      selectAllOnFocus: false,
    );
    field = Semantics(
      label: widget.label,
      expanded: true,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _onKey,
        child: field,
      ),
    );
    final search = Stack(
      children: [
        ConstrainedBox(
          // .search: min-height on the content box, the 1px border below it.
          constraints: BoxConstraints(minHeight: st.inputHeight + 1),
          child: Padding(
            padding: EdgeInsets.only(left: st.inputPaddingX, right: st.inputPaddingX, bottom: 1),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: CustomPaint(size: Size.square(iconSize), painter: _SearchPainter(st.muted)),
                ),
                SizedBox(width: st.gap),
                Expanded(child: field),
              ],
            ),
          ),
        ),
        // border-bottom: 1px line; focused: the focus colour, and an inset
        // shadow making it focus-width thick.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: focused ? st.focusWidth : 1,
          child: ColoredBox(color: focused ? st.focus : st.line),
        ),
      ],
    );

    // ---- Results ----
    final Widget body = rows.isEmpty
        ? Padding(
            padding: EdgeInsets.symmetric(vertical: _emptyPaddingY, horizontal: st.inputPaddingX),
            child: Text(
              widget.emptyText,
              textAlign: TextAlign.center,
              style: theme.text(size: fontSize * _emptyFont, color: st.muted, height: st.font.lineHeight),
            ),
          )
        : Flexible(
            child: KakaoOptionList(
              key: ValueKey(_rev),
              entries: entries,
              style: reduce ? _still(style) : style,
              controller: _list,
              onActivate: (i) => _activate(i, rows),
              initial: first < 0 ? null : first,
              revealStart: true,
              semanticsRole: SemanticsRole.list,
              semanticsLabel: KakaoCommandPalette.texts.listbox,
            ),
          );

    // ---- Key hints ----
    final hintStyle = theme.text(size: st.hintSize, color: st.muted, height: st.font.lineHeight);
    Widget hint(List<String> keys, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final k in keys) ...[Text(k, style: hintStyle), const SizedBox(width: _hintGap)],
        Text(text, style: hintStyle),
      ],
    );
    final hints = widget.hints && !touch
        ? ExcludeSemantics(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: _hintsPaddingY, horizontal: st.inputPaddingX),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: st.line)),
              ),
              child: Wrap(
                spacing: _hintsGap.column,
                runSpacing: _hintsGap.row,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  hint(['↑', '↓'], KakaoCommandPalette.texts.move),
                  hint(['↵'], KakaoCommandPalette.texts.run),
                  hint(['Esc'], KakaoCommandPalette.texts.close),
                ],
              ),
            ),
          )
        : null;

    final r = Radius.circular(st.radius);
    Widget panel = Container(
      key: widget.panelKey,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: st.bg,
        borderRadius: phone ? BorderRadius.only(bottomLeft: r, bottomRight: r) : BorderRadius.all(r),
        boxShadow: st.shadow,
      ),
      child: DefaultTextStyle(
        style: theme.text(size: fontSize, color: st.text, height: st.font.lineHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            body,
            ?hints,
            Semantics(liveRegion: true, label: _status, child: const SizedBox.shrink()),
          ],
        ),
      ),
    );
    panel = TapRegion(groupId: _group, child: panel);

    if (widget.inline) {
      return Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.label,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: st.maxHeight),
          child: panel,
        ),
      );
    }

    final animation = ModalRoute.of(context)?.animation;
    if (animation != null && !reduce) {
      final t = CurvedAnimation(parent: animation, curve: st.ease);
      final inner = panel;
      panel = FadeTransition(
        opacity: t,
        child: AnimatedBuilder(
          animation: t,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -_entrySlide * (1 - t.value)),
            child: Transform.scale(scale: _entryScale + (1 - _entryScale) * t.value, child: child),
          ),
          child: inner,
        ),
      );
    }

    final sheet = math.min(
      st.sheetMaxHeight.of(context),
      // @supports (height: 1dvh): min(sheet-max-height, 85dvh).
      KakaoViewportLength('dvh', st.sheetMaxHeight.value).of(context),
    );
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: widget.label,
      child: CustomSingleChildLayout(
        delegate: _PanelLayout(
          phone: phone,
          top: st.top.of(context),
          width: st.width,
          maxHeight: st.maxHeight,
          sheetMaxHeight: sheet,
        ),
        child: panel,
      ),
    );
  }

  static KakaoOptionListStyle _still(KakaoOptionListStyle s) => KakaoOptionListStyle(
    text: s.text,
    rowMinHeight: s.rowMinHeight,
    rowPadding: s.rowPadding,
    rowRadius: s.rowRadius,
    gap: s.gap,
    trailingGap: s.trailingGap,
    leadSize: s.leadSize,
    highlight: s.highlight,
    check: s.check,
    icon: s.icon,
    heading: s.heading,
    headingPadding: s.headingPadding,
    separator: s.separator,
    separatorMargin: s.separatorMargin,
    padding: s.padding,
    duration: Duration.zero,
    curve: s.curve,
    disabledOpacity: s.disabledOpacity,
    groupGap: s.groupGap,
  );
}

/// `.overlay` / `.panel` placement: `top` from the top and centred, at most
/// `width` wide with 1rem left and right, at most `max-height` and the room
/// down to 1rem above the bottom; a phone: full width at the top, at most
/// `sheet-max-height`.
class _PanelLayout extends SingleChildLayoutDelegate {
  const _PanelLayout({
    required this.phone,
    required this.top,
    required this.width,
    required this.maxHeight,
    required this.sheetMaxHeight,
  });

  final bool phone;
  final double top;
  final double width;
  final double maxHeight;
  final double sheetMaxHeight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    if (phone) {
      return BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
        maxHeight: math.min(sheetMaxHeight, size.height),
      );
    }
    final w = math.max(0.0, math.min(width, size.width - 2 * _sideInset));
    final room = math.max(0.0, size.height - top - _sideInset);
    return BoxConstraints(minWidth: w, maxWidth: w, maxHeight: math.min(maxHeight, room));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      phone ? Offset.zero : Offset((size.width - childSize.width) / 2, top);

  @override
  bool shouldRelayout(_PanelLayout old) =>
      old.phone != phone ||
      old.top != top ||
      old.width != width ||
      old.maxHeight != maxHeight ||
      old.sheetMaxHeight != sheetMaxHeight;
}

/// command-palette.js SEARCH: a circle at (7, 7) r 4.5 and a line from
/// (10.5, 10.5) 3 on, in a 16 unit box, stroke 1.6, round caps.
class _SearchPainter extends CustomPainter {
  const _SearchPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 16;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _searchStroke * k
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(7 * k, 7 * k), 4.5 * k, paint);
    canvas.drawLine(Offset(10.5 * k, 10.5 * k), Offset(13.5 * k, 13.5 * k), paint);
  }

  @override
  bool shouldRepaint(_SearchPainter old) => old.color != color;
}

// ---------------------------------------------------------------- Search

/// A command with its label folded for matching (command-palette.js
/// `prepare`): [folded] keeps, for every code unit, the index of the
/// character ([chars]) it came from, so marks land on the right letters.
class _Command {
  _Command(this.command, this.index) {
    final chars = <String>[];
    final buf = StringBuffer();
    final map = <int>[];
    for (final r in command.label.runes) {
      final c = String.fromCharCode(r);
      final i = chars.length;
      chars.add(c);
      var f = kakaoFold(c);
      if (f.isEmpty) f = c;
      for (var k = 0; k < f.length; k++) {
        map.add(i);
      }
      buf.write(f);
    }
    this.chars = chars;
    folded = buf.toString();
    this.map = map;
    keywords = [
      for (final k in command.keywords)
        if (kakaoFold(k.trim()) case final f when f.isNotEmpty) f,
    ];
  }

  final KakaoCommand command;
  final int index;
  late final List<String> chars;
  late final String folded;
  late final List<int> map;
  late final List<String> keywords;
}

final _wordStart = RegExp(r'[\s\-_/.:,(]');

/// The best label match of one query word: its score and the marked
/// characters, or null (command-palette.js `matchLabel`).
({int score, List<int> at})? _matchLabel(_Command cmd, String word) {
  final folded = cmd.folded;
  final map = cmd.map;
  final i = folded.indexOf(word);
  if (i >= 0) {
    final score = i == 0 ? 100 : (_wordStart.hasMatch(folded[i - 1]) ? 80 : 50);
    return (score: score, at: [for (var k = i; k < i + word.length; k++) map[k]]);
  }
  // The letters in order, each as early as possible, starting at the start
  // of a word, with no more than two letters skipped per step on average.
  final letters = [for (final r in word.runes) String.fromCharCode(r)];
  if (letters.isEmpty) return null;
  var from = 0;
  while (from < folded.length &&
      (!folded.startsWith(letters.first, from) || (from > 0 && !_wordStart.hasMatch(folded[from - 1])))) {
    from++;
  }
  if (from >= folded.length) return null;
  var gaps = 0;
  final at = <int>[];
  for (final ch in letters) {
    final j = folded.indexOf(ch, from);
    if (j < 0) return null;
    if (at.isNotEmpty) gaps += j - from;
    at.add(map[j]);
    from = j + ch.length;
  }
  if (gaps > 2 * (letters.length - 1)) return null;
  return (score: math.max(1, 30 - gaps), at: at);
}

int _matchKeywords(List<String> keywords, String word) {
  var best = 0;
  for (final k in keywords) {
    final i = k.indexOf(word);
    if (i == 0) {
      best = math.max(best, 45);
    } else if (i > 0) {
      best = math.max(best, 40);
    }
  }
  return best;
}

/// command-palette.js `matchCommand`: the score for the query words and the
/// label characters to mark; null: no match.
({int score, Set<int> marks})? _matchCommand(_Command cmd, List<String> words) {
  var score = 0;
  final marks = <int>{};
  for (final word in words) {
    final label = _matchLabel(cmd, word);
    final kw = _matchKeywords(cmd.keywords, word);
    if (label == null && kw == 0) return null;
    if (label != null && label.score >= kw) {
      score += label.score;
      marks.addAll(label.at);
    } else {
      score += kw;
    }
  }
  return (score: score, marks: marks);
}

class _Hit {
  const _Hit(this.command, this.score, this.marks);
  final _Command command;
  final int score;
  final Set<int> marks;
}

class _Group {
  _Group(this.heading, this.order);
  final String heading;
  final int order;
  final hits = <_Hit>[];
  int best = -1 << 31;
}

/// command-palette.js `_filter`: the groups to show for [query], and the
/// rows in list order.
({List<_Group> groups, List<_Command> rows}) _arrange(
  List<_Command> all,
  String query,
  List<String> recent,
  String recentHeading,
) {
  final words = kakaoFold(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final groups = <_Group>[];
  final byName = <String, _Group>{};
  void add(String key, String heading, _Hit hit, int order) {
    final g = byName.putIfAbsent(key, () {
      final g = _Group(heading, order);
      groups.add(g);
      return g;
    });
    g.hits.add(hit);
    g.best = math.max(g.best, hit.score);
  }

  if (words.isEmpty) {
    for (final id in recent) {
      final i = all.indexWhere((c) => c.command.id == id);
      if (i >= 0) add('\u0000recent', recentHeading, _Hit(all[i], 0, const {}), -1);
    }
    for (final c in all) {
      final g = c.command.group ?? '';
      add(g, g, _Hit(c, 0, const {}), c.index);
    }
  } else {
    for (final c in all) {
      final m = _matchCommand(c, words);
      final g = c.command.group ?? '';
      if (m != null) add(g, g, _Hit(c, m.score, m.marks), c.index);
    }
    for (final g in groups) {
      g.hits.sort((a, b) => b.score != a.score ? b.score - a.score : a.command.index - b.command.index);
    }
    groups.sort((a, b) => b.best != a.best ? b.best - a.best : a.order - b.order);
  }
  return (groups: groups, rows: [for (final g in groups) ...g.hits.map((h) => h.command)]);
}

/// The label with the [marks]ed characters in [style] (`<mark>`).
List<InlineSpan> _marked(_Command cmd, Set<int> marks, TextStyle style) {
  final spans = <InlineSpan>[];
  final run = StringBuffer();
  var marked = false;
  void flush() {
    if (run.isEmpty) return;
    spans.add(TextSpan(text: run.toString(), style: marked ? style : null));
    run.clear();
  }

  for (var i = 0; i < cmd.chars.length; i++) {
    final on = marks.contains(i);
    if (on != marked) {
      flush();
      marked = on;
    }
    run.write(cmd.chars[i]);
  }
  flush();
  return spans;
}

// ---------------------------------------------------------------- Hotkey

/// command-palette.js `parseHotkey` / `hotkeyMatches`: "Mod+K" and the like.
@immutable
class _Hotkey {
  const _Hotkey(this.key, {this.ctrl = false, this.meta = false, this.alt = false, this.shift = false});

  final String key;
  final bool ctrl;
  final bool meta;
  final bool alt;
  final bool shift;

  static bool get _apple => switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.iOS => true,
    _ => false,
  };

  static _Hotkey? parse(String? text) {
    final value = (text ?? '').trim();
    if (value.isEmpty || value.toLowerCase() == 'none') return null;
    var parts = value.split('+').map((p) => p.trim()).toList();
    // "Ctrl++": the last key is "+" itself.
    if (value.endsWith('++')) parts = [...parts.sublist(0, parts.length - 2), '+'];
    final key = parts.removeLast();
    if (key.isEmpty) return null;
    var ctrl = false, meta = false, alt = false, shift = false;
    for (final p in parts) {
      switch (p.toLowerCase()) {
        case 'mod':
          _apple ? meta = true : ctrl = true;
        case 'cmd' || 'command' || 'meta' || '⌘':
          meta = true;
        case 'ctrl' || 'control' || '⌃':
          ctrl = true;
        case 'alt' || 'option' || 'opt' || '⌥':
          alt = true;
        case 'shift' || '⇧':
          shift = true;
      }
    }
    return _Hotkey(key, ctrl: ctrl, meta: meta, alt: alt, shift: shift);
  }

  bool matches(KeyEvent e) {
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed != ctrl || keys.isMetaPressed != meta || keys.isAltPressed != alt) return false;
    final lower = key.toLowerCase();
    final letter = RegExp(r'^[a-z]$').hasMatch(lower);
    if (shift ? !keys.isShiftPressed : (letter && keys.isShiftPressed)) return false;
    if (e.logicalKey.keyLabel.toLowerCase() == lower || e.character?.toLowerCase() == lower) return true;
    // Alt (Option on a Mac) changes the character: fall back to the physical key.
    if (letter) return e.physicalKey == PhysicalKeyboardKey(0x00070004 + lower.codeUnitAt(0) - 0x61);
    if (RegExp(r'^[0-9]$').hasMatch(key)) {
      final d = key.codeUnitAt(0) - 0x30;
      return e.physicalKey == PhysicalKeyboardKey(d == 0 ? 0x00070027 : 0x0007001d + d);
    }
    return false;
  }
}
