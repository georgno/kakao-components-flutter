import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_anchored_panel.dart';
import '../internal/kakao_option_list.dart';
import '../settings/kakao_menu_settings.g.dart';
import '../theme/kakao_theme.dart';

/// `<kakao-menu placement>`: where the menu sits against its trigger.
enum KakaoMenuPlacement { bottomStart, bottomEnd, topStart, topEnd }

/// `type` of a menu item.
enum KakaoMenuItemType {
  /// A plain action (`menuitem`).
  action,

  /// Turns on and off (`menuitemcheckbox`).
  checkbox,

  /// One of the radio items with the same [KakaoMenuItem.name], else of the
  /// same group, is on (`menuitemradio`).
  radio,
}

/// An entry of `list-data`: a [KakaoMenuItem], a [KakaoMenuGroup] or a
/// [KakaoMenuSeparator] (`"-"`).
@immutable
sealed class KakaoMenuEntry {
  const KakaoMenuEntry();
}

/// An item (`{ label, value, icon, shortcut, disabled, tone, type, checked,
/// name, children }`).
class KakaoMenuItem extends KakaoMenuEntry {
  const KakaoMenuItem(
    this.label, {
    this.value,
    this.icon,
    this.shortcut,
    this.disabled = false,
    this.danger = false,
    this.type = KakaoMenuItemType.action,
    this.checked = false,
    this.name,
    this.children,
  });

  final String label;

  /// Reported in [KakaoMenuSelectEvent]; default: the label.
  final Object? value;

  /// Drawn before the label, `--kakao-menu-icon-size` and `--kakao-menu-icon`
  /// (an [Icon]; the web draws named glyphs).
  final Widget? icon;

  /// A hint such as `Mod+D` at the end of the row. The menu shows it only:
  /// it does not bind the key.
  final String? shortcut;

  /// Shown dimmed, cannot be picked, skipped by the keys.
  final bool disabled;

  /// `tone: "danger"`: a destructive action.
  final bool danger;
  final KakaoMenuItemType type;

  /// The starting state of a checkbox or radio item; the menu keeps the
  /// state from then on, as the web one does.
  final bool checked;

  /// Radio items with the same name in one menu belong together.
  final String? name;

  /// The item opens a submenu of these.
  final List<KakaoMenuEntry>? children;

  Object get effectiveValue => value ?? label;
  bool get _check => children == null && type != KakaoMenuItemType.action;
}

/// `{ group, items }`: items under an optional heading.
class KakaoMenuGroup extends KakaoMenuEntry {
  const KakaoMenuGroup({this.label, required this.items});
  final String? label;
  final List<KakaoMenuItem> items;
}

/// `"-"`: a separator.
class KakaoMenuSeparator extends KakaoMenuEntry {
  const KakaoMenuSeparator();
}

/// `menu-select`: an item was picked. [preventDefault] keeps the menu open
/// and leaves the check as it was.
class KakaoMenuSelectEvent {
  KakaoMenuSelectEvent._(this.item, this.checked);

  final KakaoMenuItem item;

  /// The new state of a checkbox or radio item; null for other items.
  final bool? checked;
  Object get value => item.effectiveValue;

  bool _prevented = false;
  bool get defaultPrevented => _prevented;
  void preventDefault() => _prevented = true;
}

/// Opens and closes a [KakaoMenu] (`open()`, `openAt()`, `close()`,
/// `toggle()`, `isOpen`).
class KakaoMenuController extends KakaoAnchoredPanelController {
  Offset? _point;
  _Start _start = _Start.none;

  /// Opens against the anchor (the trigger, or the context menu's child).
  @override
  void open() {
    _point = null;
    super.open();
  }

  /// Opens with its top left corner at [point], in the coordinates of the
  /// menu's anchor (`openAt(x, y)`).
  void openAt(Offset point) {
    _point = point;
    if (isOpen) {
      notifyListeners();
    } else {
      super.open();
    }
  }

  void _openWith(_Start start, [Offset? point]) {
    _start = start;
    point == null ? open() : openAt(point);
  }
}

enum _Start { none, first, last }

// menu.js script constants (outside the settings block).
const _hoverDelay = Duration(milliseconds: 140); // HOVER_DELAY
const _itemLineHeight = 1.3; // .item line-height
const _itemPaddingY = 6.4; // .item padding: 0.4rem …
const _headingPadding = (top: 8.8, bottom: 4.0); // .heading padding: 0.55rem … 0.25rem
const _arrowSize = 0.9; // .arrow width / height: 0.9em
const _arrowPull = 0.15; // .arrow margin-right: -0.15em

