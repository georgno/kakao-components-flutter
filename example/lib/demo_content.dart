import 'package:flutter/material.dart' show Icons;
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

// menu/demo.html items. Material icons stand in for menu.js's own glyphs.
// [subject] (look-alike fixtures) goes on the first icon, inside the panel.

Widget _icon(IconData icon, Key? key) => KeyedSubtree(key: key, child: Icon(icon));

/// "Icons, shortcuts, a separator and a danger item".
List<KakaoMenuEntry> fileMenuItems({Key? subject}) => [
  KakaoMenuItem('Rename', value: 'rename', icon: _icon(Icons.edit_outlined, subject), shortcut: 'F2'),
  const KakaoMenuItem('Duplicate', value: 'duplicate', icon: Icon(Icons.content_copy), shortcut: 'Mod+D'),
  const KakaoMenuItem('Download', value: 'download', icon: Icon(Icons.download)),
  const KakaoMenuItem('Archive', value: 'archive', icon: Icon(Icons.archive_outlined), disabled: true),
  const KakaoMenuSeparator(),
  const KakaoMenuItem('Delete', value: 'delete', icon: Icon(Icons.delete_outline), shortcut: 'Del', danger: true),
];

/// "Headings · { group, items }".
List<KakaoMenuEntry> accountMenuItems({Key? subject}) => [
  KakaoMenuGroup(
    label: 'Ada Lovelace',
    items: [
      KakaoMenuItem('Profile', value: 'profile', icon: _icon(Icons.person_outline, subject)),
      const KakaoMenuItem('Settings', value: 'settings', icon: Icon(Icons.tune), shortcut: 'Mod+,'),
    ],
  ),
  const KakaoMenuSeparator(),
  const KakaoMenuGroup(
    label: 'Team',
    items: [
      KakaoMenuItem('Invite people', value: 'invite', icon: Icon(Icons.add)),
      KakaoMenuItem('Shared files', value: 'shared', icon: Icon(Icons.folder_outlined)),
    ],
  ),
  const KakaoMenuSeparator(),
  const KakaoMenuItem('Sign out', value: 'sign-out', icon: Icon(Icons.logout)),
];

/// "type: checkbox and type: radio · keep-open".
const viewMenuItems = <KakaoMenuEntry>[
  KakaoMenuItem('Show sidebar', value: 'sidebar', type: KakaoMenuItemType.checkbox, checked: true, shortcut: 'Mod+B'),
  KakaoMenuItem('Show hidden files', value: 'hidden', type: KakaoMenuItemType.checkbox),
  KakaoMenuSeparator(),
  KakaoMenuGroup(
    label: 'Density',
    items: [
      KakaoMenuItem('Compact', value: 'compact', type: KakaoMenuItemType.radio),
      KakaoMenuItem('Comfortable', value: 'comfortable', type: KakaoMenuItemType.radio, checked: true),
      KakaoMenuItem('Spacious', value: 'spacious', type: KakaoMenuItemType.radio),
    ],
  ),
];

/// "Submenus · children".
const docMenuItems = <KakaoMenuEntry>[
  KakaoMenuItem('Open', value: 'open', shortcut: 'Mod+O'),
  KakaoMenuItem(
    'Share',
    icon: Icon(Icons.share_outlined),
    children: [
      KakaoMenuItem('Copy link', value: 'share-link', icon: Icon(Icons.link)),
      KakaoMenuItem('Email', value: 'share-email'),
      KakaoMenuItem(
        'Export as',
        children: [
          KakaoMenuItem('PDF', value: 'export-pdf'),
          KakaoMenuItem('Word', value: 'export-word'),
          KakaoMenuItem('Plain text', value: 'export-text'),
        ],
      ),
    ],
  ),
  KakaoMenuItem(
    'Move to',
    icon: Icon(Icons.folder_outlined),
    children: [KakaoMenuItem('Inbox'), KakaoMenuItem('Projects'), KakaoMenuItem('Archive')],
  ),
  KakaoMenuSeparator(),
  KakaoMenuItem('Delete', value: 'delete', icon: Icon(Icons.delete_outline), danger: true),
];

