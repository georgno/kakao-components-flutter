import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_anchored_panel.dart';
import '../settings/kakao_popover_settings.g.dart';
import '../theme/kakao_theme.dart';

/// `<kakao-popover trigger>`: what opens it.
enum KakaoPopoverTrigger {
  /// The anchor toggles it (call `popover.toggle` from the anchor's press);
  /// a pointer down outside or Escape closes it.
  click,

  /// Pointer on, or focus in, the anchor opens it; it closes [KakaoPopover.closeDelay]
  /// after the pointer leaves both anchor and popover, or focus leaves the anchor.
  hover,

  /// Only the controller opens and closes it.
  manual,
}

/// `<kakao-popover placement>`: the preferred side of the anchor.
enum KakaoPopoverPlacement { top, bottom, left, right }

/// A `list-data` row.
@immutable
class KakaoPopoverRow {
  const KakaoPopoverRow(this.label, this.value);
  final String label;
  final String value;
}

/// Opens and closes a [KakaoPopover] (`open()`, `close()`, `toggle()`).
class KakaoPopoverController extends KakaoAnchoredPanelController {}

/// Flutter twin of `<kakao-popover>`: a panel next to an anchor, with
/// optional header (and close button) and either [content] or [rows]
/// (`list-data`; [content] wins when both are given).
///
/// As popover.js:
/// - on [placement]'s side, [offset] px away, centred on the anchor, with an
///   arrow on the side facing it (centred on the panel); flipped to the
///   other side when it doesn't fit there but does on the other, and kept
///   8 px inside the screen;
/// - fades in over `--kakao-popover-transition-speed` (CSS `ease`), closes
///   at once; with reduced motion it appears at once;
/// - Escape closes it and focus goes back to the anchor;
/// - rows: the first one takes focus on open, arrow keys move (wrapping),
///   Home / End jump, Enter / Space or a tap call [onSelect].
///
/// [anchorBuilder] builds the anchor and gets the controller: for
/// [KakaoPopoverTrigger.click], call `popover.toggle` from its press (the
/// web listens to the anchor's `click`).
class KakaoPopover extends StatefulWidget {
  const KakaoPopover({
    super.key,
    required this.anchorBuilder,
    this.header,
    this.content,
    this.rows,
    this.trigger = KakaoPopoverTrigger.click,
    this.placement = KakaoPopoverPlacement.bottom,
    this.offset = 8,
    this.closeDelay = const Duration(milliseconds: 150),
    this.disabled = false,
    this.controller,
    this.onOpen,
    this.onClose,
    this.onSelect,
  });

  final Widget Function(BuildContext context, KakaoPopoverController popover) anchorBuilder;

  /// `slot="header"`: shown with a close button when given.
  final Widget? header;

  /// `slot="content"`.
  final Widget? content;

  /// `list-data`: label / value rows; empty shows "No data".
  final List<KakaoPopoverRow>? rows;
  final KakaoPopoverTrigger trigger;
  final KakaoPopoverPlacement placement;

  /// `offset` (popover.js default 8): the gap to the anchor.
  final double offset;

  /// `close-delay` (popover.js default 150 ms), for [KakaoPopoverTrigger.hover].
  final Duration closeDelay;

  /// Blocks every trigger and closes it.
  final bool disabled;
  final KakaoPopoverController? controller;

  /// `kakao-popover-open` / `kakao-popover-close`.
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  /// `kakao-popover-item-select`: a row was activated.
  final void Function(int index, KakaoPopoverRow row)? onSelect;

  @override
  State<KakaoPopover> createState() => _KakaoPopoverState();
}

// popover.js CSS outside the settings block.
const _lineHeight = 1.5; // .surface line-height
const _arrowSize = 8.0; // .arrow width / height (border-box), rotated 45deg
const _border = 1.0; // .surface, .header, .row: 1px solid border-color

