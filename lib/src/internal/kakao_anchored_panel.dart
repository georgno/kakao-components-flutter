// The anchored panel: the building block under popover, menu, the button's
// menu mode, select, combobox, multi-dropdown and the date pickers. Not
// exported; each public widget feeds it the values of its own web settings
// block (offset, motion, flip rule), so two widgets on it can differ where
// their web twins do.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The side of the anchor a panel sits on.
enum KakaoPanelSide {
  top,
  bottom,
  left,
  right;

  KakaoPanelSide get opposite => switch (this) {
    top => bottom,
    bottom => top,
    left => right,
    right => left,
  };

  /// Above or below the anchor (the panel moves along y).
  bool get isVertical => this == top || this == bottom;
}

/// Where the panel lines up along the anchor's other axis.
enum KakaoPanelAlign {
  /// Centred on the anchor (popover.js).
  center,

  /// Its left (top) edge on the anchor's; if it would leave the screen, its
  /// right (bottom) edge on the anchor's, else pushed inside (menu.js
  /// `bottom-start`, select.js).
  start,

  /// Its right (bottom) edge on the anchor's; else its left edge, else
  /// pushed inside (menu.js `bottom-end`).
  end,
}

/// When the panel goes to the other side of the anchor.
enum KakaoPanelFlip {
  /// Never.
  none,

  /// When it doesn't fit on its side and does fit on the other
  /// (popover.js `reposition`).
  whenOppositeFits,

  /// When it doesn't fit on its side and the other side has more room
  /// (menu.js `_placeRoot`, select.js `_place`).
  towardMoreRoom,
}

/// popover.js `VIEWPORT_PADDING`, menu.js and select.js `MARGIN`: the room
/// a panel keeps from the screen edges.
const kakaoPanelMargin = 8.0;

/// Where a panel goes against its anchor. Lengths are logical pixels.
@immutable
class KakaoPanelPlacement {
  const KakaoPanelPlacement({
    this.side = KakaoPanelSide.bottom,
    this.align = KakaoPanelAlign.center,
    this.offset = 0,
    this.flip = KakaoPanelFlip.whenOppositeFits,
    this.margin = kakaoPanelMargin,
    this.capToRoom = false,
    this.minRoom = 120,
    this.keepSide = false,
    this.matchAnchorWidth = false,
    this.minWidth = 0,
  });

  /// The preferred side.
  final KakaoPanelSide side;
  final KakaoPanelAlign align;

  /// The gap between anchor and panel (popover `offset`, `--kakao-menu-offset`,
  /// `--kakao-select-panel-offset`).
  final double offset;
  final KakaoPanelFlip flip;

  /// Room kept free at the screen edges.
  final double margin;

  /// Above or below: the panel's height is capped by the room on its side,
  /// but never below [minRoom] (menu.js / select.js `--_room`,
  /// `max(120, room)`). The panel scrolls its own content.
  final bool capToRoom;
  final double minRoom;

  /// Choose the side when the panel opens (and when the screen changes
  /// size), not on every layout, so a panel whose height changes while it is
  /// open (a select being filtered) stays put (select.js `_place(chooseSide)`).
  final bool keepSide;

  /// The panel is exactly as wide as the anchor, or [minWidth] if that is
  /// wider (select.js: `width: max(<trigger width>, --_panel-min-width)`).
  /// Otherwise it is as wide as its content, up to the screen.
  final bool matchAnchorWidth;
  final double minWidth;

  @override
  bool operator ==(Object other) =>
      other is KakaoPanelPlacement &&
      other.side == side &&
      other.align == align &&
      other.offset == offset &&
      other.flip == flip &&
      other.margin == margin &&
      other.capToRoom == capToRoom &&
      other.minRoom == minRoom &&
      other.keepSide == keepSide &&
      other.matchAnchorWidth == matchAnchorWidth &&
      other.minWidth == minWidth;

  @override
  int get hashCode =>
      Object.hash(side, align, offset, flip, margin, capToRoom, minRoom, keepSide, matchAnchorWidth, minWidth);
}

/// How a panel enters: it fades in over [duration] on [curve] while it moves
/// [slide] px towards its anchor's far side (it starts [slide] px back
/// towards the anchor: menu.js `translateY(-4px)` below, `4px` above).
///
/// Closing is at once, as on the web (popover: `visibility` is not
/// transitioned; menu and select: `display: none`). With reduced motion it
/// appears at once.
@immutable
class KakaoPanelMotion {
  const KakaoPanelMotion({required this.duration, required this.curve, this.slide = 0});

  final Duration duration;
  final Curve curve;
  final double slide;
}

/// Why a panel closed itself.
enum KakaoPanelDismiss { outsideTap, escape }