/// Flutter twin of `<kakao-menu>`: a menu of actions with groups and
/// headings, separators, icons, shortcut hints, a danger tone, checkbox and
/// radio items and submenus.
///
/// Three ways to show it, as on the web:
/// - [KakaoMenu.new] (`for`): [anchorBuilder] builds the trigger and gets the
///   controller; call `menu.toggle` from its press. Down / Up on the trigger
///   open the menu on the first / last item, Enter or Space (a keyboard
///   press) on the first.
/// - [KakaoMenu.context] (`context-for`): the menu of [child], at the pointer
///   on a secondary click or a 500 ms touch press, and under [child] with
///   Shift+F10 or the Menu key.
/// - [KakaoMenu.inline] (`inline`): shown in place, always open, one tab stop.
///
/// As menu.js:
/// - under the trigger (or above, per [placement]), [KakaoMenuSettings.offset]
///   away, lined up with its start (or end) edge; flipped to the other side
///   when there is too little room and the other side has more; kept 8 px
///   inside the screen; as tall as the room (at least 120 px), scrolling;
/// - fades in and slides 4 px over `--kakao-menu-duration`, closes at once;
///   with reduced motion it appears at once;
/// - in the menu: Down / Up (wrapping), Home / End, a letter jumps,
///   Enter / Space pick, Right opens a submenu and Left closes it, Escape
///   closes (a submenu first) with focus back where it was, Tab closes and
///   moves on; the item under the pointer is the highlighted one; a submenu
///   opens and closes 140 ms after the pointer moves onto or off its item;
/// - picking calls [onSelect] and closes the menu (checkbox and radio items
///   stay open with [keepOpen]); a pointer down outside closes it.
class KakaoMenu extends StatefulWidget {
  const KakaoMenu({
    super.key,
    required this.items,
    required Widget Function(BuildContext context, KakaoMenuController menu) this.anchorBuilder,
    this.placement = KakaoMenuPlacement.bottomStart,
    this.label,
    this.keepOpen = false,
    this.disabled = false,
    this.controller,
    this.onSelect,
    this.onOpen,
    this.onClose,
  }) : child = null,
       _mode = _Mode.trigger;

  /// A context menu for [child].
  const KakaoMenu.context({
    super.key,
    required this.items,
    required Widget this.child,
    this.label,
    this.keepOpen = false,
    this.disabled = false,
    this.controller,
    this.onSelect,
    this.onOpen,
    this.onClose,
  }) : anchorBuilder = null,
       placement = KakaoMenuPlacement.bottomStart,
       _mode = _Mode.context;

  /// The menu in place, always shown.
  const KakaoMenu.inline({super.key, required this.items, this.label, this.keepOpen = false, this.onSelect})
    : anchorBuilder = null,
      child = null,
      placement = KakaoMenuPlacement.bottomStart,
      disabled = false,
      controller = null,
      onOpen = null,
      onClose = null,
      _mode = _Mode.inline;

  /// `list-data` / `items`.
  final List<KakaoMenuEntry> items;
  final Widget Function(BuildContext context, KakaoMenuController menu)? anchorBuilder;
  final Widget? child;
  final KakaoMenuPlacement placement;

  /// The menu's accessible name; default [texts]`.menu`.
  final String? label;

  /// Checkbox and radio items do not close the menu.
  final bool keepOpen;

  /// The menu does not open.
  final bool disabled;
  final KakaoMenuController? controller;

  /// `menu-select`.
  final ValueChanged<KakaoMenuSelectEvent>? onSelect;

  /// `menu-open` / `menu-close`.
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final _Mode _mode;

  /// `KakaoMenu.texts`: the default accessible name.
  static ({String menu}) texts = (menu: 'Menu');

  @override
  State<KakaoMenu> createState() => _KakaoMenuState();
}

enum _Mode { trigger, context, inline }

