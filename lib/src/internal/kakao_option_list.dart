// The option list: the rows under menu, the button's menu mode, select,
// combobox, multi-dropdown and command-palette. Not exported. Each public
// widget feeds it the values of its own web settings block
// ([KakaoOptionListStyle]) and its own semantics, so lists built on it can
// differ where their web twins do.
//
// One highlight, set by keys and pointer alike (menu.js focuses the item
// under the pointer; select.js, combobox.js and command-palette.js move
// their `data-active` row with both), lives in a [KakaoOptionListController].
// A list that has keyboard focus itself (menu) gives a [FocusNode]; a list
// whose keys come from a text field (combobox, command palette) leaves it
// out and passes the field's keys to [KakaoOptionListController.handleKey].
import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// An entry of a [KakaoOptionList]: a [KakaoOption], a [KakaoOptionGroup] or
/// a [KakaoOptionSeparator].
@immutable
sealed class KakaoOptionEntry {
  const KakaoOptionEntry();
}

/// A row.
class KakaoOption extends KakaoOptionEntry {
  const KakaoOption({
    required this.label,
    this.disabled = false,
    this.checked,
    this.leading,
    this.trailing,
    this.color,
    this.role,
    this.expanded,
  });

  /// The text, also what type-ahead matches.
  final String label;

  /// Shown dimmed, skipped by the keys, not activated.
  final bool disabled;

  /// Null: the row is not checkable. Otherwise the lead column shows the
  /// check mark when true (and the row takes the checked weight), and keeps
  /// its room when false.
  final bool? checked;

  /// Drawn in the lead column (an icon), in the style's icon colour and size.
  /// Ignored when [checked] is not null.
  final Widget? leading;

  /// At the end of the row, after the trailing gap (a shortcut, a submenu arrow).
  final Widget? trailing;

  /// Text and icon colour instead of the style's (a danger tone).
  final Color? color;

  /// The row's semantics role (menu item, checkbox or radio menu item).
  final SemanticsRole? role;

  /// Not null: the row opens something (a submenu), open when true. An open
  /// row keeps the highlight background (menu.js `[aria-expanded="true"]`).
  final bool? expanded;
}

/// Rows under an optional heading (`role="group"`).
class KakaoOptionGroup extends KakaoOptionEntry {
  const KakaoOptionGroup(this.options, {this.label});
  final String? label;
  final List<KakaoOption> options;
}

/// A line between rows.
class KakaoOptionSeparator extends KakaoOptionEntry {
  const KakaoOptionSeparator();
}

/// The rows of [entries] in order: the indices a [KakaoOptionListController]
/// and [KakaoOptionList.onActivate] use.
List<KakaoOption> kakaoOptionRows(List<KakaoOptionEntry> entries) => [
  for (final e in entries)
    ...switch (e) {
      KakaoOption() => [e],
      KakaoOptionGroup() => e.options,
      KakaoOptionSeparator() => const <KakaoOption>[],
    },
];

/// How long typed letters add up to one search (menu.js `TYPE_RESET`).
const kakaoTypeAheadReset = Duration(milliseconds: 600);

/// The look of a [KakaoOptionList], from the settings block of the widget
/// using it. Lengths are logical pixels.
@immutable
class KakaoOptionListStyle {
  const KakaoOptionListStyle({
    required this.text,
    required this.rowMinHeight,
    required this.rowPadding,
    required this.rowRadius,
    required this.gap,
    required this.trailingGap,
    required this.leadSize,
    required this.highlight,
    required this.check,
    required this.icon,
    required this.heading,
    required this.headingPadding,
    required this.separator,
    required this.separatorMargin,
    required this.padding,
    required this.duration,
    required this.curve,
    this.checkedWeight,
    this.disabledOpacity = 1,
    this.disabledColor,
    this.focus,
    this.focusWidth = 0,
    this.checkBuilder,
  });

  /// The row text (size, weight, colour, line height).
  final TextStyle text;
  final double rowMinHeight;
  final EdgeInsets rowPadding;
  final double rowRadius;

