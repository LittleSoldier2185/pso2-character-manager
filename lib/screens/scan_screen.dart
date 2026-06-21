import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';
import '../models/character_data.dart';
import '../theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<String> _scannedFiles = [];
  bool _scanning = false;
  bool _hasScanned = false;

  Future<void> _scan(CharacterProvider provider) async {
    setState(() { _scanning = true; _scannedFiles = []; _hasScanned = false; });
    final files = await provider.scanGameFolderForUnregistered();
    if (mounted) {
      setState(() {
        _scanning = false;
        _scannedFiles = files;
        _hasScanned = true;
      });
    }
  }

  Future<void> _importAll(CharacterProvider provider) async {
    final files = List<String>.from(_scannedFiles);
    for (final path in files) {
      await provider.importLocalFile(
        name: _fileNameWithoutExt(path),
        localFilePath: path,
      );
      if (mounted) setState(() => _scannedFiles.remove(path));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported ${files.length} character${files.length == 1 ? '' : 's'}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showImportDialog(
      BuildContext context, CharacterProvider provider, String path) async {
    final imported = await showDialog<bool>(
      context: context,
      builder: (_) => _ScanImportDialog(
        filePath: path,
        provider: provider,
      ),
    );
    if (imported == true && mounted) {
      setState(() => _scannedFiles.remove(path));
    }
  }

  String _fileNameWithoutExt(String path) {
    final base = path.split(r'\').last.split('/').last;
    final dot = base.lastIndexOf('.');
    return dot == -1 ? base : base.substring(0, dot);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final hasGameFolder = provider.gameFolderPath != null;

        return Column(
          children: [
            // ── Top bar ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(
                    bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Text('Scan game folder',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  if (_scannedFiles.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: () => _importAll(provider),
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: Text('Import all (${_scannedFiles.length})',
                          style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        side: BorderSide(
                            color: AppTheme.accent.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: !hasGameFolder || _scanning
                        ? null
                        : () => _scan(provider),
                    icon: _scanning
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.bgDark))
                        : const Icon(Icons.radar_rounded, size: 15),
                    label: Text(_scanning ? 'Scanning…' : 'Scan now',
                        style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────
            Expanded(
              child: !hasGameFolder
                  ? _buildNoFolder()
                  : _scanning
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text('Scanning game folder…',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14)),
                            ],
                          ),
                        )
                      : !_hasScanned
                          ? _buildPrompt()
                          : _scannedFiles.isEmpty
                              ? _buildAllClear()
                              : _buildResults(context, provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoFolder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off_outlined,
              size: 56, color: AppTheme.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Game folder not set',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
          Text('Set your PSO2 game folder in Settings first.',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar_rounded,
              size: 56, color: AppTheme.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Ready to scan',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
          Text(
              'Click "Scan now" to find character files not yet in your library.',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAllClear() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 56, color: Colors.green.withOpacity(0.6)),
          const SizedBox(height: 16),
          Text('All clear!',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
          const SizedBox(height: 8),
          Text('No unregistered character files found.',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, CharacterProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _scannedFiles.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Found ${_scannedFiles.length} unregistered file${_scannedFiles.length == 1 ? '' : 's'}',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          );
        }
        final path = _scannedFiles[i - 1];
        return _ScanResultRow(
          filePath: path,
          onImport: () => _showImportDialog(context, provider, path),
          onDismiss: () => setState(() => _scannedFiles.remove(path)),
        );
      },
    );
  }
}

// ── Scan result row ────────────────────────────────────────────────

class _ScanResultRow extends StatelessWidget {
  final String filePath;
  final VoidCallback onImport;
  final VoidCallback onDismiss;

  const _ScanResultRow({
    required this.filePath,
    required this.onImport,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = filePath.split(r'\').last.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final raceGender = CharacterData.detectRaceGender(filePath);
    final raceColor = AppTheme.raceColor(raceGender['race'] ?? 'Unknown');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: raceColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: raceColor.withOpacity(0.4)),
            ),
            child: Text(ext.toUpperCase(),
                style: TextStyle(
                    color: raceColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName,
                    style: TextStyle(
                        color: AppTheme.textPrimary, fontSize: 12)),
                Text(
                    '${raceGender['race']} · ${raceGender['gender']}',
                    style: TextStyle(color: raceColor, fontSize: 10)),
              ],
            ),
          ),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Skip', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: onImport,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}

// ── Scan import dialog ─────────────────────────────────────────────

enum _ScanImportMode { newCharacter, asVariant }

class _ScanImportDialog extends StatefulWidget {
  final String filePath;
  final CharacterProvider provider;

  const _ScanImportDialog({
    required this.filePath,
    required this.provider,
  });

  @override
  State<_ScanImportDialog> createState() => _ScanImportDialogState();
}

class _ScanImportDialogState extends State<_ScanImportDialog> {
  _ScanImportMode _mode = _ScanImportMode.newCharacter;
  late TextEditingController _nameCtrl;
  late TextEditingController _variantNameCtrl;
  CharacterData? _targetCharacter;
  String? _thumbnailPath;
  bool _importing = false;

  late final String _fileName;
  late final Map<String, String?> _raceGender;

  @override
  void initState() {
    super.initState();
    _fileName = widget.filePath.split(r'\').last.split('/').last;
    final base = _fileName.lastIndexOf('.') == -1
        ? _fileName
        : _fileName.substring(0, _fileName.lastIndexOf('.'));
    _raceGender = CharacterData.detectRaceGender(widget.filePath);
    _nameCtrl = TextEditingController(text: base);
    _variantNameCtrl = TextEditingController(text: base);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _variantNameCtrl.dispose();
    super.dispose();
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
    if (_mode == _ScanImportMode.asVariant && _targetCharacter == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a character to add the variant to'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _importing = true);
    try {
      if (_mode == _ScanImportMode.newCharacter) {
        final name = _nameCtrl.text.trim().isEmpty ? _fileName : _nameCtrl.text.trim();
        await widget.provider.importLocalFile(
          name: name,
          localFilePath: widget.filePath,
          sourceThumbnailPath: _thumbnailPath,
        );
      } else {
        final variantName = _variantNameCtrl.text.trim().isEmpty
            ? _fileName
            : _variantNameCtrl.text.trim();
        await widget.provider.addVariant(
          character: _targetCharacter!,
          displayName: variantName,
          sourceFilePath: widget.filePath,
          sourceThumbnailPath: _thumbnailPath,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final raceColor = AppTheme.raceColor(_raceGender['race'] ?? 'Unknown');
    final characters = widget.provider.allCharacters;
    final canImport = _mode == _ScanImportMode.newCharacter ||
        (_mode == _ScanImportMode.asVariant && _targetCharacter != null);

    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: Row(
        children: [
          Icon(Icons.upload_file_outlined, color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          const Text('Import character file'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── File info card ────────────────────────────────
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
                        border: Border.all(
                            color: raceColor.withOpacity(0.4)),
                      ),
                      child: Icon(Icons.person_outline,
                          size: 26, color: raceColor.withOpacity(0.5)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fileName,
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 3),
                          Text(
                              '${_raceGender['race']} · ${_raceGender['gender']}',
                              style:
                                  TextStyle(color: raceColor, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text('From game folder',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11)),
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
                      selected: _mode == _ScanImportMode.newCharacter,
                      onTap: () => setState(
                          () => _mode = _ScanImportMode.newCharacter),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModeCard(
                      icon: Icons.call_split_rounded,
                      title: 'Add as variant',
                      subtitle: 'Add to an existing character',
                      selected: _mode == _ScanImportMode.asVariant,
                      onTap: () =>
                          setState(() => _mode = _ScanImportMode.asVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Mode-specific fields ──────────────────────────
              if (_mode == _ScanImportMode.newCharacter) ...[
                _label('Character name'),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(hintText: _fileName),
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                ),
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
                  decoration: InputDecoration(hintText: _fileName),
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                ),
              ],
              const SizedBox(height: 14),
              _label('Thumbnail (optional)'),
              const SizedBox(height: 6),
              _ThumbnailPicker(
                imagePath: _thumbnailPath,
                onPick: _pickImage,
                onClear: () => setState(() => _thumbnailPath = null),
                onDrop: (p) => setState(() => _thumbnailPath = p),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: (_importing || !canImport) ? null : _import,
          icon: _importing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.upload_rounded, size: 15),
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

// ── Shared mode card ──────────────────────────────────────────────

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

// ── Shared character picker tile ──────────────────────────────────

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
            border: Border.all(color: AppTheme.borderColor),
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