class _KakaoMenuState extends State<KakaoMenu> {
  KakaoMenuController? _own;
  KakaoMenuController get _controller => widget.controller ?? (_own ??= KakaoMenuController());
  bool _wasOpen = false;
  final _checks = Map<KakaoMenuItem, bool>.identity();
  final _inlineKey = GlobalKey<_MenuPanelState>();
  bool _contextMenuOff = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _wasOpen = _controller.isOpen;
  }

  @override
  void didUpdateWidget(KakaoMenu old) {
    super.didUpdateWidget(old);
    final before = old.controller ?? _own;
    if (before != _controller) {
      before?.removeListener(_changed);
      _controller.addListener(_changed);
      _wasOpen = _controller.isOpen;
    }
    if (!identical(old.items, widget.items)) _checks.clear();
  }

  @override
  void dispose() {
    (widget.controller ?? _own)?.removeListener(_changed);
    _own?.dispose();
    if (_contextMenuOff) BrowserContextMenu.enableContextMenu();
    super.dispose();
  }

  void _changed() {
    final open = _controller.isOpen;
    if (mounted) setState(() {}); // expanded, a new point
    if (open && widget.disabled) return; // the panel closes it again
    if (open == _wasOpen) return;
    _wasOpen = open;
    // menu.js `_onDocClick`: a click from the keyboard (Enter, Space on the
    // trigger) starts on the first item.
    if (open && _controller._start == _Start.none && widget._mode == _Mode.trigger && _controller._point == null) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      if (keys.contains(LogicalKeyboardKey.enter) ||
          keys.contains(LogicalKeyboardKey.numpadEnter) ||
          keys.contains(LogicalKeyboardKey.space)) {
        _controller._start = _Start.first;
      }
    }
    open ? widget.onOpen?.call() : widget.onClose?.call();
  }

  bool _isChecked(KakaoMenuItem item) => _checks[item] ?? item.checked;

  /// Picks [item]; [siblings] are the radio items it belongs with.
  void _select(KakaoMenuItem item, Iterable<KakaoMenuItem> siblings) {
    final checked = switch (item.type) {
      _ when !item._check => null,
      KakaoMenuItemType.radio => true,
      _ => !_isChecked(item),
    };
    final event = KakaoMenuSelectEvent._(item, checked);
    widget.onSelect?.call(event);
    if (event.defaultPrevented) return;
    if (checked != null) {
      setState(() {
        for (final s in siblings) {
          _checks[s] = false;
        }
        _checks[item] = checked;
      });
    }
    if (widget._mode == _Mode.inline) {
      _inlineKey.currentState?._closeSub();
      return;
    }
    if (checked != null && widget.keepOpen) return;
    _controller.close();
  }

  void _closeAll() => _controller.close();

  KakaoPanelPlacement _placement(KakaoMenuSettings st) {
    if (_controller._point != null) {
      // openAt: the top left corner on the point, flipped to the other side
      // of it when it would leave the screen (menu.js `_placeRoot`).
      return const KakaoPanelPlacement(align: KakaoPanelAlign.start, flip: KakaoPanelFlip.towardMoreRoom);
    }
    final p = widget.placement;
    return KakaoPanelPlacement(
      side: p == KakaoMenuPlacement.topStart || p == KakaoMenuPlacement.topEnd
          ? KakaoPanelSide.top
          : KakaoPanelSide.bottom,
      align: p == KakaoMenuPlacement.bottomEnd || p == KakaoMenuPlacement.topEnd
          ? KakaoPanelAlign.end
          : KakaoPanelAlign.start,
      offset: st.offset,
      flip: KakaoPanelFlip.towardMoreRoom,
      capToRoom: true,
    );
  }

  KeyEventResult _triggerKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || _controller.isOpen || widget.disabled) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    if (keys.isAltPressed || keys.isControlPressed || keys.isMetaPressed) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _controller._openWith(_Start.first);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _controller._openWith(_Start.last);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _contextKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || widget.disabled) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (k == LogicalKeyboardKey.contextMenu || (k == LogicalKeyboardKey.f10 && shift)) {
      _controller._openWith(_Start.first);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openAtPointer(Offset local) {
    if (widget.disabled) return;
    _controller._openWith(_Start.none, local);
  }

  void _setBrowserMenu(bool off) {
    if (!kIsWeb || off == _contextMenuOff) return;
    _contextMenuOff = off;
    off ? BrowserContextMenu.disableContextMenu() : BrowserContextMenu.enableContextMenu();
  }

  @override
  Widget build(BuildContext context) {
    final st = KakaoMenuSettings.of(KakaoTheme.of(context).colors);
    final label = widget.label ?? KakaoMenu.texts.menu;

    if (widget._mode == _Mode.inline) {
      return TapRegion(
        groupId: this,
        onTapOutside: (_) => _inlineKey.currentState?._closeSub(),
        child: _Chrome(
          inline: true,
          child: _MenuPanel(key: _inlineKey, menu: this, items: widget.items, depth: 0, inline: true, label: label),
        ),
      );
    }

    final Widget anchor;
    if (widget._mode == _Mode.trigger) {
      anchor = Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _triggerKey,
        child: Semantics(expanded: _controller.isOpen, child: widget.anchorBuilder!(context, _controller)),
      );
    } else {
      anchor = Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _contextKey,
        child: MouseRegion(
          // The browser's own menu stays away while the pointer is here.
          onEnter: (_) => _setBrowserMenu(true),
          onExit: (_) => _setBrowserMenu(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapUp: (d) => _openAtPointer(d.localPosition),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              supportedDevices: const {PointerDeviceKind.touch, PointerDeviceKind.stylus},
              // kLongPressTimeout is menu.js LONG_PRESS (500 ms).
              onLongPressStart: (d) => _openAtPointer(d.localPosition),
              child: widget.child,
            ),
          ),
        ),
      );
    }

    final start = _controller._start;
    return KakaoAnchoredPanel(
      controller: _controller,
      enabled: !widget.disabled,
      tapRegionGroup: this,
      point: _controller._point,
      placement: _placement(st),
      // `animation: kakao-menu-in var(--_duration) var(--_ease)`: from
      // opacity 0, translateY(-4px) below (4px above).
      motion: KakaoPanelMotion(duration: st.duration, curve: st.ease, slide: 4),
      onDismiss: (_) => _controller._start = _Start.none,
      panelBuilder: (context, side) => _Chrome(
        child: _MenuPanel(
          menu: this,
          items: widget.items,
          depth: 0,
          label: label,
          start: start,
          onStarted: () => _controller._start = _Start.none,
        ),
      ),
      child: anchor,
    );
  }
}