/// "An area · context-for".
const canvasMenuItems = <KakaoMenuEntry>[
  KakaoMenuItem('Cut', value: 'cut', icon: Icon(Icons.content_cut), shortcut: 'Mod+X'),
  KakaoMenuItem('Copy', value: 'copy', icon: Icon(Icons.content_copy), shortcut: 'Mod+C'),
  KakaoMenuItem('Paste', value: 'paste', icon: Icon(Icons.content_paste), shortcut: 'Mod+V'),
  KakaoMenuSeparator(),
  KakaoMenuItem('Arrange', children: [KakaoMenuItem('Bring to front'), KakaoMenuItem('Send to back')]),
  KakaoMenuItem('Refresh', value: 'refresh', icon: Icon(Icons.refresh)),
];

/// "Always shown · inline".
const messageMenuItems = <KakaoMenuEntry>[
  KakaoMenuItem('Reply', value: 'reply', shortcut: 'R'),
  KakaoMenuItem('Forward', value: 'forward', shortcut: 'F'),
  KakaoMenuItem('Label as', children: [KakaoMenuItem('Work'), KakaoMenuItem('Private'), KakaoMenuItem('Later')]),
  KakaoMenuSeparator(),
  KakaoMenuItem('Mark as unread', value: 'unread', type: KakaoMenuItemType.checkbox),
  KakaoMenuItem('Delete', value: 'delete', danger: true),
];

// button/demo.html "Menu" and "Toggle" content.

/// "Shows the choice · show-selected": the sort menu.
const sortMenuItems = [
  KakaoButtonMenuItem('newest', label: 'Newest first'),
  KakaoButtonMenuItem('oldest', label: 'Oldest first'),
  KakaoButtonMenuItem('name', label: 'Name'),
  KakaoButtonMenuItem('size', label: 'Size', disabled: true),
];

/// "Segment (exclusive)": the alignment toggles (fas fa-align-* on the web).
const alignmentSegment = [
  ('left', 'Left', Icons.format_align_left),
  ('center', 'Center', Icons.format_align_center),
  ('right', 'Right', Icons.format_align_right),
];

/// The alignment segment: [pressed] is the pressed item's value.
Widget alignmentButtons(String pressed, ValueChanged<String> onPress) => KakaoButtonSegment(
  semanticLabel: 'Alignment',
  children: [
    for (final (value, label, icon) in alignmentSegment)
      KakaoButton(
        icon: Icon(icon),
        semanticLabel: label,
        toggle: true,
        pressed: pressed == value,
        onPressed: () => onPress(value),
      ),
  ],
);

// select/demo.html lists.

/// "Single · child options": the countries.
const countryOptions = [
  KakaoSelectOption('at', label: 'Österreich'),
  KakaoSelectOption('de', label: 'Deutschland'),
  KakaoSelectOption('ch', label: 'Schweiz'),
  KakaoSelectOption('li', label: 'Liechtenstein'),
  KakaoSelectOption('lu', label: 'Luxembourg'),
  KakaoSelectOption('be', label: 'Belgique'),
  KakaoSelectOption('fr', label: 'France'),
  KakaoSelectOption('it', label: 'Italia'),
];

/// "Groups · optgroup": cities, one sold out.
const cityOptions = [
  KakaoSelectGroup('Germany', [
    KakaoSelectOption('Berlin'),
    KakaoSelectOption('Hamburg'),
    KakaoSelectOption('München'),
    KakaoSelectOption('Köln'),
  ]),
  KakaoSelectGroup('Austria', [
    KakaoSelectOption('Wien'),
    KakaoSelectOption('Graz'),
    KakaoSelectOption('Linz'),
    KakaoSelectOption('Salzburg (sold out)', disabled: true),
  ]),
  KakaoSelectGroup('Switzerland', [
    KakaoSelectOption('Zürich'),
    KakaoSelectOption('Genève'),
    KakaoSelectOption('Basel'),
  ]),
];

/// "Multiple · select all": the genres.
const genreOptions = [
  KakaoSelectOption('action', label: 'Action'),
  KakaoSelectOption('comedy', label: 'Comedy'),
  KakaoSelectOption('drama', label: 'Drama'),
  KakaoSelectOption('horror', label: 'Horror'),
  KakaoSelectOption('romance', label: 'Romance'),
  KakaoSelectOption('thriller', label: 'Thriller'),
  KakaoSelectOption('sci-fi', label: 'Science fiction'),
  KakaoSelectOption('doc', label: 'Documentary'),
  KakaoSelectOption('anim', label: 'Animation'),
];

// combobox/demo.html lists.

