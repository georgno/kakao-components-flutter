import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_anchored_panel.dart';
import '../internal/kakao_option_list.dart';
import '../settings/kakao_button_settings.g.dart';
import '../theme/kakao_theme.dart';
import 'kakao_corner_scope.dart';
import 'kakao_tooltip.dart';

/// `<kakao-button variant>`.
enum KakaoButtonVariant { primary, secondary, ghost, danger }

/// `<kakao-button size>`.
enum KakaoButtonSize { sm, md, lg }

/// One size's values from the generated settings (`--kakao-button-<size>-*`).
class _Size {
  const _Size(this.height, this.paddingX, this.fontSize, this.radius, this.gap);
  final double height, paddingX, fontSize, radius, gap;

  factory _Size.of(KakaoButtonSettings st, KakaoButtonSize size) => switch (size) {
    KakaoButtonSize.sm => _Size(st.smHeight, st.smPaddingX, st.smFontSize, st.smRadius, st.smGap),
    KakaoButtonSize.md => _Size(st.mdHeight, st.mdPaddingX, st.mdFontSize, st.mdRadius, st.mdGap),
    KakaoButtonSize.lg => _Size(st.lgHeight, st.lgPaddingX, st.lgFontSize, st.lgRadius, st.lgGap),
  };
}