/// `.panel`: background, radius, shadow (with its 1 px ring), min and max
/// width, max height.
class _Chrome extends StatelessWidget {
  const _Chrome({required this.child, this.inline = false});
  final Widget child;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final st = KakaoMenuSettings.of(KakaoTheme.of(context).colors);
    Widget box = DecoratedBox(
      decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(st.radius), boxShadow: st.shadow),
      child: child,
    );
    if (inline) {
      // :host([inline]) .panel: in place, no max height, as wide as allowed.
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: st.minWidth, maxWidth: st.maxWidth),
        child: IntrinsicWidth(child: box),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: st.minWidth, maxWidth: st.maxWidth, maxHeight: st.maxHeight),
      child: IntrinsicWidth(child: box),
    );
  }
}

/// One menu panel (the root or a submenu): its option list, and the
/// submenu open from it.
class _MenuPanel extends StatefulWidget {
  const _MenuPanel({
    super.key,
    required this.menu,
    required this.items,
    required this.depth,
    this.label,
    this.inline = false,
    this.start = _Start.none,
    this.onStarted,
    this.onBack,
  });

  final _KakaoMenuState menu;
  final List<KakaoMenuEntry> items;
  final int depth;
  final String? label;
  final bool inline;
  final _Start start;
  final VoidCallback? onStarted;