/// "Suggestions · child options": the countries.
const comboCountries = [
  KakaoComboboxOption('at', label: 'Österreich'),
  KakaoComboboxOption('de', label: 'Deutschland'),
  KakaoComboboxOption('ch', label: 'Schweiz'),
  KakaoComboboxOption('li', label: 'Liechtenstein'),
  KakaoComboboxOption('lu', label: 'Luxembourg'),
  KakaoComboboxOption('be', label: 'Belgique'),
  KakaoComboboxOption('fr', label: 'France'),
  KakaoComboboxOption('it', label: 'Italia'),
];

/// "Groups · optgroup": cities, one sold out.
const comboCities = [
  KakaoComboboxGroup('Germany', [
    KakaoComboboxOption('Berlin'),
    KakaoComboboxOption('Hamburg'),
    KakaoComboboxOption('München'),
    KakaoComboboxOption('Köln'),
  ]),
  KakaoComboboxGroup('Austria', [
    KakaoComboboxOption('Wien'),
    KakaoComboboxOption('Graz'),
    KakaoComboboxOption('Linz'),
    KakaoComboboxOption('Salzburg (sold out)', disabled: true),
  ]),
  KakaoComboboxGroup('Switzerland', [
    KakaoComboboxOption('Zürich'),
    KakaoComboboxOption('Genève'),
    KakaoComboboxOption('Basel'),
  ]),
];

/// "Free text · Use row": the tags.
const comboTags = [
  KakaoComboboxOption('Bug'),
  KakaoComboboxOption('Feature'),
  KakaoComboboxOption('Docs'),
  KakaoComboboxOption('Design'),
  KakaoComboboxOption('Performance'),
  KakaoComboboxOption('Security'),
];

/// "Inline completion": the fruits.
final comboFruits = [
  for (final f in [
    'Apple', 'Apricot', 'Banana', 'Blackberry', 'Blueberry', 'Cherry', //
    'Grape', 'Mango', 'Melon', 'Orange', 'Peach', 'Pear',
  ])
    KakaoComboboxOption(f),
];

/// "Strict · only listed values": the currencies.
const comboCurrencies = [
  KakaoComboboxOption('eur', label: 'Euro'),
  KakaoComboboxOption('chf', label: 'Swiss franc'),
  KakaoComboboxOption('usd', label: 'US dollar'),
  KakaoComboboxOption('gbp', label: 'Pound sterling'),
];

/// "Long list · 200 items": the demo script's products.
final comboProducts = () {
  const words = ['Alpine', 'Basalt', 'Cedar', 'Delta', 'Ember', 'Fjord', 'Granit', 'Harbor', 'Indigo', 'Juniper'];
  const kinds = ['lamp', 'chair', 'table', 'shelf', 'rug', 'vase', 'clock', 'mirror', 'stool', 'bench'];
  return [
    for (var i = 0; i < 200; i++)
      KakaoComboboxOption(
        'p${i + 1}',
        label: '${words[i % 10]} ${kinds[(i ~/ 10) % 10]} ${i < 100 ? 'Classic' : 'Pro'}',
      ),
  ];
}();

// multi-dropdown/demo.html "Product variant" and "Time · hh:mm" segments.
const variantSegments = [
  KakaoMultiDropdownSegment(
    name: 'size',
    label: 'Size',
    options: [
      KakaoMultiDropdownOption('XS'),
      KakaoMultiDropdownOption('S'),
      KakaoMultiDropdownOption('M'),
      KakaoMultiDropdownOption('L'),
      KakaoMultiDropdownOption('XL'),
    ],
  ),
  KakaoMultiDropdownSegment(
    name: 'color',
    label: 'Colour',
    options: [KakaoMultiDropdownOption('black'), KakaoMultiDropdownOption('white'), KakaoMultiDropdownOption('sand')],
  ),
];

final timeSegments = [
  KakaoMultiDropdownSegment(
    name: 'hour',
    label: 'Hour',
    placeholder: 'hh',
    options: [for (var h = 0; h < 24; h++) KakaoMultiDropdownOption('$h'.padLeft(2, '0'))],
  ),
  KakaoMultiDropdownSegment(
    name: 'minute',
    label: 'Minute',
    placeholder: 'mm',
    options: [for (var m = 0; m < 60; m += 5) KakaoMultiDropdownOption('$m'.padLeft(2, '0'))],
  ),
];