class _KakaoPopoverState extends State<KakaoPopover> {
  KakaoPopoverController? _own;
  KakaoPopoverController get _controller => widget.controller ?? (_own ??= KakaoPopoverController());
  bool _wasOpen = false;
  Timer? _closeTimer;
  bool _refocusing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _wasOpen = _controller.isOpen;
  }

  @override
  void didUpdateWidget(KakaoPopover old) {
    super.didUpdateWidget(old);
    final before = old.controller ?? _own;
    if (before != _controller) {
      before?.removeListener(_changed);
      _controller.addListener(_changed);
      _wasOpen = _controller.isOpen;
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    (widget.controller ?? _own)?.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  void _changed() {
    final open = _controller.isOpen;
    if (open && widget.disabled) return; // the panel closes it again
    if (open == _wasOpen) return;
    _wasOpen = open;
    if (!open) _closeTimer?.cancel();
    open ? widget.onOpen?.call() : widget.onClose?.call();
    if (mounted) setState(() {}); // aria-expanded
  }

  void _hoverOpen() {
    if (widget.disabled) return;
    _closeTimer?.cancel();
    _controller.open();
  }

  void _scheduleClose() {
    if (widget.trigger != KakaoPopoverTrigger.hover) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(widget.closeDelay, _controller.close);
  }

  @override
  Widget build(BuildContext context) {
    final st = KakaoPopoverSettings.of(KakaoTheme.of(context).colors);
    final hover = widget.trigger == KakaoPopoverTrigger.hover;
    Widget anchor = widget.anchorBuilder(context, _controller);
    if (hover) {
      anchor = MouseRegion(
        onEnter: (_) => _hoverOpen(),
        onExit: (_) => _scheduleClose(),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (f) {
            if (_refocusing) return;
            f ? _hoverOpen() : _scheduleClose();
          },
          child: anchor,
        ),
      );
    } else if (widget.trigger == KakaoPopoverTrigger.click) {
      anchor = Semantics(expanded: _controller.isOpen, child: anchor);
    }

    return KakaoAnchoredPanel(
      controller: _controller,
      enabled: !widget.disabled,
      // Outside pointer down closes a click popover only (popover.js _open).
      dismissOnTapOutside: widget.trigger == KakaoPopoverTrigger.click,
      onDismiss: (reason) {
        // Focus going back to a hover anchor must not open it again.
        if (reason == KakaoPanelDismiss.escape && hover) {
          _refocusing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _refocusing = false);
        }
      },
      placement: KakaoPanelPlacement(
        side: switch (widget.placement) {
          KakaoPopoverPlacement.top => KakaoPanelSide.top,
          KakaoPopoverPlacement.bottom => KakaoPanelSide.bottom,
          KakaoPopoverPlacement.left => KakaoPanelSide.left,
          KakaoPopoverPlacement.right => KakaoPanelSide.right,
        },
        align: KakaoPanelAlign.center,
        offset: widget.offset,
        flip: KakaoPanelFlip.whenOppositeFits,
      ),
      // `transition: opacity var(--_transition-speed) ease` (popover.js .surface).
      motion: KakaoPanelMotion(duration: st.transitionSpeed, curve: Curves.ease),
      panelBuilder: (context, side) {
        Widget surface = _Surface(
          side: side,
          header: widget.header,
          content: widget.content,
          rows: widget.rows,
          onClose: _controller.close,
          onSelect: widget.onSelect,
          keyboardOpened: HardwareKeyboard.instance.logicalKeysPressed.isNotEmpty,
        );
        if (hover) {
          surface = MouseRegion(onEnter: (_) => _closeTimer?.cancel(), onExit: (_) => _scheduleClose(), child: surface);
        }
        // role="dialog" for click; a hover popover is a tooltip, announced
        // as it appears (Flutter has no tooltip role checks yet).
        return Semantics(
          role: hover ? null : SemanticsRole.dialog,
          liveRegion: hover,
          container: true,
          explicitChildNodes: true,
          child: surface,
        );
      },
      child: anchor,
    );
  }
}