  /// Between lead column, label and trailing part.
  final double gap;

  /// Before the trailing part (menu.js `.shortcut` / `.arrow`: margin-left
  /// `shortcut-gap - gap`, so the total is this).
  final double trailingGap;

  /// The lead column's width and height (check mark and icon).
  final double leadSize;

  /// The background of the highlighted row.
  final Color highlight;
  final Color check;
  final Color icon;

  /// Group headings.
  final TextStyle heading;
  final EdgeInsets headingPadding;
  final Color separator;

  /// Above and below a separator.
  final double separatorMargin;

  /// Around the rows; separators run through it to the list's edges
  /// (menu.js `.sep` margin `calc(padding * -1)`).
  final EdgeInsets padding;

  /// The highlight background's fade (none with reduced motion).
  final Duration duration;
  final Curve curve;

  /// The weight of a checked row; null keeps the text weight.
  final double? checkedWeight;

  /// A disabled row's opacity (menu.js) or text colour (select.js).
  final double disabledOpacity;
  final Color? disabledColor;

  /// The ring on the highlighted row after keyboard use (menu.js
  /// `.item:focus-visible`), drawn inside the row. Null: no ring.
  final Color? focus;
  final double focusWidth;

  /// The lead of a checkable row instead of the check mark (a multiple
  /// select's checkbox, select.js `.box`), for checked and unchecked rows.
  final Widget Function(bool checked)? checkBuilder;
}

/// The highlighted row of a [KakaoOptionList] and the keys that move it.
///
/// - [move] goes to the next / previous enabled row, wrapping; from no
///   highlight, forward starts at the first and backward at the last;
/// - [first] / [last];
/// - [typeAhead] with a letter goes to the next row starting with it; letters
///   typed within [typeAheadReset] add up to a word, which may stay on
///   the current row (menu.js `_typeAhead`);
/// - [handleKey] maps Up / Down, Home / End (and Page Up / Down), letters and
///   Enter / Space to the above and to [activate].
///
/// [keyboard] is true when the last change came from keys (the focus ring
/// shows), false when it came from the pointer.
class KakaoOptionListController extends ChangeNotifier {
  /// [typeAheadReset]: how long typed letters add up to one word (menu.js
  /// 600 ms, button.js 700 ms).
  KakaoOptionListController({this.typeAheadReset = kakaoTypeAheadReset});

  final Duration typeAheadReset;
  int? _highlighted;
  bool _keyboard = false;
  List<KakaoOption> _rows = const [];
  void Function(int index)? _onActivate;
  String _typed = '';
  Timer? _typedTimer;

  int? get highlighted => _highlighted;
  bool get keyboard => _keyboard;

  /// True within [typeAheadReset] of a typed letter: Space then types.
  bool get typing => _typed.isNotEmpty;

  /// The rows of the list attached to this controller.
  List<KakaoOption> get rows => _rows;

  void highlight(int? index, {bool keyboard = false}) {
    final i = index != null && index >= 0 && index < _rows.length && !_rows[index].disabled ? index : null;
    if (i == _highlighted && keyboard == _keyboard) return;
    _highlighted = i;
    _keyboard = keyboard;
    notifyListeners();
  }

  List<int> get _enabled => [
    for (var i = 0; i < _rows.length; i++)
      if (!_rows[i].disabled) i,
  ];

  void move(int delta) {
    final on = _enabled;
    if (on.isEmpty) return;
    final at = on.indexOf(_highlighted ?? -1);
    final int next;
    if (at == -1) {
      next = delta > 0 ? 0 : on.length - 1;
    } else {
      next = (at + delta) % on.length;
    }
    highlight(on[next < 0 ? next + on.length : next], keyboard: true);
  }

  void first() {
    final on = _enabled;
    if (on.isNotEmpty) highlight(on.first, keyboard: true);
  }

  void last() {
    final on = _enabled;
    if (on.isNotEmpty) highlight(on.last, keyboard: true);
  }

