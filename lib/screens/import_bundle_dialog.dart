import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../providers/character_provider.dart';
import '../services/share_service.dart';
import '../services/file_service.dart';
import '../theme/app_theme.dart';

/// Show the import preview dialog from a file path.
/// Reads the bundle, then shows the preview + conflict dialog.
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

/// Show file picker then import preview dialog.
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

class ImportBundleDialog extends StatefulWidget {
  final BundlePreview preview;
  const ImportBundleDialog({super.key, required this.preview});

  @override
  State<ImportBundleDialog> createState() => _ImportBundleDialogState();
}

class _ImportBundleDialogState extends State<ImportBundleDialog> {
  late TextEditingController _nameCtrl;
  bool _importing = false;
  String? _filenameConflict; // name of the conflicting character if any
  bool _renameFile = false; // true = auto-rename, false = keep original

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.preview.characterName);
    _checkConflict();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkConflict() async {
    final conflict = await FileService.checkFileNameConflict(
        widget.preview.originalFileName);
    if (conflict != null && mounted) {
      // Find owner name
      final provider = context.read<CharacterProvider>();
      final ownerName = provider.allCharacters
          .where((c) =>
              c.gameFileName == widget.preview.originalFileName ||
              c.characterFilePath.endsWith(widget.preview.originalFileName))
          .firstOrNull
          ?.name;
      setState(() {
        _filenameConflict = ownerName ?? 'another character';
        _renameFile = true; // default to rename
      });
    }
  }

  Future<void> _import() async {
    final provider = context.read<CharacterProvider>();
    setState(() => _importing = true);

    final customFileName =
        _renameFile ? _buildRenamedFileName() : null;

    final error = await provider.importBundle(
      preview: widget.preview,
      characterName: _nameCtrl.text.trim().isEmpty
          ? widget.preview.characterName
          : _nameCtrl.text.trim(),
      customFileName: customFileName,
    );

    if (!mounted) return;
    setState(() => _importing = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error), backgroundColor: Colors.red));
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Character imported successfully'),
          backgroundColor: Colors.green));
    }
  }

  /// Builds a renamed filename by appending a timestamp before the extension.
  String _buildRenamedFileName() {
    final original = widget.preview.originalFileName;
    final dot = original.lastIndexOf('.');
    if (dot < 0) return original;
    final base = original.substring(0, dot);
    final ext = original.substring(dot);
    return '${base}_${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  @override
  Widget build(BuildContext context) {
    final raceColor = AppTheme.raceColor(widget.preview.race);

    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: Row(
        children: [
          Icon(Icons.file_download_outlined,
              color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          const Text('Import character bundle'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Character preview
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
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: raceColor.withOpacity(0.4)),
                      ),
                      child: Icon(Icons.person_outline,
                          size: 28, color: raceColor.withOpacity(0.5)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.preview.characterName,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                              '${widget.preview.race} · ${widget.preview.gender}',
                              style: TextStyle(
                                  color: raceColor, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(widget.preview.originalFileName,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11)),
                          if (widget.preview.galleryImageCount > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                                '${widget.preview.galleryImageCount} gallery image${widget.preview.galleryImageCount == 1 ? '' : 's'} included',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Name override
              const Text('Import as name',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: widget.preview.characterName,
                ),
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13),
              ),

              // Conflict section
              if (_filenameConflict != null) ...[
                const SizedBox(height: 14),
                _sectionLabel('Conflict'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.accentGold.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: AppTheme.accentGold),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '"${widget.preview.originalFileName}" already exists in your library (owned by "$_filenameConflict").',
                              style: TextStyle(
                                  color: AppTheme.accentGold,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Rename / Replace choice
                      Row(
                        children: [
                          _RadioChoice(
                            label: 'Rename (safe)',
                            selected: _renameFile,
                            onTap: () =>
                                setState(() => _renameFile = true),
                          ),
                          const SizedBox(width: 12),
                          _RadioChoice(
                            label: 'Replace existing',
                            selected: !_renameFile,
                            onTap: () =>
                                setState(() => _renameFile = false),
                            color: Colors.redAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Description preview
              if (widget.preview.description != null &&
                  widget.preview.description!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _sectionLabel('Description'),
                const SizedBox(height: 4),
                Text(widget.preview.description!,
                    style: const TextStyle(
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
          onPressed: _importing ? null : _import,
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

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500));
}

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
