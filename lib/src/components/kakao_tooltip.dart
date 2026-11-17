import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../theme/kakao_theme.dart';

/// Flutter twin of `<kakao-tooltip>` / `data-tooltip`: a small themed label
/// next to a control (the name of an icon-only button, or a short hint).
///
/// Behaviour as tooltip.js:
/// - mouse: shows after 400 ms on the anchor, hides when the pointer leaves
///   or presses;
/// - keyboard: shows while the anchor has visible focus;
/// - touch: a long-press (500 ms) shows it, and the tap that would follow is
///   swallowed; it hides on the next touch or after 3 s.
/// Above the anchor by default, below when there is no room.
class KakaoTooltip extends StatefulWidget {
  const KakaoTooltip({super.key, required this.message, required this.child});

  /// The label. Empty turns the tooltip off (`data-tooltip=""`).
  final String message;
  final Widget child;

  /// KakaoTooltip.delays in tooltip.js.
  static const hoverDelay = Duration(milliseconds: 400);
  static const touchHide = Duration(milliseconds: 3000);

  @override
  State<KakaoTooltip> createState() => _KakaoTooltipState();
}

// --kakao-tooltip-* settings.
const _fontSize = 13.0; // 0.8125rem
const _fontWeight = 500.0;
const _paddingX = 8.0; // 0.5rem
const _paddingY = 4.0; // 0.25rem
const _maxWidth = 256.0; // 16rem
const _offset = 6.0;
const _animDuration = Duration(milliseconds: 150);
const _slide = 4.0; // tooltip.js: enters 4px from its side

class _KakaoTooltipState extends State<KakaoTooltip> with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  late final _anim = AnimationController(vsync: this, duration: _animDuration);
  Timer? _showTimer;
  Timer? _hideTimer;
  bool _focused = false;

  bool get _enabled => widget.message.isNotEmpty;

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _show({Duration? hideAfter}) {
    if (!_enabled || !mounted) return;
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (!_portal.isShowing) _portal.show();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _anim.value = 1;
    } else {
      _anim.forward();
    }
    if (hideAfter != null) _hideTimer = Timer(hideAfter, _hide);
  }

  void _hide() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (!mounted || !_portal.isShowing) return;
    _anim.value = 0;
    _portal.hide();
  }

  void _onFocusChange(bool focused) {
    _focused = focused;
    final keyboard = FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (focused && keyboard) {
      _show();
    } else if (!focused) {
      _hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildLabel,
      child: TapRegion(
        // The next touch or click anywhere else hides it too.
        onTapOutside: (_) => _hide(),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: _onFocusChange,
          child: MouseRegion(
            onEnter: (e) {
              if (e.kind == PointerDeviceKind.touch) return;
              _showTimer?.cancel();
              _showTimer = Timer(KakaoTooltip.hoverDelay, _show);
            },
            onExit: (e) {
              if (!_focused) _hide();
              _showTimer?.cancel();
            },
            child: Listener(
              // Pressing the anchor hides a mouse label; a new touch hides a touch label.
              onPointerDown: (e) => _hide(),
              child: RawGestureDetector(
                gestures: {
                  LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                    () => LongPressGestureRecognizer(
                      duration: const Duration(milliseconds: 500),
                      supportedDevices: {PointerDeviceKind.touch},
                    ),
                    (r) => r.onLongPress = () => _show(hideAfter: KakaoTooltip.touchHide),
                  ),
                },
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext overlayContext) {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null || !box.attached) return const SizedBox.shrink();
    final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;

    final theme = KakaoTheme.of(context);
    final c = theme.colors;
    final label = Container(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: _paddingX, vertical: _paddingY),
      decoration: BoxDecoration(
        color: c.ink, // --_bg
        border: Border.all(color: c.ink), // --_border
        borderRadius: BorderRadius.circular(theme.tokens.radiusSm),
        boxShadow: [
          const BoxShadow(offset: Offset(0, 8), blurRadius: 24, color: Color(0x14000000)),
          BoxShadow(spreadRadius: 1, color: c.text.withValues(alpha: .10)),
        ],
      ),
      child: Text(
        widget.message,
        style: theme.text(size: _fontSize, weight: _fontWeight, color: c.onInk, height: 1.35),
      ),
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomSingleChildLayout(
          delegate: _TooltipLayout(anchor),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, child) {
              final t = theme.tokens.easeStandard.transform(_anim.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, _slide * (1 - t)), child: child),
              );
            },
            child: Semantics(liveRegion: true, child: label),
          ),
        ),
      ),
    );
  }
}

/// Centred above the anchor, flipped below when it doesn't fit, kept 8 px
/// inside the screen sideways.
class _TooltipLayout extends SingleChildLayoutDelegate {
  _TooltipLayout(this.anchor);
  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    var top = anchor.top - _offset - child.height;
    if (top < 8) top = anchor.bottom + _offset;
    final left = (anchor.center.dx - child.width / 2).clamp(
      8.0,
      (size.width - child.width - 8).clamp(8.0, double.infinity),
    );
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_TooltipLayout old) => old.anchor != anchor;
}