/// `.surface`: border, background, arrow, header and body.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.side,
    required this.header,
    required this.content,
    required this.rows,
    required this.onClose,
    required this.onSelect,
    required this.keyboardOpened,
  });

  final ValueListenable<KakaoPanelSide> side;
  final Widget? header;
  final Widget? content;
  final List<KakaoPopoverRow>? rows;
  final VoidCallback onClose;
  final void Function(int index, KakaoPopoverRow row)? onSelect;
  final bool keyboardOpened;

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoPopoverSettings.of(theme.colors);
    final text = theme.text(size: st.fontSize, color: st.textColor, height: _lineHeight);
    final pad = st.spacing * 1.5; // calc(var(--_spacing) * 1.5)

    Widget? body;
    final content = this.content;
    final rows = this.rows;
    if (content != null) {
      body = content;
    } else if (rows != null && rows.isEmpty) {
      // .empty
      body = Padding(
        padding: EdgeInsets.all(pad),
        child: Text(
          'No data',
          textAlign: TextAlign.center,
          style: text.copyWith(color: st.labelColor),
        ),
      );
    } else if (rows != null) {
      body = _Rows(rows: rows, onSelect: onSelect, keyboardOpened: keyboardOpened);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: st.minWidth, maxWidth: st.maxWidth),
      child: IntrinsicWidth(
        child: CustomPaint(
          painter: _SurfacePainter(side: side, bg: st.bg, border: st.borderColor, radius: st.radius, shadow: st.shadow),
          child: Padding(
            padding: const EdgeInsets.all(_border),
            child: DefaultTextStyle(
              style: text,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (header != null)
                    // .header: flex, space-between, gap spacing, 600, padding spacing / 1.5 spacing.
                    Container(
                      padding: EdgeInsets.symmetric(vertical: st.spacing, horizontal: pad),
                      decoration: BoxDecoration(
                        color: st.headerBg,
                        border: Border(bottom: BorderSide(color: st.borderColor)),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(st.radius)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: DefaultTextStyle(
                              style: theme.text(
                                size: st.fontSize,
                                weight: 600,
                                color: st.textColor,
                                height: _lineHeight,
                              ),
                              child: header!,
                            ),
                          ),
                          SizedBox(width: st.spacing),
                          _CloseButton(onPressed: onClose),
                        ],
                      ),
                    ),
                  // .body: padding calc(spacing * 1.5).
                  if (body != null) Padding(padding: EdgeInsets.all(pad), child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The surface box and its arrow: an 8 px square turned 45°, centred on the
/// edge facing the anchor, filled with the background and bordered on its
/// two outer edges, so it cuts into the surface's border. The header (drawn
/// after it) covers its inner half, as on the web.
class _SurfacePainter extends CustomPainter {
  _SurfacePainter({
    required this.side,
    required this.bg,
    required this.border,
    required this.radius,
    required this.shadow,
  }) : super(repaint: side);

  final ValueListenable<KakaoPanelSide> side;
  final Color bg;
  final Color border;
  final double radius;
  final List<BoxShadow> shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    for (final s in shadow) {
      canvas.drawRRect(rrect.shift(s.offset).inflate(s.spreadRadius), s.toPaint());
    }
    canvas.drawRRect(rrect, Paint()..color = bg);
    canvas.drawRRect(
      rrect.deflate(_border / 2),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = _border,
    );

    final s = side.value;
    final centre = switch (s) {
      // Placement bottom: the arrow on the top edge, and so on.
      KakaoPanelSide.bottom => Offset(size.width / 2, 0),
      KakaoPanelSide.top => Offset(size.width / 2, size.height),
      KakaoPanelSide.right => Offset(0, size.height / 2),
      KakaoPanelSide.left => Offset(size.width, size.height / 2),
    };
    const h = _arrowSize / 2;
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(math.pi / 4);
    canvas.drawRect(const Rect.fromLTRB(-h, -h, h, h), Paint()..color = bg);
    final line = Paint()..color = border;
    const top = Rect.fromLTRB(-h, -h, h, -h + _border);
    const bottom = Rect.fromLTRB(-h, h - _border, h, h);
    const left = Rect.fromLTRB(-h, -h, -h + _border, h);
    const right = Rect.fromLTRB(h - _border, -h, h, h);
    // The two edges popover.js keeps for each placement.
    final edges = switch (s) {
      KakaoPanelSide.bottom => [top, left],
      KakaoPanelSide.top => [bottom, right],
      KakaoPanelSide.left => [top, right],
      KakaoPanelSide.right => [bottom, left],
    };
    for (final e in edges) {
      canvas.drawRect(e, line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SurfacePainter old) =>
      old.side != side ||
      old.bg != bg ||
      old.border != border ||
      old.radius != radius ||
      !listEquals(old.shadow, shadow);
}

/// `.close-btn`: ✕, 14 px, line-height 1, padding 2 / 6, 1 px transparent
/// border, hover / active background, 2 px focus ring 1 px out.
class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;
  bool _down = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoPopoverSettings.of(theme.colors);
    final bg = _down ? st.activeBg : (_hover ? st.hoverBg : null);
    return Semantics(
      button: true,
      label: 'Close',
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed())},
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onPressed,
          child: Container(
            // outline: 2px, outline-offset: 1px → a ring 1..3 px outside.
            foregroundDecoration: _focus
                ? BoxDecoration(
                    border: Border.all(color: st.focusRingColor, width: 2, strokeAlign: 1.5),
                    borderRadius: BorderRadius.circular(st.radius + 1),
                  )
                : null,
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: const Color(0x00000000)),
              borderRadius: BorderRadius.circular(st.radius),
            ),
            child: Text('✕', style: theme.text(size: 14, color: st.labelColor, height: 1)),
          ),
        ),
      ),
    );
  }
}

