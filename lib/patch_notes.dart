import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

// ── Data ──────────────────────────────────────────────────────────

class _PatchEntry {
  final String version;
  final String title;
  final String body;
  const _PatchEntry(this.version, this.title, this.body);
}

const _entries = [
  _PatchEntry('1.5.0', 'Albums (major), recycle bin, list view & more', '''
ALBUMS — MAJOR UPDATE

• Albums — a new "Albums" entry in the sidebar for grouping gallery images
  into named, ordered collections. A single image can belong to multiple
  albums. Albums are sorted by last modified date and can be renamed,
  deleted, or have their tags edited from the right-click context menu.

• Album detail page — opens when you click any album. Shows the cover image,
  total image count, the characters featured, creation date, last edit date,
  and assigned tags. A thumbnail strip at the bottom lets you jump to any
  image directly — click a thumbnail to open the reader at that exact position
  rather than always starting from the beginning.

• Full-screen reader — three layout modes selectable from the toolbar:
  — Horizontal — left-to-right page flip (default)
  — Vertical — continuous top-to-bottom scroll
  — Book spread — 2-page side-by-side layout, like a manga reader
  Supports pinch-to-zoom up to 5× and free pan at any zoom level.
  Keyboard arrow keys and scroll wheel also turn pages.
  Auto-play mode cycles through pages automatically on a configurable
  interval (1–10 seconds). Swipe gestures work in horizontal mode.

• Album manage mode — a dedicated two-panel workspace:

  Left panel — form with:
    — Cover thumbnail preview (live, shows the first image in the album)
    — Name text field
    — Description — shown as a read-only preview; tap the Edit button to
      open a large floating dialog for comfortable multi-line editing
    — Tags — assigned tags shown as chips; tap "+ Tag" to open a floating
      search-and-toggle picker to add or remove any album tag
    — Characters — each character in the album listed with their avatar,
      name, and image count
    — Save and Cancel buttons pinned to the bottom of the panel

  Right panel — image list with a list/grid toggle in the toolbar:
    — List view — reorderable with a drag handle on each row; remove button
      on the right
    — Grid view — card thumbnails with order number and Cover badge; long-
      press and drag any card to reorder; remove button on each card

• Album Tags — a separate tag system exclusively for albums, completely
  independent from character tags. Managed in the new "Album Tags" screen
  reachable from a sub-navigation item under Albums in the sidebar.

  The Album Tags screen shows:
    — Stat cards: total tags, in-use count, unused count with a one-tap
      "Delete all unused" button
    — Tag cards: colour bar, tag chip preview, and usage count
    — Sort options: name A–Z / Z–A, most / least used, newest / oldest
    — Search bar to filter the tag list
    — Create / edit dialog with a full colour picker and live preview

  Clicking any tag in this screen jumps to the Albums screen
  pre-filtered to show only albums that have that tag.

• Tag filter — the Albums toolbar has a "Filter ▾" button that opens a
  searchable popover listing all album tags. Toggle any tag to filter the
  album grid. A numbered badge on the button shows how many filters are
  active. Tap Filter again or click outside to close.

• Tags on detail page — the album info panel now shows the album's assigned
  tags alongside the other metadata (name, description, characters, dates).

• Album export — export any album from the detail page as a ZIP archive
  (one image file per entry) or a multi-page PDF (each image fills one page,
  sized to fit). Accessible via the Export button in the detail view.

NEW FEATURES

• Recycle bin — deleting a character now moves it to a recycle bin instead
  of permanently removing it. Items are automatically purged after 7 days.
  A new "Recycle Bin" entry in the sidebar shows a badge with the item count.
  From the recycle bin screen you can restore any character back to your
  library or permanently delete it early. An "Empty bin" button clears
  everything at once. Items expiring within 24 hours are highlighted in red.

• Compact list view — a new "List view" option in the card size picker
  (below the existing Small / Medium / Large / Extra large grid modes)
  switches the home screen to a dense single-column list. Each row shows
  a small thumbnail, tier badge, name, race/gender, and last modified date.

• Last modified date — every character now tracks when it was last edited.
  The date appears in list view as a relative label (Today, Yesterday, 3d ago…).
  A new "Last modified" sort option is available in the sort menu across
  all screens that support sorting.

• Bulk actions — long-press any character card to enter selection mode.
  Tap additional cards to select them, then use the action bar to:
  — Move all selected characters to the recycle bin (library screen)
  — Add them to a collection (library screen)
  — Manage tags across all selected characters (library screen)
  — Unapply multiple characters at once (applied screen)

• Responsive dialogs — all dialogs and panels now shrink to fit smaller
  windows. Previously, dialogs had fixed widths and would overflow if the
  window was too narrow.

• Random spinner filters now persist — whitelist, blacklist, and the
  "Include variants" toggle are remembered when you close and reopen the
  spinner within the same session. Filters reset when the app is closed.

• Bulk tag management — with one or more characters selected, a new
  "Tags" button appears in the selection bar. Tap any tag once to mark
  it for adding to all selected characters, twice to mark it for removal,
  three times to clear the action. Confirm with Apply.

• Apply history — every apply and unapply is now recorded. Open
  Settings → About → Apply history to browse the last 100 events with
  character name, variant, action (applied / unapplied), and relative
  timestamp.

• Library backup — Settings → Storage → Backup library exports your
  entire character library (characters, collections, tags, thumbnails,
  gallery) to a dated zip file. The recycle bin is excluded to keep the
  file size manageable.

• Find duplicates — Settings → Storage → Find duplicates scans every
  character file and groups any that share identical content. Results
  show the character names and race/gender for each duplicate group.

• Gallery captions — right-click any image in the gallery and choose
  "Add caption" to attach a short note to that image. Captions appear
  in the info panel on Large and Extra large grid sizes, and as an
  overlay in the fullscreen viewer. The gallery search bar now also
  matches against captions.

CHARACTER CARD EXPORT

• Export as card image — each character can now be exported as a PNG
  image card. Open a character, tap the share icon, and choose
  "Export as card image". Individual variants also have this option
  in their right-click menu.

  The card shows the character's thumbnail, name, tier badge, race,
  gender, and tags in a full-bleed layout.

  The exported PNG has all character data embedded inside it —
  name, race, gender, tier, tags, description, and the actual
  character file. Anyone with PSO2 Character Manager can import it
  directly using the download button on the home screen →
  "Import from card image".

• Import from card — the download button on the home screen now
  offers two options: "Import from card image" and
  "Import .pso2char bundle". Picking a card PNG extracts all
  embedded data and creates a new character entry, including tags
  (created automatically if they do not exist yet).

HOW TO SHARE A CARD (IMPORTANT)

  The card image carries embedded character data. Whether that data
  survives sharing depends entirely on how you send the file.

  Safe to share — these services send the original file untouched:
    ✓ Google Drive
    ✓ Dropbox
    ✓ OneDrive
    ✓ Email attachment
    ✓ Direct file transfer (USB, LAN, etc.)

  DATA WILL BE LOST on these platforms — they re-encode all images
  and strip everything except the pixels:
    ✗ Discord — re-encodes all image files including attachments
    ✗ Twitter / X
    ✗ WhatsApp
    ✗ Facebook / Instagram / Threads
    ✗ Imgur, Gyazo, Lightshot, or any image host

  The card will still look correct as an image, but it can no longer
  be imported.

  To share on Discord with import data intact, zip the PNG first
  and send the .zip file — Discord does not re-encode non-image
  file types.

BUG FIXES

• Random spinner — whitelisting a specific variant now correctly restricts
  the spin pool to only that variant. Previously, all main variants from
  other characters were still included alongside the whitelisted entry.
  The "Include variants" toggle is now correctly ignored when exact variants
  are whitelisted.

• Auto-updater — the installer now waits 3 seconds after the app closes
  before copying files. This prevents the occasional "file in use" error
  on desktop_drop_plugin.dll and similar DLLs that Windows holds briefly
  after a process exits. Robocopy retry limits are also tightened so that
  if a lock does occur, the wait is 2 seconds instead of 30.

'''),
  _PatchEntry('1.4.4', 'QoL improvements', '''
IMPROVEMENTS

• Variant cards — left-click now instantly applies a variant; clicking an
  already-applied variant unapplies it. Right-click still opens the context menu.

• Auto-fill name — adding a new character now pre-fills the name field from
  the filename. You can still edit it freely before saving.

• Rename file — the Main File section in character detail now has an edit button
  to rename the character file's name and extension (e.g. fhp → mhp) directly
  from the app. Works on both the main variant and any individual variant.

• Main File label — the "Character file" section in character detail has been
  renamed to "Main File" for clarity.

• Thumbnail blur — blurred thumbnails now apply in the random character spinner
  and collection auto-thumbnails (when no custom collection thumbnail is set).
'''),
  _PatchEntry('1.4.3', 'Auto-updater reliability fix', '''
BUG FIX

• Auto-updater — switched from a PowerShell script to a batch file for
  the install step, which is more reliable on end-user machines.
  The app now consistently relaunches after a successful update.
'''),
  _PatchEntry('1.4.2', 'Manual download option', '''
IMPROVEMENT

• Manual download — when a new version is available, you can now choose
  between updating automatically or opening the GitHub release page to
  download and install manually.
'''),
  _PatchEntry('1.4.1', 'Bug fix', '''
BUG FIXES

• Auto-updater — the app now reopens automatically after a successful update
  instead of silently stopping mid-install.

• Version number — now shows the correct version after an update instead of
  continuing to display the old version number.
'''),
  _PatchEntry('1.4.0', 'Tier effects, Theme customisation & Tag manager', '''
IMPROVEMENTS

• Tag manager — three quality-of-life improvements:
  Click any tag card to filter the home screen by that tag instantly.
  Unused stat card now has a sweep button to delete all unused tags at once.
  Stats row always shows global counts — no longer affected by the search filter.

• Accent colour — pick any colour from the wheel or choose a quick preset
  (Cyan, Azure, Purple, Gold, Green, Coral) in Settings → Appearance.

• Background colour — new picker lets you set the app's background tone.
  Choose from twelve presets — six dark (Midnight, Void, Navy, Dusk, Grove,
  Ember) and six light (Pearl, Ivory, Mist, Petal, Sage, Slate) — or open
  the colour wheel for a fully custom colour. Light backgrounds automatically
  flip to dark text and lighter borders so everything stays readable. All
  three background levels (dark, card, surface) are derived automatically
  from the chosen base.

• Both colour changes apply instantly across the whole UI with no restart.

• Tier borders — each tier now has a unique animated border on character cards:
  S rainbow, A gold shimmer, B silver shimmer, C copper shimmer, D plain gray.
  B tier updated from green → silver, C tier updated from blue → copper.

• Settings panel reworked into a floating glassmorphism overlay dialog that
  can be opened from any page without navigating away.

• Settings dialog redesigned with a sidebar nav (Appearance / Cards / Storage / About).
  The panel is now 16:9 and scales responsively with the window.

• Tier border animations are now customisable per tier in Settings → Cards.
  Each tier has its own pool of 3–4 unique effects to choose from:

  S — Rainbow, Aurora Pulse, Prismatic Sparkle, Holographic
  A — Shimmer, Pulse Glow, Double Ring, Molten
  B — Shimmer, Double Ring, Electric Arc, Particle Sparks
  C — Shimmer, Dashed Rotation, Plasma Wave, Ember Glow
  D — None, Subtle Pulse, Dim Flicker

  Changes apply via an Apply button and persist across sessions.

PER-CHARACTER BORDER CUSTOMISATION

• Custom border — each character detail screen now has a Border section
  below the tier picker. Toggle between "Use tier" (follows global tier
  settings) and "Custom" to override independently.

• Effect — a dropdown with all sixteen effects. Selecting one updates
  the card immediately.

• Color — nine presets, a colour wheel, and a ✕ swatch to clear back
  to the tier colour.

• S-tier effects (Rainbow, Aurora Pulse, Prismatic Sparkle, Holographic)
  disable the colour row — those effects use built-in colour cycles.

• No tier required — characters without a tier can still have a custom
  border (falls back to accent colour and Shimmer effect).

IMPORT & ADD CHARACTER

• Add as variant — Add Character and both import flows (bundle and scan)
  now let you add a file as a variant of an existing character instead of
  creating a new top-level entry. A two-card mode selector appears at the
  top: "New character" keeps the existing behaviour; "Add as variant"
  shows a searchable character picker and a variant name field.

• Import bundle rework — the import dialog now opens with the mode
  selector upfront. Conflict resolution only appears in "New character"
  mode. The Import button stays disabled until a target is chosen in
  variant mode.

• Scan import dialog — clicking Import on a scan result now opens a
  dialog instead of importing immediately with no options. "Import all"
  in the toolbar still bulk-imports without a dialog.

• Thumbnail picker — all three import flows include an optional thumbnail
  field. Click to pick an image or drag and drop one directly onto the
  preview box (jpg, jpeg, png, gif, webp, bmp).

SEARCH REWORK

• Keyword search — the search bar now filters live as you type. No more
  "type keyword + Enter" token workflow. Just type and the grid updates
  instantly. The X button clears the search.

• Tag filtering remains in the filter panel (tune icon) along with tier,
  race, gender, collection, and applied status filters.

• The Apply button and keyword token pills have been removed.

APPLIED SCREEN

• Applied screen now shows one card per applied variant. If a character
  has both a main file and a variant applied, each appears as its own card
  with its own thumbnail and the variant name labelled below the character
  name.
'''),
  _PatchEntry('1.3.4', 'In-app auto-update', '''
IMPROVEMENT
• The app can now update itself. When a new version is detected, clicking
  the update button downloads the release zip, extracts it, and restarts
  the app automatically — no browser or manual install needed.
  Falls back to opening the GitHub release page if no zip is attached.
'''),
  _PatchEntry('1.3.3', 'Migration backup', '''
IMPROVEMENT
• Migration now backs up all your old data before creating the new structure.
  Hive database files, character data files, thumbnails, and gallery images
  are saved to Documents\\PSO2CharacterManager\\hive_backup before anything
  is moved or converted. You can delete this folder once migration looks good.
'''),
  _PatchEntry('1.3.2', 'Hotfix', '''
BUG FIXES
• Fixed "Check for updates" not detecting new versions when GitHub release
  tags use a capital V (e.g. V1.3.1 instead of v1.3.1).
'''),
  _PatchEntry('1.3.1', 'Hotfix', '''
BUG FIX
• Fixed data migration not working for users upgrading from v1.2.0.
  The migration was searching for Hive database files in the wrong folder
  and silently skipping all characters as a result. All your characters,
  collections, tags, and gallery images will now migrate correctly.

If you already ran v1.3.0 and your data appeared empty, delete the app data
folder (Documents\\PSO2CharacterManager) and re-launch v1.3.1 — it will
re-read the original v1.2.0 files and migrate them properly.
'''),
  _PatchEntry('1.3.0', 'Major overhaul', '''
MAJOR UPDATES

• PSO2 Salon Limit Removed
  The 50-character slot cap is gone — unlimited characters can now be applied.
  Slot numbers have been removed from cards and the applied screen.

• Sync / Update Detection (Reworked)
  Replaced the per-card sync badges with a dedicated "Sync from game" sidebar
  item. Opens a dialog listing every character with a newer game-folder file.
  Each entry has Update, Add new, and Ignore actions. Supports all variants.

• Variant System Overhaul
  Variants now have a card size picker (Small / Medium / Large / XL),
  drag-to-reorder, a full right-click menu (Rename, Duplicate, Change thumbnail,
  Export as bundle, Delete), and show filename + last-synced date on Medium+.

• Custom Title Bar
  Native Windows title bar replaced with a dark-themed custom bar matching
  the app's color scheme. Fully draggable with minimize / maximize / close.

• Collapsible Sidebar
  Sidebar collapses to a 56 px icon-only rail with a smooth animation.
  All items show tooltips in collapsed mode.

MINOR UPDATES

• Collections — Edit button moved to detail view; search added to edit dialog.
• Applied Screen — Search bar, sort menu, and card size picker added.
• Gallery — Right-click menu: Copy to clipboard / Set as thumbnail.
• Random Spinner — Variants can now enter the spin pool as individual entries.
• Open Character Folder — Folder button in the detail screen header opens
  the character's data folder in Windows Explorer.
• App Update Checker — Startup check against GitHub releases. Gold badge in
  sidebar when update available. Check for updates button in Settings → About,
  with a release notes dialog before downloading.
• First-run Setup Prompt — Guides new users to set the game folder on first launch.
• Persistent Sort — The selected sort option is restored on next launch.

BUG FIXES

• Tier sort now orders A → Z within each tier instead of random order.

PERFORMANCE

• Skeleton loading screens on all main screens — no more blank states on startup.
• IndexedStack navigation — switching between screens is instant.
• Thumbnail decode flash eliminated.

INFRASTRUCTURE

• Storage migrated from Hive binary database to human-readable JSON files.
  Migration runs automatically on first launch — no data is lost.
'''),
  _PatchEntry('1.2.0', 'Tier system, character bundles & search rework', '''
BUG FIXES

• Sync detection — update checks now run against all registered characters,
  not just applied ones.
• Sync timer — manual sync check now correctly resets the 30-second auto
  interval to avoid duplicate checks.
• Random spinner — clicking Reroll now rebuilds and spins in one tap
  instead of requiring two.

NEW FEATURES

• Tier rating — rate characters S / A / B / C / D. Tier badge on card
  thumbnail, coloured border per tier, sort by tier, and tier filter in
  the filter panel. Random spinner supports tier whitelisting/blacklisting.

• Character bundles — export and import characters as .pso2char bundles
  (zip with character file, thumbnail, gallery, and metadata). Import
  preview shows contents before committing. Drag and drop .pso2char files
  anywhere in the app.

• Collection detail redesign — left panel with thumbnail, character count,
  and info. Character grid with size picker, sort, and searchable multi-
  select add dialog.

• Card size picker — Extra large / Large / Medium / Small for both the
  library grid and gallery screen. Cards scale displayed info with size.

IMPROVEMENTS

• Search — live filtering by name. Tag filter moved to the filter panel
  with whitelist/blacklist per tag and AND/OR toggle.
• Filter presets — save, name, colour-code, and one-tap restore any
  combination of active filters. Optional persist on close.
• Collections grid — sort button added (name, most characters, newest).
'''),
  _PatchEntry('1.1.0', 'Tag manager, gallery blur & collection colours', '''
BUG FIXES

• Tag search — search bar tokens now correctly find characters by tag name.
• Favourites sort — primary sort (name, date, etc.) is now fully respected
  within both the favourites and non-favourites groups.
• Scan import crash — imported files are copied into app storage before
  saving, preventing a crash when applying scanned characters.

IMPROVEMENTS

• Tag manager — live search bar, sort menu (name, usage, date), and
  timestamp for time-based sorting.

• Gallery blur — hover any image in character or global gallery and click
  the eye icon to blur or unblur sensitive images. Blur persists across
  sessions and syncs between both galleries.

• Collection colours — cards now tint with the collection accent colour.
  Full HSV colour wheel added — no longer limited to 6 presets.
'''),
  _PatchEntry('1.0.0', 'First stable release', '''
NEW FEATURES

• Character library — grid view of all your characters with thumbnail,
  name, race, gender, description, and tags. Sort by name, date, or last
  applied. Filter by race, gender, applied status, and collection.

• Apply to game — copy up to 50 character files to your PSO2 game folder
  with one click. Slot tracking (1–50) with a progress bar on the applied
  screen.

• Collections — organise characters into named groups. One character can
  belong to multiple collections. 2×2 preview thumbnail or custom image.

• Tags — create custom tags and assign them to characters for easy
  filtering.

• Import — drag and drop character files and thumbnails from Windows
  Explorer, or scan your PSO2 game folder for unregistered files.

• Export — export any character file to any folder.

• Settings — set a custom save location, configure your PSO2 game folder,
  and choose from 6 accent colours.
'''),
];

