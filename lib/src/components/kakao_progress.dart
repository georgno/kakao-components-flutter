import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../settings/kakao_progress_settings.g.dart';
import '../theme/kakao_theme.dart';

/// `<kakao-progress size>`: bar height and label text size.
enum KakaoProgressSize { sm, md, lg }

/// `<kakao-progress tone>`: the fill colour.
enum KakaoProgressTone { primary, success, warning, danger }

/// Flutter twin of `<kakao-progress>`: a segmented progress bar
/// ("Uploading 3 of 8", "Step 2 of 4").
///
/// - [value] of [max] fills the [segments] in order; null is indeterminate:
///   a highlight sweeps through the segments.
/// - A new value is reached by a smooth fill (`--kakao-progress-fill-*`); a
///   change that completes several segments takes longer (half a fill per
///   extra segment, at most 2.5×) so it reads as a sequence.
/// - When the moving fill completes a segment, that segment pops: it
///   stretches, squashes, rebounds a little and settles. Pops are at least
///   `--kakao-progress-pop-stagger` apart. A segment pops once per fill and
///   again only after the value dropped to or below its start. Segments full
///   on the first build, when the bar leaves the indeterminate state, or when
///   [max] or [segments] change, never pop; going down never pops.
/// - Reduced motion: the value shows at once, no pop, and the sweep becomes
///   a slow fade in place.
/// - [onSegmentComplete] is `progress-segment-complete`.
class KakaoProgress extends StatefulWidget {
  const KakaoProgress({
    super.key,
    this.value,
    this.max = 1,
    this.segments = 4,
    this.label,
    this.showValue = false,
    this.valueText,
    this.size = KakaoProgressSize.md,
    this.tone = KakaoProgressTone.primary,
    this.onSegmentComplete,
  });

  final double? value;
  final double max;
  final int segments;
  final String? label;
  final bool showValue;
  final String? valueText;
  final KakaoProgressSize size;
  final KakaoProgressTone tone;
  final void Function(int index, int segments)? onSegmentComplete;

  @override
  State<KakaoProgress> createState() => _KakaoProgressState();
}

const _eps = 1e-9;

class _KakaoProgressState extends State<KakaoProgress> with TickerProviderStateMixin {
  late final Ticker _fillTicker = createTicker(_onFillTick);
  late final AnimationController _sweep = AnimationController(vsync: this);

  int _n = 0;
  double _max = double.nan;
  double? _shown; // position drawn (0…1), null = indeterminate
  double? _target;
  List<bool> _armed = [];
  List<AnimationController?> _pops = [];

  // The running fill: from → to over dur.
  double _from = 0;
  double _to = 0;
  Duration _dur = Duration.zero;
  Duration _start = Duration.zero;
  bool _startPending = false;

  Duration _lastPop = Duration.zero;
  final Stopwatch _clock = Stopwatch()..start();

  bool get _reduce => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  double _maxOf(KakaoProgress w) => w.max.isFinite && w.max > 0 ? w.max : 1;
  int _segmentsOf(KakaoProgress w) => w.segments.clamp(1, 100);

  /// value / max in 0…1, or null while indeterminate.
  double? _position(KakaoProgress w) {
    final v = w.value;
    if (v == null || !v.isFinite) return null;
    return (v / _maxOf(w)).clamp(0.0, 1.0);
  }