// command-palette/demo.html `#main-palette` (the hotkey palette).
const paletteCommands = [
  KakaoCommand('New file', id: 'new-file', group: 'File', shortcut: 'Mod+N'),
  KakaoCommand('Open file…', id: 'open-file', group: 'File', shortcut: 'Mod+O'),
  KakaoCommand('Save', id: 'save', group: 'File', shortcut: 'Mod+S'),
  KakaoCommand('Export as PDF', id: 'export', group: 'File', keywords: ['download', 'print']),
  KakaoCommand('Share with team', id: 'share', group: 'File', disabled: true),
  KakaoCommand('Go to components', id: 'components', group: 'Navigation'),
  KakaoCommand('Go to style guide', id: 'styleguide', group: 'Navigation'),
  KakaoCommand('Change theme', id: 'theme', group: 'Preferences', keywords: ['dark', 'light', 'colours']),
  KakaoCommand('Change language', id: 'language', group: 'Preferences', keywords: ['locale']),
  KakaoCommand('Edit profile', id: 'profile', group: 'Account'),
  KakaoCommand('Sign out', id: 'sign-out', group: 'Account', keywords: ['logout', 'exit']),
];

// command-palette/demo.html "Another key · hotkey": plain strings.
const paletteEditorCommands = [
  KakaoCommand('Format document'),
  KakaoCommand('Toggle word wrap'),
  KakaoCommand('Fold all'),
  KakaoCommand('Unfold all'),
  KakaoCommand('Sort lines'),
  KakaoCommand('Join lines'),
];

// command-palette/demo.html "From script": Material icons stand in for the
// demo's inline SVG icons.
const paletteAdminCommands = [
  KakaoCommand('Add user', id: 'user-add', group: 'Users', icon: Icon(Icons.add)),
  KakaoCommand('List users', id: 'user-list', group: 'Users', icon: Icon(Icons.person_outline)),
  KakaoCommand('Rebuild search index', id: 'reindex', group: 'Maintenance', icon: Icon(Icons.refresh)),
  KakaoCommand('Clear cache', id: 'cache', group: 'Maintenance', value: 'all', icon: Icon(Icons.delete_outline)),
];

// command-palette/demo.html "Inline".
const paletteInlineCommands = [
  KakaoCommand('Copy link', id: 'copy', group: 'Share', shortcut: 'Mod+Shift+C'),
  KakaoCommand('Send by email', id: 'email', group: 'Share', keywords: ['mail']),
  KakaoCommand('Rename', id: 'rename', group: 'Edit', shortcut: 'F2'),
  KakaoCommand('Duplicate', id: 'duplicate', group: 'Edit', shortcut: 'Mod+D'),
];

// text-input/demo.html icons.

/// The demo's inline search icon (`<svg slot="icon" viewBox="0 0 24 24">`: a
/// circle at 11,11, r 6, and `M20 20l-4.5-4.5`, stroke 2, round caps), 1em
/// big in [IconTheme]'s colour, as the slotted SVG takes `currentColor`.
class SearchGlyph extends StatelessWidget {
  const SearchGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    return CustomPaint(
      size: Size.square(icon.size ?? 15),
      painter: _SearchPainter(icon.color ?? const Color(0xFF000000)),
    );
  }
}

class _SearchPainter extends CustomPainter {
  const _SearchPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(11 * k, 11 * k), 6 * k, paint);
    canvas.drawLine(Offset(20 * k, 20 * k), Offset(15.5 * k, 15.5 * k), paint);
  }

  @override
  bool shouldRepaint(_SearchPainter old) => old.color != color;
}

/// password-input/demo.html "Own requirements · list-data".
final passphraseRequirements = [
  KakaoPasswordRequirement.pattern('At least 16 characters', '.{16,}'),
  KakaoPasswordRequirement.pattern('Four words or more', r'(\S+\s+){3,}\S+'),
  KakaoPasswordRequirement.pattern('No word repeated', r'^(?!.*\b(\w+)\b.*\b\1\b)'),
];

/// password-input/demo.html "Set by script · requirements property".
final accountRequirements = [
  KakaoPasswordRequirement.pattern('At least 10 characters', '.{10,}'),
  KakaoPasswordRequirement(label: 'Not your username', test: (v) => v.toLowerCase() != 'ana'),
];

/// tag-input/demo.html "Suggestions": its `list-data`.
const tagSuggestions = ['Bug', 'Feature', 'Docs', 'Design', 'Performance', 'Security', 'Accessibility', 'Refactoring'];
