import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../models/character_data.dart';
import '../providers/character_provider.dart';
import '../services/card_service.dart';
import '../theme/app_theme.dart';
import '../widgets/character_card_preview.dart';

class ExportCardDialog extends StatefulWidget {
  final CharacterData character;
  /// When set, exports this specific variant's .fhp + thumbnail instead of main.
  final VariantData? variant;
  const ExportCardDialog({super.key, required this.character, this.variant});

  @override
  State<ExportCardDialog> createState() => _ExportCardDialogState();
}

class _ExportCardDialogState extends State<ExportCardDialog> {
  final _cardKey = GlobalKey();
  bool _exporting = false;

  Future<Uint8List> _capturePng() async {
    final boundary =
        _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _share() async {
    final exportName = widget.variant?.displayName ?? widget.character.name;
    final safeName = exportName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save character image',
      fileName: '$safeName.png',
      type: FileType.image,
      allowedExtensions: ['png'],
    );
    if (savePath == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      final pngBytes = await _capturePng();
      await File(savePath).writeAsBytes(pngBytes);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Image saved — plain PNG, no character data included'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Export failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _export() async {
    final provider = context.read<CharacterProvider>();
    final exportName = widget.variant?.displayName ?? widget.character.name;
    final safeName = exportName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save character card',
      fileName: '$safeName.png',
      type: FileType.image,
      allowedExtensions: ['png'],
    );
    if (savePath == null || !mounted) return;

    setState(() => _exporting = true);

    try {
      final pngBytes = await _capturePng();

      final resolvedTags = widget.character.tags
          .map((id) => provider.tagById(id))
          .where((t) => t != null)
          .map((t) => t!)
          .toList();

      // Variant-specific overrides (null = use character's main files)
      final v = widget.variant;
      final fhpOverride = v != null
          ? widget.character.charFileForVariant(v.folderName)
          : null;
      final thumbOverride = v != null
          ? widget.character.thumbnailForVariant(v.folderName)
          : null;
      final fileNameOverride = v != null
          ? (v.originalFileName ?? p.basename(fhpOverride ?? ''))
          : null;

      final error = await CardService.saveCard(
        pngBytes: Uint8List.fromList(pngBytes),
        character: widget.character,
        resolvedTags: resolvedTags,
        savePath: savePath,
        fhpPathOverride: fhpOverride,
        thumbPathOverride: thumbOverride,
        gameFileNameOverride: fileNameOverride?.isNotEmpty == true ? fileNameOverride : null,
        nameOverride: widget.variant?.displayName,
      );

      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red));
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Card exported — the PNG contains embedded import data'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Export failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final resolvedTags = widget.character.tags
        .map((id) => provider.tagById(id))
        .where((t) => t != null)
        .map((t) => t!)
        .toList();

    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: Row(
        children: [
          Icon(Icons.image_outlined, color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          const Text('Export character card'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"Save card" embeds character data so it can be imported into PSO2 '
              'Character Manager. "Share image" saves a plain PNG with no hidden '
              'data — for posting anywhere.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Card preview — FittedBox scales 480×640 down to 300×400 for display.
            // RepaintBoundary captures the card at its logical size (480×640),
            // so the FittedBox transform is excluded from the export.
            Center(
              child: SizedBox(
                width: 300,
                height: 400,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: CharacterCardPreview(
                      character: widget.character,
                      tags: resolvedTags,
                      thumbnailOverridePath: widget.variant != null
                          ? widget.character.thumbnailForVariant(
                              widget.variant!.folderName)
                          : null,
                      nameOverride: widget.variant?.displayName,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _exporting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: _exporting ? null : _share,
          icon: const Icon(Icons.share_outlined, size: 15),
          label: const Text('Share image'),
        ),
        ElevatedButton.icon(
          onPressed: _exporting ? null : _export,
          icon: _exporting
              ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_outlined, size: 15),
          label: Text(_exporting ? 'Exporting…' : 'Save card'),
        ),
      ],
    );
  }
}

Future<void> showExportCardDialog(BuildContext context, CharacterData character) {
  return showDialog(
    context: context,
    builder: (_) => ExportCardDialog(character: character),
  );
}

Future<void> showExportVariantCardDialog(
    BuildContext context, CharacterData character, VariantData variant) {
  return showDialog(
    context: context,
    builder: (_) => ExportCardDialog(character: character, variant: variant),
  );
}
