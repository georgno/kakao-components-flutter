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
