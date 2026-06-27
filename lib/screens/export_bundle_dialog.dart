import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character_data.dart';
import '../providers/character_provider.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';

class ExportBundleDialog extends StatefulWidget {
  final CharacterData character;
  const ExportBundleDialog({super.key, required this.character});

  @override
  State<ExportBundleDialog> createState() => _ExportBundleDialogState();
}

class _ExportBundleDialogState extends State<ExportBundleDialog> {
  bool _includeGallery = true;
  bool _includeTags = true;
  bool _includeDescription = true;
  int? _estimatedSize;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _updateEstimate();
  }

  Future<void> _updateEstimate() async {
    final provider = context.read<CharacterProvider>();
    final size = await provider.estimateBundleSize(
      character: widget.character,
      options: ExportOptions(
        includeGallery: _includeGallery,
        includeTags: _includeTags,
        includeDescription: _includeDescription,
      ),
    );
    if (mounted) setState(() => _estimatedSize = size);
  }

  Future<void> _export() async {
    final provider = context.read<CharacterProvider>();
    final safeName =
        widget.character.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export character bundle',
      fileName: '$safeName.pso2char',
      type: FileType.custom,
      allowedExtensions: ['pso2char'],
    );
    if (result == null || !mounted) return;

    setState(() => _exporting = true);
    final error = await provider.exportBundle(
      character: widget.character,
      destPath: result,
      options: ExportOptions(
        includeGallery: _includeGallery,
        includeTags: _includeTags,
        includeDescription: _includeDescription,
      ),
    );
    if (!mounted) return;
    setState(() => _exporting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error), backgroundColor: Colors.red));
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bundle exported successfully'),
          backgroundColor: Colors.green));
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: Row(
        children: [
          Icon(Icons.file_upload_outlined,
              color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          const Text('Export character bundle'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Character preview
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  // Thumbnail
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: widget.character.thumbnailPath != null &&
                            File(widget.character.thumbnailPath!).existsSync()
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.file(
                                File(widget.character.thumbnailPath!),
                                fit: BoxFit.cover))
                        : Icon(Icons.person_outline,
                            size: 22,
                            color: AppTheme.raceColor(widget.character.race)
                                .withOpacity(0.4)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.character.name,
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        Text(
                            '${widget.character.race} · ${widget.character.gender}',
                            style: TextStyle(
                                color:
                                    AppTheme.raceColor(widget.character.race),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Options
            _ToggleRow(
              label: 'Include gallery images',
              subtitle: 'Adds all photos to the bundle',
              value: _includeGallery,
              onChanged: (v) {
                setState(() => _includeGallery = v);
                _updateEstimate();
              },
            ),
            _ToggleRow(
              label: 'Include tags',
              subtitle: 'Receiver can see tag info',
              value: _includeTags,
              onChanged: (v) {
                setState(() => _includeTags = v);
                _updateEstimate();
              },
            ),
            _ToggleRow(
              label: 'Include description',
              subtitle: 'Name, notes and description',
              value: _includeDescription,
              onChanged: (v) {
                setState(() => _includeDescription = v);
                _updateEstimate();
              },
            ),

            const SizedBox(height: 12),
            // Size estimate
            Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 5),
                Text(
                  _estimatedSize != null
                      ? 'Estimated size: ${_formatSize(_estimatedSize!)}'
                      : 'Calculating size…',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _exporting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _exporting ? null : _export,
          icon: _exporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.file_upload_outlined, size: 15),
          label: Text(_exporting ? 'Exporting…' : 'Export'),
        ),
      ],
    );
  }
}

// ── Toggle row ─────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13)),
                Text(subtitle,
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }
}

/// Show the export bundle dialog.
Future<void> showExportBundleDialog(
    BuildContext context, CharacterData character) {
  return showDialog(
    context: context,
    builder: (_) => ExportBundleDialog(character: character),
  );
}