  /// Goes to the row matching the letters typed so far; true when one did.
  bool typeAhead(String char) {
    _typedTimer?.cancel();
    _typedTimer = Timer(typeAheadReset, () => _typed = '');
    _typed += char.toLowerCase();
    final on = _enabled;
    if (on.isEmpty) return false;
    final i = on.indexOf(_highlighted ?? -1);
    final same = _typed.split('').every((c) => c == _typed[0]);
    final query = same ? _typed[0] : _typed;
    // One letter (again and again) walks on; a longer word may stay put.
    final start = same ? i + 1 : (i < 0 ? 0 : i);
    for (var n = 0; n < on.length; n++) {
      final row = on[(start + n) % on.length];
      if (_rows[row].label.trim().toLowerCase().startsWith(query)) {
        highlight(row, keyboard: true);
        return true;
      }
    }
    return false;
  }

  /// Activates the highlighted row (Enter), as a tap on it would.
  void activate() {
    final i = _highlighted;
    if (i != null) _onActivate?.call(i);
  }

  /// The list's keys. [typeAhead] false leaves letters (and Space) to a text
  /// field; [space] false leaves Space alone.
  KeyEventResult handleKey(KeyEvent e, {bool typeAhead = true, bool space = true}) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    if (keys.isAltPressed || keys.isControlPressed || keys.isMetaPressed) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      move(1);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      move(-1);
    } else if (k == LogicalKeyboardKey.home || k == LogicalKeyboardKey.pageUp) {
      first();
    } else if (k == LogicalKeyboardKey.end || k == LogicalKeyboardKey.pageDown) {
      last();
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (e is KeyDownEvent) activate();
    } else if (k == LogicalKeyboardKey.space && space) {
      if (typeAhead && typing) {
        this.typeAhead(' ');
      } else if (e is KeyDownEvent) {
        activate();
      }
    } else if (typeAhead && e.character != null && e.character!.length == 1 && e.character!.trim().isNotEmpty) {
      this.typeAhead(e.character!);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _attach(List<KakaoOption> rows, void Function(int index)? onActivate) {
    _rows = rows;
    _onActivate = onActivate;
    final h = _highlighted;
    if (h != null && (h >= rows.length || rows[h].disabled)) _highlighted = null;
  }

  @override
  void dispose() {
    _typedTimer?.cancel();
    super.dispose();
  }
}

/// Rows, group headings and separators with one highlight (see
/// [KakaoOptionListController]).
///
/// - A pointer over an enabled row highlights it (a disabled row clears the
///   highlight); the highlight stays when the pointer leaves the list.
/// - A tap on an enabled row, or Enter / Space, calls [onActivate] with the
///   row's index in [kakaoOptionRows].
/// - With a [focusNode] the list takes keys itself while focused ([onKey]
///   sees them first) and a pointer over a row moves focus to it, as
///   menu.js focuses the item under the pointer. [focusable] makes it a tab
///   stop (an inline menu); [highlightFirstOnFocus] then highlights the
///   first row when focus arrives with nothing highlighted.
/// - A row moved to by keys scrolls into view; the list scrolls its own
///   content when its height is capped.
/// - The lead column (check mark or icon) shows when any row has one
///   (menu.js `.panel.has-lead`).
///
/// [rowWrapper] wraps a row (without the list padding), for a submenu
/// panel anchored to it.
class KakaoOptionList extends StatefulWidget {
  const KakaoOptionList({
    super.key,
    required this.entries,
    required this.style,
    required this.controller,
    this.onActivate,
    this.focusNode,
    this.focusable = false,
    this.highlightFirstOnFocus = false,
    this.onKey,
    this.onFocusChange,
    this.rowWrapper,
    this.semanticsRole,
    this.semanticsLabel,
  });

