import 'package:flutter/widgets.dart';
import 'package:kakao_components/kakao_components.dart';

// Content the showcase and the look-alike fixtures share with the web demo pages.

/// The demo's account popover body: popover/demo.html `dl` (14 px), `dt`
/// (12 px, 600, muted, 8 px above), `dd` (4 px below; a dd's 4 and the next
/// dt's 8 collapse to 8), at the popover's line-height 1.5.
class AccountDetails extends StatelessWidget {
  const AccountDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final dt = theme.text(size: 12, weight: 600, color: theme.colors.muted, height: 1.5);
    final dd = theme.text(size: 14, height: 1.5);
    const items = [('Plan', 'Pro'), ('Renews', 'Aug 4, 2026'), ('Seats', '12 / 20 used')];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (t, d) in items) ...[const SizedBox(height: 8), Text(t, style: dt), Text(d, style: dd)],
        const SizedBox(height: 4),
      ],
    );
  }
}