// ── Body parser ───────────────────────────────────────────────────

const _kGreen = Color(0xFF56D364);
const _kRed   = Color(0xFFFF7B72);

List<InlineSpan> _parseBody(String body, TextStyle base, TextStyle bold) {
  final spans = <InlineSpan>[];
  for (final line in body.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      spans.add(TextSpan(text: '\n', style: base));
      continue;
    }
    // All-caps section headers (IMPROVEMENTS, BUG FIXES, MAJOR UPDATES…)
    if (trimmed == trimmed.toUpperCase() && trimmed.contains(RegExp(r'[A-Z]'))) {
      spans.add(TextSpan(text: '$line\n', style: bold));
      continue;
    }
    // ✓ safe lines → green
    if (trimmed.startsWith('✓')) {
      spans.add(TextSpan(text: '$line\n', style: base.copyWith(color: _kGreen)));
      continue;
    }
    // ✗ unsafe lines → red
    if (trimmed.startsWith('✗')) {
      spans.add(TextSpan(text: '$line\n', style: base.copyWith(color: _kRed)));
      continue;
    }
    // Bullet lines: bold up to the em-dash; rest is normal
    if (trimmed.startsWith('•')) {
      final dashIdx = line.indexOf('—');
      if (dashIdx != -1) {
        spans.add(TextSpan(children: [
          TextSpan(text: line.substring(0, dashIdx), style: bold),
          TextSpan(text: '${line.substring(dashIdx)}\n', style: base),
        ]));
      } else {
        // No dash: the whole bullet line is the feature name
        spans.add(TextSpan(text: '$line\n', style: bold));
      }
      continue;
    }
    spans.add(TextSpan(text: '$line\n', style: base));
  }
  return spans;
}