  /// Left in a submenu: the parent closes it and takes focus back.
  final VoidCallback? onBack;

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<_MenuPanel> {
  final _list = KakaoOptionListController();
  final _focus = FocusNode(debugLabel: 'KakaoMenu panel');
  final _subs = <int, KakaoAnchoredPanelController>{};
  int? _openSub;
  _Start _subStart = _Start.none;
  int? _lastHighlight;
  Timer? _hoverTimer;

  /// The items in row order, and the radio items each one belongs with.
  late List<(KakaoMenuItem, Object)> _rows;

  @override
  void initState() {
    super.initState();
    _list.addListener(_highlightChanged);
    if (widget.inline) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // menu.js `_show`: focus on the first / last item, else on the panel.
      final start = widget.start;
      _focus.requestFocus();
      if (start == _Start.first) _list.first();
      if (start == _Start.last) _list.last();
      widget.onStarted?.call();
    });
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _list.dispose();
    _focus.dispose();
    for (final c in _subs.values) {
      c.dispose();
    }
    super.dispose();
  }

  KakaoMenuSettings get _st => KakaoMenuSettings.of(KakaoTheme.of(context).colors);

  void _highlightChanged() {
    final h = _list.highlighted;
    if (h == _lastHighlight) return;
    _lastHighlight = h;
    _hoverTimer?.cancel();
    if (_list.keyboard) {
      // menu.js `_move`: moving closes the open submenu.
      if (_openSub != null && _openSub != h) _closeSub();
      return;
    }
    // menu.js `_onPointerMove`: open or close after HOVER_DELAY.
    final item = h == null ? null : _rows[h].$1;
    if (item != null && item.children != null && !item.disabled) {
      if (_openSub != h) _hoverTimer = Timer(_hoverDelay, () => _openSubAt(h!, focus: false));
    } else if (_openSub != null) {
      _hoverTimer = Timer(_hoverDelay, _closeSub);
    }
  }

  void _openSubAt(int i, {required bool focus}) {
    if (!mounted) return;
    _hoverTimer?.cancel();
    if (_openSub != i) {
      _closeSub();
      setState(() {
        _openSub = i;
        _subStart = focus ? _Start.first : _Start.none;
      });
      (_subs[i] ??= KakaoAnchoredPanelController()).open();
    } else if (focus) {
      // Already open (by hover): Right puts focus in it.
      setState(() => _subStart = _Start.first);
      _subKeys[i]?.currentState?._takeFocus();
    }
  }

  final _subKeys = <int, GlobalKey<_MenuPanelState>>{};

  void _takeFocus() {
    _focus.requestFocus();
    if (_list.highlighted == null) _list.first();
  }

  /// Closes the submenu open from here (and its own).
  void _closeSub() {
    _hoverTimer?.cancel();
    final i = _openSub;
    if (i == null) return;
    final c = _subs[i];
    if (c != null && c.isOpen && (_subKeys[i]?.currentState?._focus.hasFocus ?? false)) _focus.requestFocus();
    if (mounted) setState(() => _openSub = null);
    c?.close();
  }

  void _back() {
    _closeSub();
    _focus.requestFocus();
  }

  void _activate(int i) {
    final (item, key) = _rows[i];
    if (item.disabled) return;
    if (item.children != null) {
      // From the keyboard the submenu takes focus; a pointer stays here.
      _openSubAt(i, focus: HardwareKeyboard.instance.logicalKeysPressed.isNotEmpty);
      return;
    }
    final siblings = item.type == KakaoMenuItemType.radio
        ? [
            for (final (other, k) in _rows)
              if (!identical(other, item) && other.type == KakaoMenuItemType.radio && k == key) other,
          ]
        : const <KakaoMenuItem>[];
    widget.menu._select(item, siblings);
  }

  KeyEventResult _onKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final h = _list.highlighted;
    if (k == LogicalKeyboardKey.arrowRight) {
      if (h != null && _rows[h].$1.children != null) _openSubAt(h, focus: true);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      widget.onBack?.call();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.tab) {
      if (widget.inline) {
        _closeSub();
        return KeyEventResult.ignored;
      }
      // Close, and let Tab go on from where the menu was opened.
      final back = HardwareKeyboard.instance.isShiftPressed;
      widget.menu._closeAll();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final f = FocusManager.instance.primaryFocus;
        back ? f?.previousFocus() : f?.nextFocus();
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusChanged(bool on) {
    // A popup menu stays open when focus moves elsewhere by script: Flutter
    // web moves focus when the page itself takes focus, which would close
    // a menu opened before that. Outside taps, Escape and Tab close it.
    if (on) return;
    if (widget.inline) {
      // menu.js focusout on an inline menu: submenus close, no item has focus.
      _closeSub();
      _list.highlight(null);
      return;
    }
  }

  KakaoOptionListStyle _style(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = _st;
    final touch = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => true,
      _ => false,
    };
    return KakaoOptionListStyle(
      text: theme.text(size: st.font.size, color: st.text, height: _itemLineHeight),
      // @media (pointer: coarse): touch-item-height.
      rowMinHeight: touch ? st.touchItemHeight : st.itemHeight,
      rowPadding: EdgeInsets.symmetric(vertical: _itemPaddingY, horizontal: st.itemPaddingX),
      rowRadius: st.itemRadius,
      gap: st.gap,
      trailingGap: st.shortcutGap,
      leadSize: st.iconSize.of(st.font.size),
      highlight: st.hoverBg,
      check: st.check,
      icon: st.icon,
      // .heading: heading-size, heading-weight, muted, the panel's line height.
      heading: theme.text(size: st.headingSize, weight: st.headingWeight, color: st.muted, height: st.font.lineHeight),
      headingPadding: EdgeInsets.fromLTRB(
        st.itemPaddingX,
        _headingPadding.top,
        st.itemPaddingX,
        _headingPadding.bottom,
      ),
      separator: st.line,
      separatorMargin: st.separatorMargin,
      padding: EdgeInsets.all(st.padding),
      duration: st.duration,
      curve: st.ease,
      checkedWeight: st.checkedWeight,
      disabledOpacity: st.disabledOpacity,
      focus: st.focus,
      focusWidth: st.focusWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = _st;
    final menu = widget.menu;
    final rows = <(KakaoMenuItem, Object)>[];

    KakaoOption option(KakaoMenuItem item, Object group) {
      final i = rows.length;
      rows.add((item, item.name != null ? 'n:${item.name}' : group));
      final sub = item.children != null;
      Widget? trailing;
      if (sub) {
        // .arrow: 0.9em, muted, margin-right -0.15em.
        final size = _arrowSize * st.font.size;
        trailing = SizedBox(
          width: size - _arrowPull * st.font.size,
          height: size,
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: size,
            child: SizedBox.square(
              dimension: size,
              child: CustomPaint(painter: _ArrowPainter(st.muted)),
            ),
          ),
        );
      } else if (item.shortcut != null) {
        // .shortcut: muted, shortcut-size, 400, no wrap (plain text: no kakao-kbd yet).
        trailing = Text(
          item.shortcut!,
          softWrap: false,
          style: theme.text(size: st.shortcutSize, color: st.muted, height: _itemLineHeight),
        );
      }
      return KakaoOption(
        label: item.label,
        disabled: item.disabled,
        checked: item._check ? menu._isChecked(item) : null,
        leading: item._check ? null : item.icon,
        trailing: trailing,
        color: item.danger ? st.danger : null,
        role: switch (item.type) {
          _ when !item._check => SemanticsRole.menuItem,
          KakaoMenuItemType.checkbox => SemanticsRole.menuItemCheckbox,
          _ => SemanticsRole.menuItemRadio,
        },
        expanded: sub ? _openSub == i : null,
      );
    }

    final top = Object();
    final entries = <KakaoOptionEntry>[
      for (final e in widget.items)
        switch (e) {
          KakaoMenuItem() => option(e, top),
          KakaoMenuGroup() => () {
            final g = Object();
            return KakaoOptionGroup([for (final i in e.items) option(i, g)], label: e.label);
          }(),
          KakaoMenuSeparator() => const KakaoOptionSeparator(),
        },
    ];
    _rows = rows;

    return KakaoOptionList(
      entries: entries,
      style: _style(context),
      controller: _list,
      focusNode: _focus,
      focusable: widget.inline,
      highlightFirstOnFocus: widget.inline,
      onActivate: _activate,
      onKey: _onKey,
      onFocusChange: _focusChanged,
      semanticsRole: SemanticsRole.menu,
      semanticsLabel: widget.label,
      rowWrapper: (i, row) {
        final item = rows[i].$1;
        final children = item.children;
        if (children == null) return row;
        final key = _subKeys.putIfAbsent(i, GlobalKey<_MenuPanelState>.new);
        return KakaoAnchoredPanel(
          controller: _subs[i] ??= KakaoAnchoredPanelController(),
          tapRegionGroup: menu,
          dismissOnTapOutside: false,
          returnFocus: false,
          // menu.js `_placeSub`: beside the parent menu, level with the item
          // (less the padding), sub-offset away; to the left without room.
          anchorInsets: EdgeInsets.all(st.padding),
          placement: KakaoPanelPlacement(
            side: KakaoPanelSide.right,
            align: KakaoPanelAlign.start,
            offset: st.subOffset,
            flip: KakaoPanelFlip.whenOppositeFits,
          ),
          motion: KakaoPanelMotion(duration: st.duration, curve: st.ease, slide: 4),
          onDismiss: (_) {
            // Escape: back to the item that opened it.
            if (mounted) setState(() => _openSub = null);
            _focus.requestFocus();
          },
          panelBuilder: (context, side) => _Chrome(
            child: _MenuPanel(
              key: key,
              menu: menu,
              items: children,
              depth: widget.depth + 1,
              label: item.label,
              start: _subStart,
              onBack: _back,
            ),
          ),
          child: row,
        );
      },
    );
  }
}

/// `.arrow`: `m6 3.5 4.5 4.5L6 12.5` in a 16 unit box, stroke 1.75, round.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 16;
    canvas.drawPath(
      Path()
        ..moveTo(6 * k, 3.5 * k)
        ..lineTo(10.5 * k, 8 * k)
        ..lineTo(6 * k, 12.5 * k),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.75 * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}
