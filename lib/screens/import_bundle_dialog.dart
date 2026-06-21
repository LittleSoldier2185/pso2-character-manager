import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character_data.dart';
import '../providers/character_provider.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';

// ── Entry points ──────────────────────────────────────────────────

Future<void> showImportBundleFromPath(
    BuildContext context, String bundlePath) async {
  final preview = await ShareService.readBundlePreview(bundlePath);
  if (preview == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invalid or unreadable .pso2char bundle'),
          backgroundColor: Colors.red));
    }
    return;
  }
  if (context.mounted) {
    await showDialog(
      context: context,
      builder: (_) => ImportBundleDialog(preview: preview),
    );
  }
}

Future<void> showImportBundlePicker(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: 'Import character bundle',
    type: FileType.custom,
    allowedExtensions: [kBundleExtension],
  );
  if (result == null || result.files.single.path == null) return;
  if (context.mounted) {
    await showImportBundleFromPath(context, result.files.single.path!);
  }
}

// ── Dialog ────────────────────────────────────────────────────────

enum _ImportMode { newCharacter, asVariant }

class ImportBundleDialog extends StatefulWidget {
  final BundlePreview preview;
  const ImportBundleDialog({super.key, required this.preview});

  @override
  State<ImportBundleDialog> createState() => _ImportBundleDialogState();
}

class _ImportBundleDialogState extends State<ImportBundleDialog> {
  _ImportMode _mode = _ImportMode.newCharacter;

  // New character fields
  late TextEditingController _nameCtrl;
  String? _filenameConflict;
  bool _renameFile = true;

  // Variant fields
  CharacterData? _targetCharacter;
  late TextEditingController _variantNameCtrl;

