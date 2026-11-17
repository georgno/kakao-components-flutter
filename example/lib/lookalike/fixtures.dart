import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:kakao_components/kakao_components.dart';

/// The Flutter side of each look-alike pair in tool/lookalike/cases.json: the
/// same content as the web demo element of the same id. Text, values and
/// layout follow the demo page; the layout literals name the demo CSS rule
/// they come from (shared/demo.css, or the page's own <style>).
final Map<String, WidgetBuilder> lookalikeFixtures = {
  'button-variants': (_) => _row([
    KakaoButton(label: 'Primary', onPressed: _noop),
    KakaoButton(label: 'Secondary', variant: KakaoButtonVariant.secondary, onPressed: _noop),
    KakaoButton(label: 'Ghost', variant: KakaoButtonVariant.ghost, onPressed: _noop),
    // fas fa-trash on the web; the showcase has no Font Awesome.
    KakaoButton(label: 'Danger', variant: KakaoButtonVariant.danger, icon: const Icon(Icons.delete), onPressed: _noop),
    const KakaoButton(label: 'Disabled'),
  ]),
  'button-sizes': (_) => _row([
    KakaoButton(label: 'Small', size: KakaoButtonSize.sm, onPressed: _noop),
    KakaoButton(label: 'Medium', onPressed: _noop),
    KakaoButton(label: 'Large', size: KakaoButtonSize.lg, onPressed: _noop),
  ]),
  'card-primary': (c) => _card(
    c,
    'Upgrade to Pro',
    'Unlimited projects, version history and priority support.',
    [
      KakaoButton(label: 'Upgrade', onPressed: _noop),
      KakaoButton(label: 'Later', variant: KakaoButtonVariant.ghost, onPressed: _noop),
    ],
  ),
  'card-danger': (c) => _card(c, 'Delete project', 'This removes all files and cannot be undone.', [
    // fas fa-trash on the web.
    KakaoButton(label: 'Delete', variant: KakaoButtonVariant.danger, icon: const Icon(Icons.delete), onPressed: _noop),
    KakaoButton(label: 'Cancel', variant: KakaoButtonVariant.secondary, onPressed: _noop),
  ]),
  'card-single-button': (c) => _card(c, 'Invite your team', 'A single button can go straight into the footer.', [
    KakaoButton(label: 'Send invites', variant: KakaoButtonVariant.secondary, onPressed: _noop),
  ]),
  'progress-segments': (_) => _bars(const [
    KakaoProgress(label: 'One segment', segments: 1, value: 0.62, showValue: true),
    KakaoProgress(label: 'Step 2 of 3', segments: 3, value: 2, max: 3, showValue: true, valueText: '2 of 3'),
    KakaoProgress(label: 'Four segments (default)', value: 0.6, showValue: true),
    KakaoProgress(label: 'Eight segments', segments: 8, value: 5.5, max: 8, showValue: true),
  ]),
  'progress-sizes': (_) => _bars(const [
    KakaoProgress(size: KakaoProgressSize.sm, label: 'Small', value: 0.45, showValue: true),
    KakaoProgress(label: 'Medium (default)', value: 0.45, showValue: true),
    KakaoProgress(size: KakaoProgressSize.lg, label: 'Large', value: 0.45, showValue: true),
  ]),
  'progress-tones': (_) => _bars(const [
    KakaoProgress(label: 'Primary (default)', value: 0.7, showValue: true),
    KakaoProgress(tone: KakaoProgressTone.success, label: 'Success', value: 1, showValue: true),
    KakaoProgress(
      tone: KakaoProgressTone.warning,
      label: 'Warning',
      value: 0.85,
      showValue: true,
      valueText: '85 of 100 GB',
    ),
    KakaoProgress(tone: KakaoProgressTone.danger, label: 'Danger', value: 0.3, showValue: true),
  ]),
};

void _noop() {}

// demo.css `.row`: flex, wrap, gap 0.5rem, items centred.
Widget _row(List<Widget> children) =>
    Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: children);

// progress/demo.html `.bars`: grid, gap 1.25rem.
Widget _bars(List<Widget> children) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 20), children[i]],
  ],
);

// card/demo.html: `kakao-card h3[slot="header"] { font-size: 1.05rem;
// letter-spacing: -0.01em }` on the browser's bold h3; `kakao-card p` in
// --muted; body text 16px / 1.5 (demo.css `body`).
Widget _card(BuildContext context, String title, String text, List<Widget> footer) {
  final theme = KakaoTheme.of(context);
  return KakaoCard(
    header: Text(title, style: theme.text(size: 16.8, weight: 700, tracking: -0.01, height: 1.5)),
    footer: footer,
    children: [Text(text, style: theme.text(size: 16, color: theme.colors.muted, height: 1.5))],
  );
}