// ── Dialog ────────────────────────────────────────────────────────

void showPatchNotesDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _PatchNotesDialog(),
  );
}

class _PatchNotesDialog extends StatefulWidget {
  const _PatchNotesDialog();

  @override
  State<_PatchNotesDialog> createState() => _PatchNotesDialogState();
}

class _PatchNotesDialogState extends State<_PatchNotesDialog> {
  _PatchEntry _selected = _entries.first;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_PatchEntry> get _filtered => _query.isEmpty
      ? _entries
      : _entries
          .where((e) =>
              e.version.contains(_query) ||
              e.title.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final w = (screen.width * 0.75).clamp(520.0, 1100.0);
    final h = (w * 9 / 16).clamp(0.0, screen.height * 0.90);
    final fontSize = (13.0 + (w - 520) / (1100 - 520) * 4).clamp(13.0, 17.0);
    final filtered = _filtered;

    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: w,
        height: h,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Divider(height: 1, color: AppTheme.borderColor),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSidebar(filtered),
                    VerticalDivider(
                        width: 1, thickness: 1, color: AppTheme.borderColor),
                    Expanded(child: _buildContent(fontSize)),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.borderColor),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text(
              'Patch notes',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close,
                  size: 16, color: AppTheme.textSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );

  Widget _buildSidebar(List<_PatchEntry> filtered) => SizedBox(
        width: 172,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() {
                  _query = v;
                  final nf = v.isEmpty
                      ? _entries
                      : _entries
                          .where((e) =>
                              e.version.contains(v) ||
                              e.title.toLowerCase().contains(v.toLowerCase()))
                          .toList();
                  if (nf.isNotEmpty && !nf.contains(_selected)) {
                    _selected = nf.first;
                  }
                }),
                style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search…',
                  hintStyle: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 14, color: AppTheme.textSecondary),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: AppTheme.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.accent),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: AppTheme.borderColor),
            // Version list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No results',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 6),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        final active = e == _selected;
                        return _VersionItem(
                          entry: e,
                          selected: active,
                          onTap: () => setState(() => _selected = e),
                        );
                      },
                    ),
            ),
          ],
        ),
      );

  Widget _buildContent(double fontSize) {
    final base = TextStyle(
        color: AppTheme.textSecondary, fontSize: fontSize, height: 1.7);
    final bold = base.copyWith(
        color: AppTheme.textPrimary, fontWeight: FontWeight.w600);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'v${_selected.version} — ${_selected.title}',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: fontSize + 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text.rich(TextSpan(
              children: _parseBody(_selected.body.trim(), base, bold))),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
}

// ── Sidebar item ──────────────────────────────────────────────────

class _VersionItem extends StatefulWidget {
  final _PatchEntry entry;
  final bool selected;
  final VoidCallback onTap;
  const _VersionItem(
      {required this.entry, required this.selected, required this.onTap});

  @override
  State<_VersionItem> createState() => _VersionItemState();
}

class _VersionItemState extends State<_VersionItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.15)
                : _hovered
                    ? AppTheme.bgSurface
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? AppTheme.accent.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'v${widget.entry.version}',
                style: TextStyle(
                  color: active ? AppTheme.accent : AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.entry.title,
                style: TextStyle(
                  color: active
                      ? AppTheme.accent.withValues(alpha: 0.8)
                      : AppTheme.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
