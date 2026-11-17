import 'package:flutter/widgets.dart';

/// What a footer button tells the box it sits in, so that box can fit its
/// corners to it (the nesting rule: outer radius = button radius + padding).
@immutable
class KakaoCornerEntry {
  const KakaoCornerEntry({required this.context, required this.filled, required this.radius});

  /// The button's element; its render box is measured after layout.
  final BuildContext context;

  /// A ghost button has no shape at rest, so it never shapes a corner.
  final bool filled;

  /// The button's own bottom corner radius (half its height when round).
  final double radius;
}

/// Collects the [KakaoCornerEntry]s of the buttons below it. Buttons register
/// while they build and leave when they are disposed; the owner (a dialog)
/// measures them after layout, as dialog.js measures its footer buttons.
class KakaoCornerRegistry {
  KakaoCornerRegistry({this.onChange});

  /// Called when a button (re)registers or leaves: the owner measures again
  /// after the frame (a button can change size without its dialog rebuilding).
  final VoidCallback? onChange;

  final Map<Object, KakaoCornerEntry> _entries = {};

  Iterable<KakaoCornerEntry> get entries => _entries.values;

  void put(Object owner, KakaoCornerEntry entry) {
    _entries[owner] = entry;
    onChange?.call();
  }

  void remove(Object owner) {
    if (_entries.remove(owner) != null) onChange?.call();
  }
}

/// Hands a [KakaoCornerRegistry] down to the buttons in a footer.
class KakaoCornerScope extends InheritedWidget {
  const KakaoCornerScope({super.key, required this.registry, required super.child});

  final KakaoCornerRegistry registry;

  static KakaoCornerRegistry? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<KakaoCornerScope>()?.registry;

  @override
  bool updateShouldNotify(KakaoCornerScope oldWidget) => registry != oldWidget.registry;
}
