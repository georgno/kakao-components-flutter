import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:kakao_components/kakao_components.dart';

import 'fixtures.dart';
import 'signal_stub.dart' if (dart.library.js_interop) 'signal_web.dart';

/// The showcase's look-alike mode, for tool/lookalike: the web build opened
/// with `?lookalike=<case id>` shows only that case's fixture, at the web
/// element's width, on the web element's background, then reports where it
/// is. Query: `theme` (a theme name), `contrast=more`, `motion=reduce`,
/// `w` (width in CSS pixels), `bg` (RRGGBB), `settle` (ms to wait).
class LookalikeApp extends StatefulWidget {
  const LookalikeApp({super.key, required this.query});

  final Map<String, String> query;

  /// The query when this run is a look-alike run, else null.
  static Map<String, String>? queryOf(Uri uri) => uri.queryParameters.containsKey('lookalike') ? uri.queryParameters : null;

  /// Room around the subject for its shadow and glow.
  static const margin = 48.0;

  @override
  State<LookalikeApp> createState() => _LookalikeAppState();
}

class _LookalikeAppState extends State<LookalikeApp> {
  final _subject = GlobalKey();

  @override
  void initState() {
    super.initState();
    final settle = int.tryParse(widget.query['settle'] ?? '') ?? 1500;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(Duration(milliseconds: settle), () {
        final box = _subject.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        final o = box.localToGlobal(Offset.zero);
        reportBox(o.dx, o.dy, box.size.width, box.size.height);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query;
    final id = q['lookalike']!;
    final theme = KakaoThemeData.all.firstWhere((t) => t.name == q['theme'], orElse: () => KakaoThemeData.light);
    final bg = int.tryParse(q['bg'] ?? '', radix: 16);
    final width = double.tryParse(q['w'] ?? '');
    final fixture = lookalikeFixtures[id];
    final media = MediaQueryData.fromView(View.of(context)).copyWith(
      highContrast: q['contrast'] == 'more',
      disableAnimations: q['motion'] == 'reduce',
    );

    return MediaQuery(
      data: media,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: KakaoTheme(
          data: theme,
          child: Builder(
            builder: (context) => ColoredBox(
              // The web element's own background, measured by the script.
              color: bg != null ? Color(0xFF000000 | bg) : KakaoTheme.of(context).colors.page,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(LookalikeApp.margin),
                  child: SizedBox(
                    width: width,
                    child: KeyedSubtree(
                      key: _subject,
                      child: fixture == null ? Text('No look-alike fixture "$id"') : fixture(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