/// `.rows`: label / value rows with a roving focus.
class _Rows extends StatefulWidget {
  const _Rows({required this.rows, required this.onSelect, required this.keyboardOpened});
  final List<KakaoPopoverRow> rows;
  final void Function(int index, KakaoPopoverRow row)? onSelect;
  final bool keyboardOpened;

  @override
  State<_Rows> createState() => _RowsState();
}

class _RowsState extends State<_Rows> {
  late List<FocusNode> _nodes = _make(widget.rows.length);
  int _active = 0;

  /// :focus-visible: after keys, not after a pointer opened the popover.
  late bool _ring = widget.keyboardOpened;

  List<FocusNode> _make(int n) => [for (var i = 0; i < n; i++) FocusNode(debugLabel: 'KakaoPopover row $i')];

  @override
  void initState() {
    super.initState();
    // popover.js _open: the first row takes focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _nodes.isNotEmpty) _nodes.first.requestFocus();
    });
  }

  @override
  void didUpdateWidget(_Rows old) {
    super.didUpdateWidget(old);
    if (old.rows.length != widget.rows.length) {
      for (final n in _nodes) {
        n.dispose();
      }
      _nodes = _make(widget.rows.length);
      _active = 0;
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _move(int to) {
    setState(() {
      _ring = true;
      _active = to;
    });
    _nodes[to].requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final n = _nodes.length;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.arrowRight) {
      _move((_active + 1) % n);
    } else if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowLeft) {
      _move((_active - 1 + n) % n);
    } else if (k == LogicalKeyboardKey.home) {
      _move(0);
    } else if (k == LogicalKeyboardKey.end) {
      _move(n - 1);
    } else if ((k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) && e is KeyDownEvent) {
      final i = _nodes.indexWhere((f) => f.hasPrimaryFocus);
      if (i < 0) return KeyEventResult.ignored;
      widget.onSelect?.call(i, widget.rows[i]);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: Semantics(
        role: SemanticsRole.list,
        container: true,
        explicitChildNodes: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.rows.length; i++)
              _Row(
                row: widget.rows[i],
                node: _nodes[i],
                last: i == widget.rows.length - 1,
                ring: _ring,
                onFocus: () => _active = i,
                onTap: () {
                  _active = i;
                  widget.onSelect?.call(i, widget.rows[i]);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.row,
    required this.node,
    required this.last,
    required this.ring,
    required this.onFocus,
    required this.onTap,
  });

  final KakaoPopoverRow row;
  final FocusNode node;
  final bool last;
  final bool ring;
  final VoidCallback onFocus;
  final VoidCallback onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoPopoverSettings.of(theme.colors);
    final bg = _down ? st.activeBg : (_hover ? st.hoverBg : null);
    return Semantics(
      role: SemanticsRole.listItem,
      button: true,
      onTap: widget.onTap,
      child: Focus(
        focusNode: widget.node,
        onFocusChange: (f) {
          setState(() => _focused = f);
          if (f) widget.onFocus();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _down = true),
            onTapUp: (_) => setState(() => _down = false),
            onTapCancel: () => setState(() => _down = false),
            onTap: widget.onTap,
            child: Container(
              // .row:focus-visible: outline 2px, outline-offset -2px (inside).
              foregroundDecoration: _focused && widget.ring
                  ? BoxDecoration(border: Border.all(color: st.focusRingColor, width: 2))
                  : null,
              // .row: padding spacing / 1.5 spacing, border-bottom (not the last).
              padding: EdgeInsets.symmetric(vertical: st.spacing, horizontal: st.spacing * 1.5),
              decoration: BoxDecoration(
                color: bg,
                border: widget.last ? null : Border(bottom: BorderSide(color: st.borderColor)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // .label: label-font-size, 600, label-color, no wrap.
                  Text(
                    widget.row.label,
                    softWrap: false,
                    style: theme.text(size: st.labelFontSize, weight: 600, color: st.labelColor, height: _lineHeight),
                  ),
                  SizedBox(width: st.spacing * 1.5), // gap: calc(spacing * 1.5)
                  // .value: font-size, 400, text colour, right-aligned, wraps.
                  Expanded(
                    child: Text(
                      widget.row.value,
                      textAlign: TextAlign.right,
                      style: theme.text(size: st.fontSize, color: st.textColor, height: _lineHeight),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