/// Makes the [KakaoButton]s below it fill the width they get (the dialog's
/// full-width footer sets the inner button to width: 100% the same way).
class KakaoButtonStretch extends InheritedWidget {
  const KakaoButtonStretch({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<KakaoButtonStretch>() != null;

  @override
  bool updateShouldNotify(KakaoButtonStretch oldWidget) => false;
}

/// An item of a menu button's `list-data`: `{ value, label, disabled }`.
@immutable
class KakaoButtonMenuItem {
  const KakaoButtonMenuItem(this.value, {String? label, this.disabled = false}) : label = label ?? value;

  final String value;

  /// Shown in the menu (and on the button with `showSelected`); default: [value].
  final String label;

  /// Shown dimmed, cannot be picked, skipped by the keys.
  final bool disabled;
}

/// `kakao-button-select`: a menu item was picked.
@immutable
class KakaoButtonSelectEvent {
  const KakaoButtonSelectEvent._(this.value, this.label, this.previous, this.position);

  final String value;
  final String label;

  /// The value selected before, if any.
  final String? previous;

  /// Where the pick happened, in global coordinates: the pointer, or the
  /// middle of the item when it was picked with the keyboard (`x`, `y`: for
  /// effects that start there).
  final Offset position;
}

/// Opens and closes a menu button's menu (`openMenu()`, `closeMenu()`).
class KakaoButtonMenuController extends KakaoAnchoredPanelController {}

/// Groups toggle [KakaoButton]s into a segmented control
/// (`.kakao-button-segment`): a tray in `--kakao-button-segment-bg` with
/// `segment-padding` around and `segment-gap` between the items, the outer
/// radius `segment-radius` and the items' `segment-item-radius` (nested
/// radius = outer radius − padding).
///
/// Inside it a button draws as a segment item: transparent at rest, in ink,
/// [KakaoButtonSettings.segmentItemSize] tall and, as an icon button, as wide
/// as its size is tall (the web's icon-only width rule outranks the
/// segment's 38 px; a labelled item keeps its size's side padding, where the
/// web CSS lets the label overflow 38 px), its variant's hover background on hover (with light
/// ink on the dark primary and danger ones), `segment-pressed-bg` when
/// [KakaoButton.pressed], without shadows. An item that becomes pressed shows
/// `segment-pressed-shadow` once: it fades in over the first quarter of
/// `segment-settle-duration` and out over the rest (none with reduced
/// motion). Toggles keep their opacity and weight.
///
/// The group does not make the toggles exclusive by itself: as on the web
/// demo, the owner presses one and releases the others in `onPressed`.
class KakaoButtonSegment extends StatelessWidget {
  const KakaoButtonSegment({super.key, required this.children, this.semanticLabel});

  final List<Widget> children;

  /// The group's accessible name.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final st = KakaoButtonSettings.of(KakaoTheme.of(context).colors);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(color: st.segmentBg, borderRadius: BorderRadius.circular(st.segmentRadius)),
        child: Padding(
          padding: EdgeInsets.all(st.segmentPadding),
          child: _SegmentScope(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(width: st.segmentGap), children[i]],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentScope extends InheritedWidget {
  const _SegmentScope({required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_SegmentScope>() != null;

  @override
  bool updateShouldNotify(_SegmentScope oldWidget) => false;
}

/// The CSS `transition: … ease` the button uses with its --kakao-button-transition.
const _ease = Curves.ease;

// button.js easings.
const _bounce = Cubic(0.34, 1.3, 0.64, 1); // BOUNCE
const _soft = Cubic(0.25, 1.0, 0.5, 1); // SOFT

// button.js / button.css values outside the settings block.
const _menuEntry = Duration(milliseconds: 180); // openMenu: animate(…, { duration: 180, easing: BOUNCE })
const _menuEntryScale = .97; // openMenu: scale(0.97)
const _menuEntrySlide = 4.0; // --_menu-from: -4px (4px when it opens upwards)
const _menuTypeAheadReset = Duration(milliseconds: 700); // _onMenuKey: now - _typedAt > 700
const _menuItemPadding = (left: 9.6, right: 13.6); // .kakao-button-menu-item padding: 0 0.85rem 0 0.6rem
const _menuItemGap = 8.8; // .kakao-button-menu-item gap: 0.55rem
const _menuCheckSize = 1.1; // .kakao-button-menu-check width: 1.1em
const _menuCheckedWeight = 600.0; // .kakao-button-menu-item[aria-checked="true"]
const _menuFocusWidth = 2.0; // .kakao-button-menu-item:focus-visible outline: 2px, offset -2px
const _pageLineHeight = 1.5; // the menu inherits the page's line height (demo.css body: 1.5)
const _chevronPull = .2; // .kakao-button-chevron margin-right: -0.2em
const _pillPadding = (left: .95, right: .85); // icon-only menu button: padding 0 0.85em 0 0.95em
const _settlePeak = .25; // @keyframes kakao-button-segment-settle: the shadow peaks at 25%

/// Flutter twin of `<kakao-button>`: same variants, sizes, colours and motion.
///
/// Motion as in button.js:
/// - press squash: scale to 0.94 on touch down (110 ms, soft), springs back
///   (220 ms, bounce);
/// - loading: the label shrinks and fades out, the spinner pops in;
/// - [onPressedAsync]: loading while the future runs, then the success check
///   for 900 ms (or straight back to the label when it fails), like `run()`.
///
/// [toggle] makes it a toggle button (`toggle` / `pressed` on the web): off
/// it is dimmed to 0.45 at weight 400, [pressed] it is full at weight 600,
/// so the state never depends on colour alone. Tapping calls [onPressed];
/// the owner flips [pressed].
///
/// Pass neither callback for the disabled state. An [icon] without a [label]
/// gives the round icon-only button; give it a [semanticLabel], which also
/// shows as its tooltip. [tooltip] is the web's `title`: a themed tooltip
/// on any button. In a [KakaoButtonSegment] it draws as a segment item.
///
/// Menu form (`list-data`): with [menu], any variant and size becomes a
/// dropdown button with a trailing chevron (0.9 em, turning over when open,
/// `--kakao-button-transition` on button.js BOUNCE). [selected] is the
/// checked item; the button keeps the pick from then on, as the web one
/// does, and takes a new [selected] from its owner. [showSelected] shows the
/// selected item's label instead of [label] (which then names the menu:
/// "Sort by: Newest first"). [noChevron] hides the chevron; an icon-only
/// dropdown is then round, else a pill that shows the chevron. Pass
/// [onSelect] to enable it.
///
/// The menu, as button.js draws it from the `--kakao-button-menu-*`
/// settings: below the button, [KakaoButtonSettings.menuOffset] away, at
/// least as wide as the button and `menu-min-width`; above it when there is
/// no room below and more above; lined up with the button's right edge when
/// it would run off the right side. It fades in from 4 px back and 97 % size
/// over 180 ms (BOUNCE), and closes at once. It opens on the checked item
/// (on the last one with Up). Keys: Down / Up open it; in it Up / Down /
/// Home / End move (skipping disabled items), a letter jumps, Enter / Space
/// pick, Escape closes with focus back on the button, Tab closes and moves
/// on. A pick, or a pointer down outside, closes it.
///
/// A theme picker (`<kakao-button theme-picker>`) is this plus the theme:
/// set the theme in [onMenuHover] (the page follows the pointer down the
/// list) and in [onSelect]; [KakaoTheme] cross-fades it.
class KakaoButton extends StatefulWidget {
  const KakaoButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.onPressedAsync,
    this.variant = KakaoButtonVariant.primary,
    this.size = KakaoButtonSize.md,
    this.loading = false,
    this.successHold = const Duration(milliseconds: 900),
    this.semanticLabel,
    this.tooltip,
    this.toggle = false,
    this.pressed = false,
    this.menu,
    this.selected,
    this.showSelected = false,
    this.noChevron = false,
    this.onSelect,
    this.onMenuChanged,
    this.onMenuHover,
    this.menuController,
    this.menuKey,
  }) : assert(label != null || icon != null, 'A button needs a label or an icon'),
       assert(onPressed == null || onPressedAsync == null, 'Pass onPressed or onPressedAsync, not both'),
       assert(menu == null || (onPressed == null && onPressedAsync == null), 'A menu button reports onSelect');

  final String? label;
  final Widget? icon;
  final VoidCallback? onPressed;

  /// Runs the button's loading → success / fail animation around the future.
  final Future<void> Function()? onPressedAsync;
  final KakaoButtonVariant variant;
  final KakaoButtonSize size;

  /// Shows the spinner (for loading driven from outside).
  final bool loading;

  /// How long the success check stays (`run(…, { successHold })`).
  final Duration successHold;
  final String? semanticLabel;

  /// The web's `title`: shown as a [KakaoTooltip]. Empty turns off the
  /// icon-only button's automatic one (`title=""`).
  final String? tooltip;

  /// Toggle button (`toggle`), currently [pressed] or not.
  final bool toggle;
  final bool pressed;

  /// `list-data`: the menu's items. Empty or null: not a menu button.
  final List<KakaoButtonMenuItem>? menu;

  /// `selected`: the value of the checked item.
  final String? selected;

  /// `show-selected`.
  final bool showSelected;

  /// `no-chevron`.
  final bool noChevron;

  /// `kakao-button-select`.
  final ValueChanged<KakaoButtonSelectEvent>? onSelect;

  /// `kakao-button-menu`: the menu opened (true) or closed.
  final ValueChanged<bool>? onMenuChanged;

  /// `kakao-button-menu-hover`: the mouse moved onto another enabled item
  /// (not keys or taps). Again after the pointer left the menu or it reopened.
  final ValueChanged<KakaoButtonMenuItem>? onMenuHover;

  /// Opens and closes the menu from outside.
  final KakaoButtonMenuController? menuController;

  /// Put on the open menu's panel (tests, screenshots).
  final Key? menuKey;

  /// `KakaoButton.texts`: the menu's default accessible name.
  static ({String menu}) texts = (menu: 'Menu');

  @override
  State<KakaoButton> createState() => _KakaoButtonState();
}

enum _Overlay { none, spinner, check }

class _KakaoButtonState extends State<KakaoButton> with TickerProviderStateMixin {
  KakaoCornerRegistry? _corners;
  bool _hover = false;
  bool _focusVisible = false;
  bool _running = false; // onPressedAsync in flight or showing its result
  _Overlay _overlay = _Overlay.none;

  late final _press = AnimationController(vsync: this, value: 1, lowerBound: 0, upperBound: 2);
  late final _content = AnimationController(vsync: this, value: 1, upperBound: 2);
  late final _spinner = AnimationController(vsync: this, value: 0, upperBound: 2);
  late final _check = AnimationController(vsync: this, value: 0, upperBound: 2);
  double _checkFrom = .7; // the check grows from .7, leaves towards .85
  final _timers = <Timer>[];

  // Segment item: the settling shadow.
  late final _settle = AnimationController(vsync: this);

  // Menu form.
  KakaoButtonMenuController? _ownMenu;
  KakaoAnchoredPanelController get _menuCtl => widget.menuController ?? (_ownMenu ??= KakaoButtonMenuController());
  String? _selected;
  bool _menuOpen = false;
  bool _openOnLast = false;
  bool _openByKeys = false;
  double _anchorWidth = 0;

  bool get _isMenu => widget.menu?.isNotEmpty ?? false;
  bool get _hasAction =>
      widget.onPressed != null || widget.onPressedAsync != null || (_isMenu && widget.onSelect != null);
  bool get _busy => widget.loading || _running;
  bool get _enabled => _hasAction && !_busy;
  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _menuCtl.addListener(_menuChanged);
    if (widget.loading) {
      _content.value = 0;
      _spinner.value = 1;
      _overlay = _Overlay.spinner;
    }
  }

  @override
  void didUpdateWidget(KakaoButton old) {
    super.didUpdateWidget(old);
    if (widget.loading != old.loading && !_running) {
      widget.loading ? _startLoading() : _finishLoading(success: false);
    }
    if (widget.selected != old.selected) _selected = widget.selected;
    final before = old.menuController ?? _ownMenu;
    if (before != _menuCtl) {
      before?.removeListener(_menuChanged);
      _menuCtl.addListener(_menuChanged);
    }
    // Newly pressed in a segment: the brief settle shadow (button.js
    // attributeChangedCallback adds kakao-button-settling).
    if (widget.pressed && !old.pressed && context.getInheritedWidgetOfExactType<_SegmentScope>() != null) {
      if (_reduceMotion) return;
      _settle.duration = KakaoButtonSettings.of(KakaoTheme.of(context).colors).segmentSettleDuration;
      _settle.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _corners?.remove(this);
    for (final t in _timers) {
      t.cancel();
    }
    (widget.menuController ?? _ownMenu)?.removeListener(_menuChanged);
    _ownMenu?.dispose();
    _settle.dispose();
    _press.dispose();
    _content.dispose();
    _spinner.dispose();
    _check.dispose();
    super.dispose();
  }

  void _after(Duration d, VoidCallback f) {
    _timers.add(
      Timer(d, () {
        if (mounted) f();
      }),
    );
  }

  Duration _ms(int ms) => Duration(milliseconds: _reduceMotion ? 1 : ms);

  // ---- press squash, interruption-safe (animates from the current scale) ----
  void _animatePress(double target) {
    if (_reduceMotion) {
      _press.value = target;
      return;
    }
    final down = target < 1;
    _press.animateTo(
      target,
      duration: Duration(milliseconds: down ? 110 : 220),
      curve: down ? _soft : _bounce,
    );
  }

  // ---- loading / success, as _startLoading / _finishLoading in button.js ----
  void _startLoading() {
    setState(() => _overlay = _Overlay.spinner);
    _content.animateTo(0, duration: _ms(180), curve: _soft);
    _spinner.value = 0;
    _after(_ms(54), () => _spinner.animateTo(1, duration: _ms(180), curve: _bounce));
  }

  /// Removes an overlay once it has faded out, so a hidden spinner stops ticking.
  void _dropOverlay(_Overlay which, TickerFuture faded) {
    faded.whenCompleteOrCancel(() {
      if (mounted && _overlay == which) setState(() => _overlay = _Overlay.none);
    });
  }

  void _finishLoading({required bool success}) {
    final spinnerOut = _spinner.animateTo(0, duration: _ms(160), curve: _soft);
    if (success) {
      setState(() {
        _overlay = _Overlay.check;
        _checkFrom = .7;
      });
      _check.value = 0;
      _after(_ms(48), () => _check.animateTo(1, duration: _ms(160), curve: _bounce));
      _after(widget.successHold, () {
        setState(() => _checkFrom = .85);
        _dropOverlay(_Overlay.check, _check.animateTo(0, duration: _ms(160), curve: _soft));
        _content.animateTo(1, duration: _ms(220), curve: _bounce);
        _running = false;
      });
    } else {
      _dropOverlay(_Overlay.spinner, spinnerOut);
      _after(_ms(160), () => _content.animateTo(1, duration: _ms(220), curve: _bounce));
      _running = false;
    }
  }

  // ---- menu form ----
  void _menuChanged() {
    final open = _menuCtl.isOpen;
    if (!mounted || open == _menuOpen) return;
    if (open && !(_isMenu && _enabled)) return; // the panel closes it again
    if (open) {
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize) _anchorWidth = box.size.width;
      // A click from the keyboard (Enter, Space) shows the focus ring in the menu.
      _openByKeys = _openByKeys || HardwareKeyboard.instance.logicalKeysPressed.isNotEmpty;
    } else {
      _openOnLast = false;
      _openByKeys = false;
    }
    setState(() => _menuOpen = open);
    widget.onMenuChanged?.call(open);
  }

  void _openMenu({required bool last}) {
    if (!_isMenu || !_enabled || _menuCtl.isOpen) return;
    _openOnLast = last;
    _openByKeys = true;
    _menuCtl.open();
  }

  void _pick(KakaoButtonMenuItem item, Offset position) {
    if (item.disabled) return;
    final previous = _selected;
    setState(() => _selected = item.value);
    _menuCtl.close();
    widget.onSelect?.call(KakaoButtonSelectEvent._(item.value, item.label, previous, position));
  }

  KakaoButtonMenuItem? get _selectedItem {
    for (final it in widget.menu ?? const <KakaoButtonMenuItem>[]) {
      if (it.value == _selected) return it;
    }
    return null;
  }

  Future<void> _activate() async {
    if (!_enabled) return;
    if (_isMenu) {
      _menuCtl.toggle();
      return;
    }
    if (widget.onPressedAsync == null) {
      widget.onPressed?.call();
      return;
    }
    setState(() => _running = true);
    _startLoading();
    var ok = true;
    try {
      await widget.onPressedAsync!();
    } on Object {
      ok = false;
    }
    if (mounted) setState(() => _finishLoading(success: ok));
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoButtonSettings.of(theme.colors);
    final s = _Size.of(st, widget.size);
    final iconOnly = widget.label == null;
    final segment = _SegmentScope.of(context);
    final isMenu = _isMenu;
    final chevron = isMenu && !widget.noChevron;
    // An icon-only menu button becomes a pill so the chevron shows.
    final pill = iconOnly && chevron && !segment;
    final shownItem = isMenu && widget.showSelected ? _selectedItem : null;
    final shownLabel = shownItem?.label ?? widget.label;
    final reduce = _reduceMotion;

    // Colours per variant: the generated --kakao-button-<variant>-* settings.
    // A ghost button has no fill at rest (transparent ink, so hover blends from ink).
    var (Color bg, Color hoverBg, Color fg, Color ring, List<BoxShadow> shadow) = switch (widget.variant) {
      KakaoButtonVariant.primary => (st.primaryBg, st.primaryHoverBg, st.primaryText, st.primaryRing, st.primaryShadow),
      KakaoButtonVariant.secondary => (
        st.secondaryBg,
        st.secondaryHoverBg,
        st.secondaryText,
        st.secondaryRing,
        const <BoxShadow>[],
      ),
      KakaoButtonVariant.ghost => (
        st.ink.withValues(alpha: 0),
        st.ghostHoverBg,
        st.ghostText,
        st.ghostRing,
        const <BoxShadow>[],
      ),
      KakaoButtonVariant.danger => (st.dangerBg, st.dangerHoverBg, st.dangerText, st.dangerRing, st.dangerShadow),
    };
    var hoverFg = fg;
    if (segment) {
      // .kakao-button-segment kakao-button: transparent, ink, no shadow, the
      // secondary ring; the variant's hover background still applies, with
      // light ink on the dark ones; pressed: segment-pressed-bg.
      final variantHoverFg = switch (widget.variant) {
        KakaoButtonVariant.primary => st.primaryText,
        KakaoButtonVariant.danger => st.dangerText,
        _ => st.ink,
      };
      bg = widget.pressed ? st.segmentPressedBg : hoverBg.withValues(alpha: 0);
      hoverBg = widget.pressed ? st.segmentPressedBg : hoverBg;
      fg = st.ink;
      hoverFg = widget.pressed ? st.ink : variantHoverFg;
      ring = st.secondaryRing;
      shadow = const [];
    }
    final hovering = _enabled && _hover;
    final ink = hovering ? hoverFg : fg;
    // Focus halo: box-shadow 0 0 0 <focus-ring-width> <ring>, in place of the rest shadow.
    final shadows = _focusVisible ? [BoxShadow(color: ring, spreadRadius: st.focusRingWidth)] : shadow;

    // Toggles show their state with weight as well: 400 off, 600 pressed.
    final weight = widget.toggle ? (widget.pressed ? 600.0 : 400.0) : st.labelWeight;
    final textStyle = theme
        .text(size: s.fontSize, weight: weight, color: ink)
        .copyWith(letterSpacing: -0.01 * s.fontSize, height: 1);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null)
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: ink),
            duration: st.transition,
            curve: _ease,
            builder: (context, color, child) => IconTheme(
              data: IconThemeData(color: color, size: s.fontSize * .95),
              child: child!,
            ),
            child: widget.icon,
          ),
        if (widget.icon != null && !iconOnly) SizedBox(width: s.gap),
        if (!iconOnly)
          AnimatedDefaultTextStyle(
            style: textStyle,
            duration: st.transition,
            curve: _ease,
            child: Text(shownLabel!, maxLines: 1, softWrap: false),
          ),
      ],
    );

    Widget body = _ScaleFade(controller: _content, from: .9, child: content);
    if (chevron) {
      // .kakao-button-chevron: chevron-size, after the flex gap, margin-right
      // -0.2em; turned over while the menu is open.
      final size = st.chevronSize.of(s.fontSize);
      body = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          body,
          SizedBox(width: s.gap),
          SizedBox(
            width: size - _chevronPull * s.fontSize,
            height: size,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: size,
              child: AnimatedRotation(
                turns: _menuOpen ? .5 : 0,
                duration: reduce ? Duration.zero : st.transition,
                curve: _bounce,
                child: CustomPaint(size: Size.square(size), painter: _ChevronPainter(ink)),
              ),
            ),
          ),
        ],
      );
    }

    // The label keeps its place while hidden, so the width stays put
    // (button.js locks the width the same way).
    final layers = Stack(
      alignment: Alignment.center,
      children: [
        body,
        if (_overlay == _Overlay.spinner)
          _ScaleFade(
            controller: _spinner,
            from: .85,
            child: _Spinner(color: ink, size: st.spinnerSize, still: reduce),
          ),
        if (_overlay == _Overlay.check)
          _ScaleFade(
            controller: _check,
            from: _checkFrom,
            child: CustomPaint(size: Size.square(st.spinnerSize), painter: _CheckPainter(ink)),
          ),
      ],
    );

    final double height;
    final double? width;
    final EdgeInsets padding;
    final double radius;
    if (segment) {
      // segment-item-size tall; an icon item keeps its size's width (on the
      // web the icon-only width rule outranks the segment's square).
      height = st.segmentItemSize;
      width = iconOnly ? s.height : null;
      padding = EdgeInsets.symmetric(horizontal: iconOnly ? 0 : s.paddingX);
      radius = st.segmentItemRadius;
    } else if (pill) {
      height = s.height;
      width = null;
      padding = EdgeInsets.only(left: _pillPadding.left * s.fontSize, right: _pillPadding.right * s.fontSize);
      radius = s.height / 2; // --kakao-radius-pill
    } else if (iconOnly) {
      height = s.height;
      width = s.height;
      padding = EdgeInsets.zero;
      radius = s.height / 2;
    } else {
      height = s.height;
      width = KakaoButtonStretch.of(context) ? double.infinity : null;
      padding = EdgeInsets.symmetric(horizontal: s.paddingX);
      radius = s.radius;
    }

    Widget box = AnimatedContainer(
      duration: st.transition,
      curve: _ease,
      height: height,
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: hovering ? hoverBg : bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
      ),
      child: layers,
    );

    if (segment) {
      // @keyframes kakao-button-segment-settle (ease-out per keyframe): from
      // no shadow to segment-pressed-shadow at 25 %, back to none at 100 %.
      box = AnimatedBuilder(
        animation: _settle,
        builder: (context, child) {
          final t = _settle.value;
          final k = !_settle.isAnimating || !widget.pressed
              ? 0.0
              : t < _settlePeak
              ? Curves.easeOut.transform(t / _settlePeak)
              : 1 - Curves.easeOut.transform((t - _settlePeak) / (1 - _settlePeak));
          if (k <= 0) return child!;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                for (final b in st.segmentPressedShadow)
                  BoxShadow(
                    color: b.color.withValues(alpha: b.color.a * k),
                    offset: b.offset * k,
                    blurRadius: b.blurRadius * k,
                    spreadRadius: b.spreadRadius * k,
                  ),
              ],
            ),
            child: child,
          );
        },
        child: box,
      );
    }

    box = ScaleTransition(scale: _press, child: box);

    box = AnimatedOpacity(
      opacity: !_hasAction
          ? st.disabledOpacity
          : (widget.toggle && !widget.pressed)
          ? st.toggleOffOpacity
          : 1,
      duration: st.transition,
      curve: _ease,
      child: box,
    );

    // In a dialog footer: tell the dialog where this button is and how round
    // its corners are, so a corner it sits in can follow it (nesting rule).
    _corners = KakaoCornerScope.maybeOf(context);
    _corners?.put(
      this,
      KakaoCornerEntry(
        context: context,
        filled: widget.variant != KakaoButtonVariant.ghost && !segment,
        radius: radius,
      ),
    );

    // The accessible name: own, else "<label>: <item>" with showSelected,
    // else the shown text.
    final name =
        widget.semanticLabel ??
        (shownItem != null && widget.label != null ? '${widget.label}: ${shownItem.label}' : shownLabel);
    final tip = widget.tooltip ?? (iconOnly ? widget.semanticLabel : null);
    Widget button = Semantics(
      button: true,
      enabled: _enabled,
      toggled: widget.toggle ? widget.pressed : null,
      expanded: isMenu ? _menuOpen : null,
      label: name,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _hasAction,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        // Down / Up on a menu button open the menu (on the checked / last item).
        shortcuts: isMenu ? _menuShortcuts : const {},
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activate()),
          _OpenMenuIntent: CallbackAction<_OpenMenuIntent>(onInvoke: (i) => _openMenu(last: i.last)),
        },
        child: Listener(
          // Pointer events, like button.js: the squash starts on touch down,
          // before the tap is recognised.
          onPointerDown: (_) {
            if (_enabled) _animatePress(.94);
          },
          onPointerUp: (_) => _animatePress(1),
          onPointerCancel: (_) => _animatePress(1),
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _enabled ? _activate : null, child: box),
        ),
      ),
    );
    if (tip != null && tip.isNotEmpty) button = KakaoTooltip(message: tip, child: button);
    if (!isMenu) return button;

    return KakaoAnchoredPanel(
      controller: _menuCtl,
      enabled: _enabled,
      // button.js openMenu / _placeMenuX: below, menu-offset away, from the
      // button's left edge (its right edge without room, else pushed 8 px
      // inside); above when there is no room below and more above.
      placement: KakaoPanelPlacement(
        side: KakaoPanelSide.bottom,
        align: KakaoPanelAlign.start,
        offset: st.menuOffset,
        flip: KakaoPanelFlip.towardMoreRoom,
      ),
      motion: const KakaoPanelMotion(
        duration: _menuEntry,
        curve: _bounce,
        slide: _menuEntrySlide,
        scale: _menuEntryScale,
      ),
      panelBuilder: (context, side) => _ButtonMenu(
        key: widget.menuKey,
        items: widget.menu!,
        selected: _selected,
        last: _openOnLast,
        keyboard: _openByKeys,
        minWidth: _anchorWidth,
        label: widget.label ?? widget.semanticLabel ?? KakaoButton.texts.menu,
        onPick: _pick,
        onHover: widget.onMenuHover,
        onClose: _menuCtl.close,
      ),
      child: button,
    );
  }
}