/// The side a panel goes on, given where its anchor is ([anchor], in the
/// screen's coordinates), its natural size and the screen size.
KakaoPanelSide kakaoPanelSide(Rect anchor, Size panel, Size screen, KakaoPanelPlacement p) {
  final side = p.side;
  final need = side.isVertical ? panel.height : panel.width;
  final room = kakaoPanelRoom(anchor, screen, side, p);
  final other = kakaoPanelRoom(anchor, screen, side.opposite, p);
  final flip = switch (p.flip) {
    KakaoPanelFlip.none => false,
    KakaoPanelFlip.whenOppositeFits => room < need && other >= need,
    KakaoPanelFlip.towardMoreRoom => room < need && other > room,
  };
  return flip ? side.opposite : side;
}

/// The room on [side] of [anchor]: up to the screen edge less the offset
/// and margin.
double kakaoPanelRoom(Rect anchor, Size screen, KakaoPanelSide side, KakaoPanelPlacement p) =>
    switch (side) {
      KakaoPanelSide.top => anchor.top,
      KakaoPanelSide.bottom => screen.height - anchor.bottom,
      KakaoPanelSide.left => anchor.left,
      KakaoPanelSide.right => screen.width - anchor.right,
    } -
    p.offset -
    p.margin;

/// The panel's top left corner on [side] of [anchor], lined up per
/// [KakaoPanelPlacement.align] and kept [KakaoPanelPlacement.margin] inside
/// the screen on both axes (the top / left edge wins when it is larger
/// than the screen).
Offset kakaoPanelPosition(Rect anchor, Size panel, Size screen, KakaoPanelSide side, KakaoPanelPlacement p) {
  final m = p.margin;
  double x;
  double y;
  if (side.isVertical) {
    y = side == KakaoPanelSide.top ? anchor.top - p.offset - panel.height : anchor.bottom + p.offset;
    x = _cross(anchor.left, anchor.right, panel.width, screen.width, p.align, m);
  } else {
    x = side == KakaoPanelSide.left ? anchor.left - p.offset - panel.width : anchor.right + p.offset;
    y = _cross(anchor.top, anchor.bottom, panel.height, screen.height, p.align, m);
  }
  x = math.max(m, math.min(x, screen.width - panel.width - m));
  y = math.max(m, math.min(y, screen.height - panel.height - m));
  return Offset(x, y);
}

double _cross(double start, double end, double size, double extent, KakaoPanelAlign align, double m) {
  switch (align) {
    case KakaoPanelAlign.center:
      return (start + end) / 2 - size / 2;
    case KakaoPanelAlign.start:
      if (start + size <= extent - m) return start;
      return end - size >= m ? end - size : extent - m - size;
    case KakaoPanelAlign.end:
      if (end - size >= m) return end - size;
      return start + size <= extent - m ? start : m;
  }
}

/// Opens and closes a [KakaoAnchoredPanel].
class KakaoAnchoredPanelController extends ChangeNotifier {
  bool _open = false;

  bool get isOpen => _open;

  void open() {
    if (_open) return;
    _open = true;
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    notifyListeners();
  }

  void toggle() => _open ? close() : open();
}

/// A panel in the nearest [Overlay], next to [child] (its anchor): placed by
/// [placement], following the anchor while the page scrolls or the screen
/// changes size, entering with [motion].
///
/// While open:
/// - a pointer down anywhere outside the panel and the anchor closes it
///   ([dismissOnTapOutside]; the anchor's own tap is left to the anchor, so
///   it can toggle);
/// - Escape closes it, whatever has focus, and is not passed on
///   ([dismissOnEscape]); with several panels open only the newest one
///   closes;
/// - when it closes with focus inside it, or by Escape, focus goes back to
///   the first focusable widget in the anchor ([returnFocus]).
///
/// [panelBuilder] builds the panel; `side` is the side it ended up on, known
/// only after layout, so read it while painting (a [CustomPainter] with
/// `repaint: side`), not while building.
///
/// [point] anchors the panel at a point in [child]'s coordinates instead of
/// its box (a context menu). [anchorInsets] grows the anchor's box before
/// placing (a submenu lines up with its parent panel's edge and padding, not
/// its row's).
///
/// [tapRegionGroup] puts the panel and anchor in a shared tap region group,
/// so panels that belong together (a menu and its submenus) do not count a
/// tap in one another as outside. Default: a group of this panel's own.
///
/// Needs an [Overlay] and a [TapRegionSurface] above it, as every
/// `WidgetsApp` has.
class KakaoAnchoredPanel extends StatefulWidget {
  const KakaoAnchoredPanel({
    super.key,
    required this.controller,
    required this.placement,
    required this.motion,
    required this.panelBuilder,
    required this.child,
    this.enabled = true,
    this.dismissOnTapOutside = true,
    this.dismissOnEscape = true,
    this.returnFocus = true,
    this.onDismiss,
    this.point,
    this.anchorInsets = EdgeInsets.zero,
    this.tapRegionGroup,
  });

