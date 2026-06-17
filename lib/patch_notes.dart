import 'package:flutter/material.dart';
import 'services/app_update_service.dart';
import 'theme/app_theme.dart';

const kPatchNotes = '''
v1.3.4 — In-app auto-update

IMPROVEMENT
• The app can now update itself. When a new version is detected, clicking
  the update button downloads the release zip, extracts it, and restarts
  the app automatically — no browser or manual install needed.
  Falls back to opening the GitHub release page if no zip is attached.

────────────────────────────────────────

v1.3.3 — Migration backup

IMPROVEMENT
• Migration now backs up all your old data before creating the new structure.
  Hive database files, character data files, thumbnails, and gallery images
  are saved to Documents\\PSO2CharacterManager\\hive_backup\ before anything
  is moved or converted. You can delete this folder once migration looks good.

────────────────────────────────────────

v1.3.2 — Hotfix

BUG FIXES
• Fixed "Check for updates" not detecting new versions when GitHub release
  tags use a capital V (e.g. V1.3.1 instead of v1.3.1).

────────────────────────────────────────

v1.3.1 — Hotfix

BUG FIX
• Fixed data migration not working for users upgrading from v1.2.0.
  The migration was searching for Hive database files in the wrong folder
  and silently skipping all characters as a result. All your characters,
  collections, tags, and gallery images will now migrate correctly.

If you already ran v1.3.0 and your data appeared empty, delete the app data
folder (Documents\\PSO2CharacterManager) and re-launch v1.3.1 — it will
re-read the original v1.2.0 files and migrate them properly.

────────────────────────────────────────

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
''';

void showPatchNotesDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    "What's new in v$kAppVersion",
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        size: 16, color: AppTheme.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderColor),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Text(
                  kPatchNotes.trim(),
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.7),
                ),
              ),
            ),

            // Footer
            const Divider(height: 1, color: AppTheme.borderColor),
            Padding(
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
            ),
          ],
        ),
      ),
    ),
  );
}