  String? _thumbnailPath;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.preview.characterName);
    _variantNameCtrl = TextEditingController(text: widget.preview.characterName);
    _checkConflict();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _variantNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkConflict() async {
    if (!mounted) return;
    final provider = context.read<CharacterProvider>();
    final ownerName = provider.allCharacters
        .where((c) =>
            c.gameFileName == widget.preview.originalFileName ||
            (c.characterFilePath?.endsWith(widget.preview.originalFileName) ??
                false))
        .firstOrNull
        ?.name;
    if (ownerName != null && mounted) {
      setState(() {
        _filenameConflict = ownerName;
        _renameFile = true;
      });
    }
  }

  String _buildRenamedFileName() {
    final original = widget.preview.originalFileName;
    final dot = original.lastIndexOf('.');
    if (dot < 0) return original;
    return '${original.substring(0, dot)}_${DateTime.now().millisecondsSinceEpoch}${original.substring(dot)}';
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: 'Add thumbnail image',
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _thumbnailPath = result.files.single.path);
    }
  }

  Future<void> _import() async {
    if (_mode == _ImportMode.asVariant && _targetCharacter == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a character to add the variant to'),
          backgroundColor: Colors.red));
      return;
    }

    final provider = context.read<CharacterProvider>();
    setState(() => _importing = true);

    final String? error;

    if (_mode == _ImportMode.asVariant) {
      final variantName = _variantNameCtrl.text.trim().isEmpty
          ? widget.preview.characterName
          : _variantNameCtrl.text.trim();
      error = await provider.importBundleAsVariant(
        preview: widget.preview,
        character: _targetCharacter!,
        variantName: variantName,
        sourceThumbnailPath: _thumbnailPath,
      );
    } else {
      final characterName = _nameCtrl.text.trim().isEmpty
          ? widget.preview.characterName
          : _nameCtrl.text.trim();
      error = await provider.importBundle(
        preview: widget.preview,
        characterName: characterName,
        customFileName: _renameFile ? _buildRenamedFileName() : null,
        sourceThumbnailPath: _thumbnailPath,
      );
    }

    if (!mounted) return;
    setState(() => _importing = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_mode == _ImportMode.asVariant
              ? 'Added as variant of ${_targetCharacter!.name}'
              : 'Character imported successfully'),
          backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    final raceColor = AppTheme.raceColor(widget.preview.race);
    final characters = context.read<CharacterProvider>().allCharacters;
    final canImport = _mode == _ImportMode.newCharacter ||
        (_mode == _ImportMode.asVariant && _targetCharacter != null);

    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: Row(
        children: [
          Icon(Icons.file_download_outlined, color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          const Text('Import character bundle'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Bundle preview card ───────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: raceColor.withOpacity(0.4)),
                      ),
                      child: Icon(Icons.person_outline,
                          size: 26, color: raceColor.withOpacity(0.5)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.preview.characterName,
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text('${widget.preview.race} · ${widget.preview.gender}',
                              style:
                                  TextStyle(color: raceColor, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(widget.preview.originalFileName,
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11)),
                          if (widget.preview.galleryImageCount > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                                '${widget.preview.galleryImageCount} gallery image${widget.preview.galleryImageCount == 1 ? '' : 's'} included',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Mode selector ─────────────────────────────────
              _label('Import as'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ModeCard(
                      icon: Icons.person_add_outlined,
                      title: 'New character',
                      subtitle: 'Create a new entry in the library',
                      selected: _mode == _ImportMode.newCharacter,
                      onTap: () =>
                          setState(() => _mode = _ImportMode.newCharacter),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModeCard(
                      icon: Icons.call_split_rounded,
                      title: 'Add as variant',
                      subtitle: 'Add to an existing character',
                      selected: _mode == _ImportMode.asVariant,
                      onTap: () =>
                          setState(() => _mode = _ImportMode.asVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Mode-specific fields ──────────────────────────
              if (_mode == _ImportMode.newCharacter) ...[
                _label('Character name'),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                      hintText: widget.preview.characterName),
                  style:
                      TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                ),
                if (_filenameConflict != null) ...[
                  const SizedBox(height: 12),
                  _ConflictBox(
                    fileName: widget.preview.originalFileName,
                    ownerName: _filenameConflict!,
                    renameFile: _renameFile,
                    onRenameChanged: (v) => setState(() => _renameFile = v),
                  ),
                ],
              ] else ...[
                _label('Add as variant of'),
                const SizedBox(height: 8),
                _CharacterPickerTile(
                  selected: _targetCharacter,
                  characters: characters,
                  onPick: (c) => setState(() => _targetCharacter = c),
                  onClear: () => setState(() => _targetCharacter = null),
                ),
                const SizedBox(height: 12),
                _label('Variant name'),
                const SizedBox(height: 6),
                TextField(
                  controller: _variantNameCtrl,
                  decoration: InputDecoration(
                      hintText: widget.preview.characterName),
                  style:
                      TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                ),
              ],

              // ── Thumbnail ─────────────────────────────────────
              const SizedBox(height: 14),
              _label('Thumbnail (optional)'),
              const SizedBox(height: 6),
              _ThumbnailPicker(
                imagePath: _thumbnailPath,
                onPick: _pickImage,
                onClear: () => setState(() => _thumbnailPath = null),
                onDrop: (p) => setState(() => _thumbnailPath = p),
              ),

              // ── Description preview ───────────────────────────
              if (widget.preview.description != null &&
                  widget.preview.description!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _label('Description'),
                const SizedBox(height: 4),
                Text(widget.preview.description!,
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: (_importing || !canImport) ? null : _import,
          icon: _importing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.file_download_outlined, size: 15),
          label: Text(_importing ? 'Importing…' : 'Import'),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500));
}

// ── Mode card ─────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.accent : AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accent.withOpacity(0.08)
              : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 3),
            Text(subtitle,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Character picker tile ─────────────────────────────────────────

class _CharacterPickerTile extends StatelessWidget {
  final CharacterData? selected;
  final List<CharacterData> characters;
  final void Function(CharacterData) onPick;
  final VoidCallback onClear;

  const _CharacterPickerTile({
    required this.selected,
    required this.characters,
    required this.onPick,
    required this.onClear,
  });

  Future<void> _openPicker(BuildContext context) async {
    String query = '';
    final picked = await showDialog<CharacterData>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final filtered = query.isEmpty
              ? characters
              : characters
                  .where((c) =>
                      c.name.toLowerCase().contains(query.toLowerCase()))
                  .toList();
          return AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search characters…',
                prefixIcon: Icon(Icons.search_rounded,
                    size: 16, color: AppTheme.textSecondary),
              ),
              onChanged: (v) => setSt(() => query = v),
            ),
            content: SizedBox(
              width: 320,
              height: 340,
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No characters found',
                          style:
                              TextStyle(color: AppTheme.textSecondary)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final rc = AppTheme.raceColor(c.race);
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                                color: rc, shape: BoxShape.circle),
                          ),
                          title: Text(c.name,
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13)),
                          subtitle: Text(
                              '${c.race} · ${c.gender} · ${c.variants.length} variant${c.variants.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11)),
                          onTap: () => Navigator.pop(ctx, c),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
            ],
          );
        },
      ),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    if (selected == null) {
      return GestureDetector(
        onTap: characters.isEmpty ? null : () => _openPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppTheme.borderColor,
                style: BorderStyle.solid),
          ),
          child: Row(
            children: [
              Icon(Icons.person_search_outlined,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                characters.isEmpty
                    ? 'No characters in library'
                    : 'Tap to select a character…',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final rc = AppTheme.raceColor(selected!.race);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: rc, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selected!.name,
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Text(
                    '${selected!.race} · ${selected!.gender} · ${selected!.variants.length} variant${selected!.variants.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _openPicker(context),
            child: Icon(Icons.swap_horiz_rounded,
                size: 15, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Conflict box ──────────────────────────────────────────────────

class _ConflictBox extends StatelessWidget {
  final String fileName;
  final String ownerName;
  final bool renameFile;
  final void Function(bool) onRenameChanged;

  const _ConflictBox({
    required this.fileName,
    required this.ownerName,
    required this.renameFile,
    required this.onRenameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 13, color: AppTheme.accentGold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '"$fileName" is already owned by "$ownerName".',
                  style: TextStyle(
                      color: AppTheme.accentGold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _RadioChoice(
                label: 'Rename (safe)',
                selected: renameFile,
                onTap: () => onRenameChanged(true),
              ),
              const SizedBox(width: 12),
              _RadioChoice(
                label: 'Replace existing',
                selected: !renameFile,
                onTap: () => onRenameChanged(false),
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Radio choice ──────────────────────────────────────────────────

class _RadioChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _RadioChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accent;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? c : AppTheme.borderColor, width: 1.5),
              color: selected ? c : Colors.transparent,
            ),
            child: selected
                ? const Icon(Icons.circle, size: 6, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: selected ? c : AppTheme.textSecondary,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Thumbnail picker ──────────────────────────────────────────────

class _ThumbnailPicker extends StatefulWidget {
  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final void Function(String) onDrop;

  const _ThumbnailPicker({
    required this.imagePath,
    required this.onPick,
    required this.onClear,
    required this.onDrop,
  });

  @override
  State<_ThumbnailPicker> createState() => _ThumbnailPickerState();
}

class _ThumbnailPickerState extends State<_ThumbnailPicker> {
  static const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (d) {
            setState(() => _dragging = false);
            final path = d.files.firstOrNull?.path;
            if (path != null &&
                _imageExts.contains(path.split('.').last.toLowerCase())) {
              widget.onDrop(path);
            }
          },
          child: GestureDetector(
            onTap: widget.onPick,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _dragging
                    ? AppTheme.accent.withOpacity(0.08)
                    : AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _dragging ? AppTheme.accent : AppTheme.borderColor,
                  width: _dragging ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: widget.imagePath != null
                  ? Image.file(File(widget.imagePath!), fit: BoxFit.cover)
                  : Icon(Icons.image_outlined,
                      size: 24, color: AppTheme.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: widget.onPick,
                icon: const Icon(Icons.image_outlined, size: 14),
                label: Text(
                  widget.imagePath == null ? 'Add thumbnail' : 'Change thumbnail',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: BorderSide(color: AppTheme.borderColor),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
              ),
              if (widget.imagePath != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: widget.onClear,
                  child: Text('Remove',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
