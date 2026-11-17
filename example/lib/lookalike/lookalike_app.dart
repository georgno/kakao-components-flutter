import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:kakao_components/kakao_components.dart';

import 'fixtures.dart';
import 'signal_stub.dart' if (dart.library.js_interop) 'signal_web.dart';

/// The showcase's look-alike mode, for tool/lookalike: the web build opened
/// with `?lookalike=<case id>` shows only that case's fixture, at the web
/// element's width, on the web element's background, then reports where it
/// is. Query: `theme` (a theme name), `contrast=more`, `motion=reduce`,
/// `w` (width in CSS pixels), `bg` (RRGGBB), `settle` (ms to wait), `open=1`
/// (the case's web element was opened first: the fixture opens itself, see
/// [LookalikeApp.isOpen], and marks its panel with [LookalikeApp.subjectOf]).
class LookalikeApp extends StatefulWidget {
  const LookalikeApp({super.key, required this.query});

  final Map<String, String> query;

  /// The query when this run is a look-alike run, else null.
  static Map<String, String>? queryOf(Uri uri) =>
      uri.queryParameters.containsKey('lookalike') ? uri.queryParameters : null;

  /// Room around the subject for its shadow and glow.
  static const margin = 48.0;

  /// Whether the fixture should open itself (a popover, a menu): `open=1`.
  static bool isOpen(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_OpenCase>()?.open ?? false;

  /// The key an opened fixture puts on something inside its panel. The
  /// reported box is then the panel around it: the outermost box above the
  /// key that is still smaller than the screen.
  static GlobalKey? subjectOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_OpenCase>()?.subject;

  @override
  State<LookalikeApp> createState() => _LookalikeAppState();
}

class _LookalikeAppState extends State<LookalikeApp> {
  final _subject = GlobalKey();
  final _panelSubject = GlobalKey();

  bool get _open => widget.query['open'] == '1';

  @override
  void initState() {
    super.initState();
    final settle = int.tryParse(widget.query['settle'] ?? '') ?? 1500;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(Duration(milliseconds: settle), () {
        final found = (_open ? _panelSubject : _subject).currentContext?.findRenderObject() as RenderBox?;
        if (found == null || !mounted) return;
        var box = found;
        if (_open) {
          final screen = MediaQuery.sizeOf(context);
          for (var p = box.parent; p is RenderBox; p = p.parent) {
            if (p.size.width >= screen.width || p.size.height >= screen.height) break;
            box = p;
          }
        }
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
    final media = MediaQueryData.fromView(View.of(context))
        .copyWith(highContrast: q['contrast'] == 'more', disableAnimations: q['motion'] == 'reduce');

    return MediaQuery(
      data: media,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: KakaoTheme(
          data: theme,
          // Panels (popover, menu) open in an overlay; outside taps need a surface.
          child: TapRegionSurface(
            child: Overlay(
              initialEntries: [
                OverlayEntry(
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
                            child: _OpenCase(
                              open: _open,
                              subject: _panelSubject,
                              child: Builder(
                                builder: (context) =>
                                    fixture == null ? Text('No look-alike fixture "$id"') : fixture(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenCase extends InheritedWidget {
  const _OpenCase({required this.open, required this.subject, required super.child});

  final bool open;
  final GlobalKey subject;

  @override
  bool updateShouldNotify(_OpenCase old) => old.open != open || old.subject != subject;
}