  final KakaoAnchoredPanelController controller;
  final KakaoPanelPlacement placement;
  final KakaoPanelMotion motion;
  final Widget Function(BuildContext context, ValueListenable<KakaoPanelSide> side) panelBuilder;

  /// The anchor.
  final Widget child;

  /// False: the panel closes and stays closed (`disabled`).
  final bool enabled;
  final bool dismissOnTapOutside;
  final bool dismissOnEscape;
  final bool returnFocus;

  /// Called after the panel closed itself (outside tap or Escape).
  final ValueChanged<KakaoPanelDismiss>? onDismiss;
  final Offset? point;
  final EdgeInsets anchorInsets;
  final Object? tapRegionGroup;

  @override
  State<KakaoAnchoredPanel> createState() => _KakaoAnchoredPanelState();
}

class _KakaoAnchoredPanelState extends State<KakaoAnchoredPanel> with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  final _side = ValueNotifier(KakaoPanelSide.bottom);
  final _anchorFocus = FocusNode(debugLabel: 'KakaoAnchoredPanel anchor', canRequestFocus: false, skipTraversal: true);
  final _panelFocus = FocusNode(debugLabel: 'KakaoAnchoredPanel panel', canRequestFocus: false, skipTraversal: true);
  late final _anim = AnimationController(vsync: this, duration: widget.motion.duration);
  late CurvedAnimation _curved = CurvedAnimation(parent: _anim, curve: widget.motion.curve);

  /// Open panels, oldest first: Escape goes to the last one.
  static final List<_KakaoAnchoredPanelState> _openPanels = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _side.value = widget.placement.side;
    if (widget.controller.isOpen) WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(KakaoAnchoredPanel old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
    if (old.motion != widget.motion) {
      _anim.duration = widget.motion.duration;
      _curved.dispose();
      _curved = CurvedAnimation(parent: _anim, curve: widget.motion.curve);
    }
    if (!widget.enabled && widget.controller.isOpen) {
      // Not during build: the controller's listeners may set state.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.enabled) widget.controller.close();
      });
    } else if (widget.controller.isOpen != _portal.isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _unregister();
    _curved.dispose();
    _anim.dispose();
    _side.dispose();
    _anchorFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final open = widget.controller.isOpen;
    if (open && !widget.enabled) {
      widget.controller.close();
      return;
    }
    if (open == _portal.isShowing) return;
    if (open) {
      _side.value = widget.placement.side;
      _portal.show();
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _anim.value = 1;
      } else {
        _anim.forward(from: 0);
      }
      _register();
    } else {
      final hadFocus = _panelFocus.hasFocus;
      _unregister();
      _anim.value = 0;
      _portal.hide();
      if (hadFocus && widget.returnFocus) _focusAnchor();
    }
  }

  void _focusAnchor() {
    for (final node in _anchorFocus.descendants) {
      if (node.canRequestFocus && !node.skipTraversal) {
        node.requestFocus();
        return;
      }
    }
  }

  void _dismiss(KakaoPanelDismiss reason) {
    widget.controller.close();
    if (reason == KakaoPanelDismiss.escape && widget.returnFocus) _focusAnchor();
    widget.onDismiss?.call(reason);
  }

  void _register() {
    if (_openPanels.isEmpty) HardwareKeyboard.instance.addHandler(_onKey);
    _openPanels.remove(this);
    _openPanels.add(this);
  }

  void _unregister() {
    if (!_openPanels.remove(this)) return;
    if (_openPanels.isEmpty) HardwareKeyboard.instance.removeHandler(_onKey);
  }

  static bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (_openPanels.isEmpty) return false;
    final top = _openPanels.last;
    if (!top.widget.dismissOnEscape) return false;
    top._dismiss(KakaoPanelDismiss.escape);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) {
        final box = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
        final point = widget.point;
        final anchor = widget.anchorInsets.inflateRect(
          point == null
              ? box
              : Rect.fromCenter(
                  center: MatrixUtils.transformPoint(info.childPaintTransform, point),
                  width: 0,
                  height: 0,
                ),
        );
        return _PanelLayout(
          anchor: anchor,
          placement: widget.placement,
          animation: _curved,
          slide: widget.motion.slide,
          side: _side,
          child: TapRegion(
            groupId: widget.tapRegionGroup ?? this,
            onTapOutside: widget.dismissOnTapOutside ? (_) => _dismiss(KakaoPanelDismiss.outsideTap) : null,
            child: Focus(focusNode: _panelFocus, child: widget.panelBuilder(context, _side)),
          ),
        );
      },
      child: TapRegion(
        groupId: widget.tapRegionGroup ?? this,
        child: Focus(focusNode: _anchorFocus, child: widget.child),
      ),
    );
  }
}