  bool _isFull(int i, double p) => p >= (i + 1) / _n - _eps;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_n == 0) _sync(initial: true);
    _syncSweep();
  }

  @override
  void didUpdateWidget(KakaoProgress old) {
    super.didUpdateWidget(old);
    _sync(initial: false);
    _syncSweep();
  }

  @override
  void dispose() {
    _fillTicker.dispose();
    _sweep.dispose();
    for (final c in _pops) {
      c?.dispose();
    }
    super.dispose();
  }

  KakaoProgressSettings get _st => KakaoProgressSettings.of(KakaoTheme.of(context).colors);

  void _syncSweep() {
    final indeterminate = _position(widget) == null;
    if (!indeterminate) {
      _sweep.stop();
      return;
    }
    // Reduced motion: a slow fade, 2400ms ease-in-out, alternating.
    final d = _reduce ? const Duration(milliseconds: 2400) : _st.sweepDuration;
    if (_sweep.duration != d || !_sweep.isAnimating) {
      _sweep.duration = d;
      _sweep.repeat(reverse: _reduce);
    }
  }

  void _build(int n) {
    _stopFill();
    for (final c in _pops) {
      c?.dispose();
    }
    _n = n;
    _pops = List.filled(n, null);
    _armed = List.filled(n, true);
  }

  /// Arm and disarm without popping: full segments count as popped.
  void _baseline(double p) => _armed = List.generate(_n, (i) => !_isFull(i, p));

  /// A segment the value dropped to or below the start of may pop again.
  void _rearm(double p) {
    for (var i = 0; i < _n; i++) {
      if (p <= i / _n + _eps) _armed[i] = true;
    }
  }

  void _sync({required bool initial}) {
    final n = _segmentsOf(widget);
    final max = _maxOf(widget);
    final p = _position(widget);
    final structural = initial || n != _n || max != _max;
    if (n != _n) _build(n);
    _max = max;
    if (p == null) {
      _stopFill();
      _target = _shown = null;
      return;
    }
    final fresh = structural || _shown == null;
    _target = p;
    if (fresh || _reduce) {
      final from = _shown;
      _stopFill();
      _shown = p;
      if (fresh) {
        _baseline(p);
        return;
      }
      _rearm(p);
      if (from != null && p > from) _completeUpTo(p);
      return;
    }
    _rearm(p);
    _animate(_shown!, p);
  }

  void _animate(double from, double to) {
    if ((to - from).abs() < _eps) {
      _stopFill();
      _shown = to;
      return;
    }
    var crossings = 0;
    if (to > from) {
      for (var i = 0; i < _n; i++) {
        if (_armed[i] && _isFull(i, to) && !_isFull(i, from)) crossings++;
      }
    }
    final base = _st.fillDuration;
    final factor = math.min(2.5, 1 + 0.5 * math.max(0, crossings - 1));
    _from = from;
    _to = to;
    _dur = base * factor;
    _startPending = true;
    if (!_fillTicker.isActive) _fillTicker.start();
  }

  void _stopFill() {
    if (_fillTicker.isActive) _fillTicker.stop();
  }

  void _onFillTick(Duration elapsed) {
    if (_startPending) {
      _start = elapsed;
      _startPending = false;
    }
    final t = _dur == Duration.zero ? 1.0 : ((elapsed - _start).inMicroseconds / _dur.inMicroseconds).clamp(0.0, 1.0);
    final eased = _st.fillEase.transform(t);
    final s = (_from + (_to - _from) * eased).clamp(0.0, 1.0);
    setState(() => _shown = t >= 1 ? _to : s);
    if (_to > _from) _completeUpTo(_shown!);
    if (t >= 1) _stopFill();
  }

  /// Pops every armed segment the shown value has filled (only while the target is past it too).
  void _completeUpTo(double s) {
    final target = _target;
    if (target == null) return;
    for (var i = 0; i < _n; i++) {
      if (_armed[i] && _isFull(i, s) && _isFull(i, target)) {
        _armed[i] = false;
        _queuePop(i);
      }
    }
  }

  void _queuePop(int i) {
    if (_reduce) {
      widget.onSegmentComplete?.call(i, _n);
      return;
    }
    final now = _clock.elapsed;
    final at = now > _lastPop + _st.popStagger ? now : _lastPop + _st.popStagger;
    _lastPop = at;
    void fire() {
      if (!mounted || i >= _n) return;
      _pop(i);
      widget.onSegmentComplete?.call(i, _n);
    }

    if (at <= now) {
      fire();
    } else {
      Future<void>.delayed(at - now, fire);
    }
  }

  void _pop(int i) {
    _pops[i]?.dispose();
    final c = AnimationController(vsync: this, duration: _st.popDuration)..addListener(() => setState(() {}));
    _pops[i] = c;
    c.forward().whenCompleteOrCancel(() {
      if (mounted && _pops[i] == c) {
        _pops[i] = null;
        c.dispose();
        setState(() {});
      }
    });
  }

  /// The pop's keyframes (progress.js): rest → stretch (28 %) → squash (58 %)
  /// → small rebound (80 %) → rest, each leg on the pop easing.
  ({double scaleY, double dy}) _popAt(double t, KakaoProgressSettings st) {
    final scale = st.popScale;
    final squash = 1 - (scale - 1) * 0.35;
    final rebound = 1 + (scale - 1) * 0.1;
    const stops = [0.0, 0.28, 0.58, 0.8, 1.0];
    final ys = [1.0, scale, squash, rebound, 1.0];
    final dys = [0.0, -1.0, 0.0, 0.0, 0.0];
    var k = 0;
    while (k < 3 && t > stops[k + 1]) {
      k++;
    }
    final local = ((t - stops[k]) / (stops[k + 1] - stops[k])).clamp(0.0, 1.0);
    final e = st.popEase.transform(local);
    return (scaleY: ys[k] + (ys[k + 1] - ys[k]) * e, dy: dys[k] + (dys[k + 1] - dys[k]) * e);
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoProgressSettings.of(theme.colors);
    final (double height, double fontSize) = switch (widget.size) {
      KakaoProgressSize.sm => (st.smHeight, st.smFontSize),
      KakaoProgressSize.md => (st.height, st.fontSize),
      KakaoProgressSize.lg => (st.lgHeight, st.lgFontSize),
    };
    final tone = switch (widget.tone) {
      KakaoProgressTone.primary => st.primary,
      KakaoProgressTone.success => st.success,
      KakaoProgressTone.warning => st.warning,
      KakaoProgressTone.danger => st.danger,
    };
    final p = _position(widget);
    final label = (widget.label ?? '').trim();
    var valueText = '';
    if (widget.showValue) {
      if (widget.valueText != null && widget.valueText!.isNotEmpty) {
        valueText = widget.valueText!;
      } else if (p != null) {
        valueText = '${(p * 100).round()}%';
      }
    }

    final bar = SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _BarPainter(
            n: _n,
            gap: st.gap,
            radius: st.radius,
            track: st.track,
            tone: tone,
            shown: _shown,
            sweep: p == null ? _sweep.value : null,
            sweepEase: st.sweepEase,
            reduce: _reduce,
            pops: [for (final c in _pops) c == null ? null : _popAt(c.value, st)],
          ),
        ),
      ),
    );

    return Semantics(
      label: label.isEmpty ? null : label,
      value: widget.valueText ?? (p == null ? null : '${(p * 100).round()}%'),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label.isNotEmpty || valueText.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.text(size: fontSize, weight: st.labelWeight, color: st.labelColor, height: 1.4),
                    ),
                  ),
                  if (valueText.isNotEmpty) ...[
                    const SizedBox(width: 12), // .head gap: 0.75rem
                    Text(
                      valueText,
                      style: theme.text(size: fontSize, color: st.valueColor, height: 1.4, tabular: true),
                    ),
                  ],
                ],
              ),
              SizedBox(height: st.labelGap),
            ],
            bar,
          ],
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.n,
    required this.gap,
    required this.radius,
    required this.track,
    required this.tone,
    required this.shown,
    required this.sweep,
    required this.sweepEase,
    required this.reduce,
    required this.pops,
  });

  final int n;
  final double gap, radius;
  final Color track, tone;
  final double? shown; // null: indeterminate
  final double? sweep; // 0…1 of the sweep cycle while indeterminate
  final Curve sweepEase;
  final bool reduce;
  final List<({double scaleY, double dy})?> pops;

  @override
  void paint(Canvas canvas, Size size) {
    if (n == 0) return;
    final w = (size.width - gap * (n - 1)) / n;
    final h = size.height;
    final r = Radius.circular(math.min(radius, h / 2));
    final trackPaint = Paint()..color = track;
    final tonePaint = Paint()..color = tone;

    // Indeterminate band: 40% of the whole bar, translateX(-100% → 250%) of itself.
    Rect? band;
    var bandAlpha = 1.0;
    if (shown == null && sweep != null) {
      if (reduce) {
        band = Offset.zero & size; // the whole bar, breathing 0.25 ↔ 0.6
        bandAlpha = 0.25 + 0.35 * Curves.easeInOut.transform(sweep!);
      } else {
        final bw = size.width * 0.4;
        final x = bw * (-1 + 3.5 * sweepEase.transform(sweep!));
        band = Rect.fromLTWH(x, 0, bw, h);
      }
    }

    for (var i = 0; i < n; i++) {
      final seg = Rect.fromLTWH(i * (w + gap), 0, w, h);
      canvas.save();
      final pop = i < pops.length ? pops[i] : null;
      if (pop != null) {
        // scale(1, s) about the segment's centre, plus translateY.
        canvas.translate(0, seg.center.dy + pop.dy);
        canvas.scale(1, pop.scaleY);
        canvas.translate(0, -seg.center.dy);
      }
      final rr = RRect.fromRectAndRadius(seg, r);
      canvas.drawRRect(rr, trackPaint);
      canvas.clipRRect(rr);
      if (shown != null) {
        final f = (shown! * n - i).clamp(0.0, 1.0);
        if (f > 0) {
          // The fill slides in from the left, so its leading edge stays round.
          canvas.drawRRect(RRect.fromRectAndRadius(seg.shift(Offset((f - 1) * w, 0)), r), tonePaint);
        }
      } else if (band != null) {
        final paint = Paint()..color = tone.withValues(alpha: tone.a * bandAlpha);
        canvas.drawRRect(RRect.fromRectAndRadius(band, reduce ? Radius.zero : r), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => true;
}