const _menuShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.arrowDown): _OpenMenuIntent(last: false),
  SingleActivator(LogicalKeyboardKey.arrowUp): _OpenMenuIntent(last: true),
};

class _OpenMenuIntent extends Intent {
  const _OpenMenuIntent({required this.last});
  final bool last;
}

/// The open menu of a menu button: `.kakao-button-menu` and its
/// `menuitemradio` rows, on the shared option list.
class _ButtonMenu extends StatefulWidget {
  const _ButtonMenu({
    super.key,
    required this.items,
    required this.selected,
    required this.last,
    required this.keyboard,
    required this.minWidth,
    required this.label,
    required this.onPick,
    required this.onHover,
    required this.onClose,
  });

  final List<KakaoButtonMenuItem> items;
  final String? selected;

  /// Start on the last item (Up), else on the checked one.
  final bool last;

  /// Opened from the keyboard: the start item shows the focus ring.
  final bool keyboard;

  /// The button's width.
  final double minWidth;
  final String label;
  final void Function(KakaoButtonMenuItem item, Offset position) onPick;
  final ValueChanged<KakaoButtonMenuItem>? onHover;
  final VoidCallback onClose;

  @override
  State<_ButtonMenu> createState() => _ButtonMenuState();
}

class _ButtonMenuState extends State<_ButtonMenu> {
  final _list = KakaoOptionListController(typeAheadReset: _menuTypeAheadReset);
  final _focus = FocusNode(debugLabel: 'KakaoButton menu');
  final _rowKeys = <int, GlobalKey>{};
  Offset? _pointer;
  int _hovered = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // button.js openMenu: focus on the last item (Up), else the checked
      // one, else the first; disabled items are skipped.
      _focus.requestFocus();
      final items = widget.items;
      final on = [
        for (var i = 0; i < items.length; i++)
          if (!items[i].disabled) i,
      ];
      if (on.isEmpty) return;
      final checked = on.where((i) => items[i].value == widget.selected);
      final start = widget.last ? on.last : (checked.isEmpty ? on.first : checked.first);
      _list.highlight(start, keyboard: widget.keyboard);
    });
  }

  @override
  void dispose() {
    _list.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// `_reportHover`: once per item the mouse moves onto.
  void _reportHover() {
    if (!mounted || _list.keyboard) return;
    final h = _list.highlighted ?? -1;
    if (h == _hovered) return;
    _hovered = h;
    if (h >= 0) widget.onHover?.call(widget.items[h]);
  }

  void _activate(int i) {
    final item = widget.items[i];
    final keys = HardwareKeyboard.instance.logicalKeysPressed.isNotEmpty;
    var at = _pointer;
    if (keys || at == null) {
      final box = _rowKeys[i]?.currentContext?.findRenderObject();
      at = box is RenderBox && box.hasSize ? box.localToGlobal(box.size.center(Offset.zero)) : Offset.zero;
    }
    widget.onPick(item, at);
  }

  KeyEventResult _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.tab) return KeyEventResult.ignored;
    // Tab closes, and focus goes on from the button.
    final back = HardwareKeyboard.instance.isShiftPressed;
    widget.onClose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final f = FocusManager.instance.primaryFocus;
      back ? f?.previousFocus() : f?.nextFocus();
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoButtonSettings.of(theme.colors);
    // .kakao-button-menu: the button font at md-font-size, menu-text.
    final text = theme.text(size: st.mdFontSize, color: st.menuText, height: _pageLineHeight);
    final style = KakaoOptionListStyle(
      text: text,
      rowMinHeight: st.menuItemHeight,
      rowPadding: EdgeInsets.only(left: _menuItemPadding.left, right: _menuItemPadding.right),
      rowRadius: st.menuItemRadius,
      gap: _menuItemGap,
      trailingGap: 0,
      leadSize: _menuCheckSize * st.mdFontSize,
      highlight: st.menuHoverBg,
      check: st.menuCheck,
      icon: st.menuText,
      // No headings or separators in a button menu.
      heading: text,
      headingPadding: EdgeInsets.zero,
      separator: st.menuBorder,
      separatorMargin: 0,
      padding: EdgeInsets.all(st.menuPadding),
      // The items have no transition.
      duration: Duration.zero,
      curve: Curves.linear,
      checkedWeight: _menuCheckedWeight,
      disabledOpacity: st.disabledOpacity,
      focus: st.menuFocus,
      focusWidth: _menuFocusWidth,
    );
    final entries = [
      for (final it in widget.items)
        KakaoOption(
          label: it.label,
          disabled: it.disabled,
          checked: it.value == widget.selected,
          role: SemanticsRole.menuItemRadio,
        ),
    ];

    return ConstrainedBox(
      // min-width: max(100%, menu-min-width).
      constraints: BoxConstraints(minWidth: math.max(widget.minWidth, st.menuMinWidth)),
      child: IntrinsicWidth(
        child: Container(
          decoration: BoxDecoration(
            color: st.menuBg,
            border: Border.all(color: st.menuBorder),
            borderRadius: BorderRadius.circular(st.menuRadius),
            boxShadow: st.menuShadow,
          ),
          child: Listener(
            onPointerDown: (e) => _pointer = e.position,
            onPointerUp: (e) => _pointer = e.position,
            child: MouseRegion(
              // The row under the pointer is highlighted by the list first.
              onHover: (_) => scheduleMicrotask(_reportHover),
              onExit: (_) => _hovered = -1,
              child: KakaoOptionList(
                entries: entries,
                style: style,
                controller: _list,
                focusNode: _focus,
                onActivate: _activate,
                onKey: _onKey,
                semanticsRole: SemanticsRole.menu,
                semanticsLabel: widget.label,
                rowWrapper: (i, row) => KeyedSubtree(key: _rowKeys.putIfAbsent(i, GlobalKey.new), child: row),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// button.js CHEVRON: `M6 9l6 6 6-6` in a 24 box, stroke 2.4, round.
class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.drawPath(
      Path()
        ..moveTo(6 * k, 9 * k)
        ..lineTo(12 * k, 15 * k)
        ..lineTo(18 * k, 9 * k),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}

/// Opacity and scale driven by one 0..1 value (overshoot only scales).
class _ScaleFade extends AnimatedWidget {
  const _ScaleFade({required AnimationController controller, required this.from, required this.child})
    : super(listenable: controller);

  final double from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = (listenable as AnimationController).value;
    return Opacity(
      opacity: v.clamp(0.0, 1.0),
      child: Transform.scale(scale: from + (1 - from) * v, child: child),
    );
  }
}

/// The loading arc: r 9 in a 24 box, stroke 3, dash 42 of 56.55, one turn
/// per 0.85 s. With reduced motion it stands still and pulses instead
/// (opacity .4 ↔ 1, 1.1 s ease-in-out), as kakao-button-pulse.
class _Spinner extends StatefulWidget {
  const _Spinner({required this.color, required this.size, required this.still});
  final Color color;
  final double size;
  final bool still;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(_Spinner old) {
    super.didUpdateWidget(old);
    if (old.still != widget.still) _run();
  }

  void _run() {
    _c.duration = Duration(milliseconds: widget.still ? 1100 : 850);
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arc = CustomPaint(size: Size.square(widget.size), painter: _ArcPainter(widget.color));
    if (widget.still) {
      return AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = Curves.easeInOut.transform(_c.value < .5 ? _c.value * 2 : (1 - _c.value) * 2);
          return Opacity(opacity: .4 + .6 * t, child: child);
        },
        child: arc,
      );
    }
    return RotationTransition(turns: _c, child: arc);
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = Paint()
      ..color = color.withValues(alpha: color.a * .9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * k
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 9 * k);
    // SVG circles start at 3 o'clock; 42 / 56.55 of the circumference.
    canvas.drawArc(rect, 0, 2 * math.pi * 42 / 56.55, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}

/// button.js CHECK: `M5 12.5l4.5 4.5L19 7.5` in a 24 box, stroke 2.6, round.
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(5 * k, 12.5 * k)
      ..lineTo(9.5 * k, 17 * k)
      ..lineTo(19 * k, 7.5 * k);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color;
}