/// Lays the panel out over the whole overlay: measures it, picks the side,
/// caps its height, places it, and paints it with the entry motion.
class _PanelLayout extends SingleChildRenderObjectWidget {
  const _PanelLayout({
    required this.anchor,
    required this.placement,
    required this.animation,
    required this.slide,
    required this.side,
    required super.child,
  });

  final Rect anchor;
  final KakaoPanelPlacement placement;
  final Animation<double> animation;
  final double slide;
  final ValueNotifier<KakaoPanelSide> side;

  @override
  _RenderPanelLayout createRenderObject(BuildContext context) =>
      _RenderPanelLayout(anchor: anchor, placement: placement, animation: animation, slide: slide, side: side);

  @override
  void updateRenderObject(BuildContext context, _RenderPanelLayout r) {
    r
      ..anchor = anchor
      ..placement = placement
      ..animation = animation
      ..slide = slide
      ..side = side;
  }
}

class _RenderPanelLayout extends RenderShiftedBox {
  _RenderPanelLayout({
    required this._anchor,
    required this._placement,
    required this._animation,
    required this._slide,
    required this.side,
  }) : super(null);

  ValueNotifier<KakaoPanelSide> side;

  Rect get anchor => _anchor;
  Rect _anchor;
  set anchor(Rect v) {
    if (v == _anchor) return;
    _anchor = v;
    markNeedsLayout();
  }

  KakaoPanelPlacement get placement => _placement;
  KakaoPanelPlacement _placement;
  set placement(KakaoPanelPlacement v) {
    if (v == _placement) return;
    _placement = v;
    _kept = null;
    markNeedsLayout();
  }

  Animation<double> get animation => _animation;
  Animation<double> _animation;
  set animation(Animation<double> v) {
    if (v == _animation) return;
    if (attached) _animation.removeListener(markNeedsPaint);
    _animation = v;
    if (attached) _animation.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double get slide => _slide;
  double _slide;
  set slide(double v) {
    if (v == _slide) return;
    _slide = v;
    markNeedsPaint();
  }

  /// The side chosen with [placement.keepSide], and the screen it was chosen for.
  (KakaoPanelSide, Size)? _kept;
  KakaoPanelSide _current = KakaoPanelSide.bottom;
  final _opacity = LayerHandle<OpacityLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _opacity.layer = null;
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    final p = placement;
    final m = p.margin;
    final width = p.matchAnchorWidth ? math.max(anchor.width, p.minWidth) : null;
    final maxW = math.max(0.0, size.width - 2 * m);
    final maxH = math.max(0.0, size.height - 2 * m);
    BoxConstraints box(double maxHeight) => width != null
        ? BoxConstraints.tightFor(width: math.min(width, maxW)).copyWith(maxHeight: maxHeight)
        : BoxConstraints(maxWidth: maxW, maxHeight: maxHeight);

    child.layout(box(maxH), parentUsesSize: true);
    var s = kakaoPanelSide(anchor, child.size, size, p);
    final kept = _kept;
    if (p.keepSide) {
      if (kept != null && kept.$2 == size) s = kept.$1;
      _kept = (s, size);
    }
    if (p.capToRoom && s.isVertical) {
      final room = math.max(p.minRoom, kakaoPanelRoom(anchor, size, s, p).floorToDouble());
      if (child.size.height > room) child.layout(box(math.min(maxH, room)), parentUsesSize: true);
    }
    (child.parentData! as BoxParentData).offset = kakaoPanelPosition(anchor, child.size, size, s, p);
    _current = s;
    // Painters listening to the side repaint; nothing rebuilds.
    side.value = s;
  }

  Offset get _slideOffset {
    final d = slide * (1 - animation.value);
    return switch (_current) {
      KakaoPanelSide.bottom => Offset(0, -d),
      KakaoPanelSide.top => Offset(0, d),
      KakaoPanelSide.right => Offset(-d, 0),
      KakaoPanelSide.left => Offset(d, 0),
    };
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final t = animation.value;
    final at = offset + (child.parentData! as BoxParentData).offset + _slideOffset;
    _opacity.layer = context.pushOpacity(
      at,
      (t.clamp(0.0, 1.0) * 255).round(),
      (context, offset) => context.paintChild(child, offset),
      oldLayer: _opacity.layer,
    );
  }

  @override
  bool hitTestSelf(Offset position) => false;
}