  final List<KakaoOptionEntry> entries;
  final KakaoOptionListStyle style;
  final KakaoOptionListController controller;
  final void Function(int index)? onActivate;
  final FocusNode? focusNode;
  final bool focusable;
  final bool highlightFirstOnFocus;
  final KeyEventResult Function(KeyEvent event)? onKey;
  final ValueChanged<bool>? onFocusChange;
  final Widget Function(int index, Widget row)? rowWrapper;

  /// The list's role (menu, list) and accessible name.
  final SemanticsRole? semanticsRole;
  final String? semanticsLabel;

  @override
  State<KakaoOptionList> createState() => _KakaoOptionListState();
}

class _KakaoOptionListState extends State<KakaoOptionList> {
  final _scroll = ScrollController();
  final _rowKeys = <int, GlobalKey>{};
  int? _shown;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(KakaoOptionList old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final c = widget.controller;
    final i = c.highlighted;
    if (i != _shown && i != null && c.keyboard) {
      // Keep the row in view inside the list, without moving the page.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _rowKeys[i]?.currentContext;
        final box = ctx?.findRenderObject();
        if (ctx == null || box == null || !_scroll.hasClients) return;
        final viewport = RenderAbstractViewport.maybeOf(box);
        if (viewport == null) return;
        final top = viewport.getOffsetToReveal(box, 0).offset;
        final bottom = viewport.getOffsetToReveal(box, 1).offset;
        final now = _scroll.offset;
        if (now > top) _scroll.jumpTo(top);
        if (now < bottom) _scroll.jumpTo(bottom);
      });
    }
    _shown = i;
  }

  void _hover(int index, KakaoOption row) {
    final c = widget.controller;
    c.highlight(row.disabled ? null : index);
    final f = widget.focusNode;
    if (f != null && !f.hasPrimaryFocus) f.requestFocus();
  }

  void _tap(int index, KakaoOption row) {
    if (!row.disabled) widget.onActivate?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final rows = kakaoOptionRows(widget.entries);
    final c = widget.controller.._attach(rows, widget.onActivate);
    final lead = rows.any((r) => r.checked != null || r.leading != null);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final hasFocus = widget.focusNode?.hasFocus ?? true;
    var index = 0;

    Widget row(KakaoOption o) {
      final i = index++;
      final key = _rowKeys.putIfAbsent(i, GlobalKey.new);
      Widget w = _Row(
        key: key,
        option: o,
        style: s,
        lead: lead,
        highlighted: c.highlighted == i,
        ring: c.highlighted == i && c.keyboard && hasFocus,
        duration: reduce ? Duration.zero : s.duration,
        onHover: () => _hover(i, o),
        onTap: () => _tap(i, o),
      );
      final wrap = widget.rowWrapper;
      if (wrap != null) w = wrap(i, w);
      return Padding(
        padding: EdgeInsets.only(left: s.padding.left, right: s.padding.right),
        child: w,
      );
    }

    Widget heading(String label) => Padding(
      padding: EdgeInsets.only(left: s.padding.left, right: s.padding.right),
      child: Padding(
        padding: s.headingPadding,
        child: Text(label, style: s.heading),
      ),
    );

    final children = <Widget>[];
    for (final e in widget.entries) {
      switch (e) {
        case KakaoOption():
          children.add(row(e));
        case KakaoOptionGroup():
          children.add(
            Semantics(
              container: true,
              explicitChildNodes: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [if (e.label case final l? when l.isNotEmpty) heading(l), for (final o in e.options) row(o)],
              ),
            ),
          );
        case KakaoOptionSeparator():
          children.add(
            Padding(
              padding: EdgeInsets.symmetric(vertical: s.separatorMargin),
              child: SizedBox(height: 1, child: ColoredBox(color: s.separator)),
            ),
          );
      }
    }

    Widget list = SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsets.only(top: s.padding.top, bottom: s.padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
    list = Semantics(
      role: widget.semanticsRole,
      label: widget.semanticsLabel,
      container: true,
      explicitChildNodes: true,
      child: list,
    );
    final f = widget.focusNode;
    if (f != null) {
      list = Focus(
        focusNode: f,
        canRequestFocus: true,
        skipTraversal: !widget.focusable,
        includeSemantics: false,
        onFocusChange: (on) {
          if (on && widget.highlightFirstOnFocus && c.highlighted == null) c.first();
          widget.onFocusChange?.call(on);
          setState(() {});
        },
        onKeyEvent: (node, e) {
          final r = widget.onKey?.call(e) ?? KeyEventResult.ignored;
          if (r != KeyEventResult.ignored) return r;
          return c.handleKey(e);
        },
        child: list,
      );
    }
    return DefaultTextStyle(style: s.text, child: list);
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.option,
    required this.style,
    required this.lead,
    required this.highlighted,
    required this.ring,
    required this.duration,
    required this.onHover,
    required this.onTap,
  });

  final KakaoOption option;
  final KakaoOptionListStyle style;
  final bool lead;
  final bool highlighted;
  final bool ring;
  final Duration duration;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = style;
    final o = option;
    final checked = o.checked == true;
    final fg = o.disabled && s.disabledColor != null ? s.disabledColor! : (o.color ?? s.text.color!);
    final weight = checked && s.checkedWeight != null ? s.checkedWeight! : null;
    var text = s.text.copyWith(color: fg);
    if (weight != null) {
      text = text.copyWith(
        fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
        fontVariations: [FontVariation.weight(weight)],
      );
    }
    final radius = BorderRadius.circular(s.rowRadius);

    Widget? leadBox;
    if (lead) {
      final box = s.checkBuilder;
      final Widget? inner = o.checked != null
          ? (box != null ? box(checked) : (checked ? CustomPaint(painter: KakaoCheckPainter(s.check)) : null))
          : (o.leading == null
                ? null
                : IconTheme(
                    // A danger row's icon takes its colour (menu.js `.lead { color: inherit }`).
                    data: IconThemeData(color: o.color ?? s.icon, size: s.leadSize),
                    child: o.leading!,
                  ));
      leadBox = SizedBox.square(dimension: s.leadSize, child: inner);
    }

    Widget content = Row(
      children: [
        if (leadBox != null) ...[leadBox, SizedBox(width: s.gap)],
        Expanded(child: Text(o.label, style: text)),
        if (o.trailing != null) ...[SizedBox(width: s.trailingGap), o.trailing!],
      ],
    );
    content = AnimatedContainer(
      duration: duration,
      curve: s.curve,
      constraints: BoxConstraints(minHeight: s.rowMinHeight),
      padding: s.rowPadding,
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: highlighted || o.expanded == true ? s.highlight : s.highlight.withValues(alpha: 0),
        borderRadius: radius,
      ),
      foregroundDecoration: ring && s.focus != null && s.focusWidth > 0
          ? BoxDecoration(
              border: Border.all(color: s.focus!, width: s.focusWidth),
              borderRadius: radius,
            )
          : null,
      child: content,
    );
    if (o.disabled && s.disabledOpacity < 1) content = Opacity(opacity: s.disabledOpacity, child: content);

    return Semantics(
      role: o.role,
      container: true,
      enabled: !o.disabled,
      checked: o.checked,
      selected: o.role == null && o.checked != null ? checked : null,
      expanded: o.expanded,
      button: o.role == null && o.checked == null,
      label: o.label,
      onTap: o.disabled ? null : onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: o.disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        onHover: (_) => onHover(),
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: content),
      ),
    );
  }
}

/// The check mark menu.js and select.js draw: `M5 12.5l4.5 4.5L19 7.5` in a
/// 24 unit box, stroke 2.6, round caps and joins, scaled to the box.
class KakaoCheckPainter extends CustomPainter {
  const KakaoCheckPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 24;
    final path = Path()
      ..moveTo(5 * k, 12.5 * k)
      ..lineTo(9.5 * k, 17 * k)
      ..lineTo(19 * k, 7.5 * k);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(KakaoCheckPainter old) => old.color != color;
}
