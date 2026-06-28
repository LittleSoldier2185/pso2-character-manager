import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character_data.dart';
import '../models/tag_data.dart';
import '../providers/character_provider.dart';
import '../services/card_service.dart';
import '../theme/app_theme.dart';

enum _ImportMode { newCharacter, asVariant }

/// Pick a card PNG and show the import dialog.
Future<void> showImportCardPicker(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: 'Import character card',
    type: FileType.image,
    allowedExtensions: ['png'],
  );
  final path = result?.files.single.path;
  if (path == null) return;

  final payload = await CardService.readPayload(path);
  if (payload == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This PNG does not contain character card data'),
        backgroundColor: Colors.red,
      ));
    }
    return;
  }

  if (context.mounted) {
    await showDialog(
      context: context,
      builder: (_) => _ImportCardDialog(payload: payload),
    );
  }
}

class _ImportCardDialog extends StatefulWidget {
  final CardPayload payload;
  const _ImportCardDialog({required this.payload});

  @override
  State<_ImportCardDialog> createState() => _ImportCardDialogState();
}

class _ImportCardDialogState extends State<_ImportCardDialog> {
  _ImportMode _mode = _ImportMode.newCharacter;
  late TextEditingController _nameCtrl;
  late TextEditingController _variantNameCtrl;
  CharacterData? _targetCharacter;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.payload.name);
    _variantNameCtrl = TextEditingController(text: widget.payload.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _variantNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final provider = context.read<CharacterProvider>();

    if (_mode == _ImportMode.asVariant && _targetCharacter == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Select a character to add the variant to'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _importing = true);

    final String? error;
    if (_mode == _ImportMode.asVariant) {
      final variantName = _variantNameCtrl.text.trim().isEmpty
          ? widget.payload.name
          : _variantNameCtrl.text.trim();
      error = await provider.importCardAsVariant(
        payload: widget.payload,
        character: _targetCharacter!,
        variantName: variantName,
      );
    } else {
      final name = _nameCtrl.text.trim().isEmpty
          ? widget.payload.name
          : _nameCtrl.text.trim();
      error = await provider.importCard(
        payload: widget.payload,
        characterName: name,
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
            : 'Character imported from card'),
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;
    final raceColor = _raceColor(payload.race);
    final characters = context.read<CharacterProvider>().allCharacters;
    final canImport = _mode == _ImportMode.newCharacter ||
        (_mode == _ImportMode.asVariant && _targetCharacter != null);

    final tags = List.generate(
      payload.tagNames.length,
      (i) => TagData(
        id: '',
        name: payload.tagNames[i],
        colorValue: i < payload.tagColors.length
            ? payload.tagColors[i]
            : AppTheme.accent.toARGB32(),
      ),
    );

    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          Icon(Icons.image_search_outlined, color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          const Text('Import character card'),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left: card image ────────────────────────────────
              _InlineCardPreview(payload: payload, tags: tags),

              const SizedBox(width: 20),

              // ── Right: info + fields ────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Character name headline
                    Text(
                      payload.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Race · gender · tier · size row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                  color: raceColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text('${payload.race} · ${payload.gender}',
                                style: TextStyle(
                                    color: raceColor, fontSize: 12)),
                          ],
                        ),
                        if (payload.tier != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(payload.tier!.colorValue),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(payload.tier!.label,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        Text(
                          '${(payload.fhpBytes.length / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),

                    // Tags preview
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: tags.take(8).map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.color.withOpacity(0.45)),
                          ),
                          child: Text(t.name,
                              style: TextStyle(
                                  color: t.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        )).toList(),
                      ),
                    ],

                    const Spacer(),

                    // Mode selector
                    Row(
                      children: [
                        Expanded(
                          child: _ModeCard(
                            icon: Icons.person_add_outlined,
                            title: 'New character',
                            selected: _mode == _ImportMode.newCharacter,
                            onTap: () => setState(
                                () => _mode = _ImportMode.newCharacter),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ModeCard(
                            icon: Icons.call_split_rounded,
                            title: 'Add as variant',
                            selected: _mode == _ImportMode.asVariant,
                            onTap: () => setState(
                                () => _mode = _ImportMode.asVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Mode-specific fields
                    if (_mode == _ImportMode.newCharacter) ...[
                      _label('Character name'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(hintText: payload.name),
                        style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13),
                      ),
                    ] else ...[
                      _label('Add as variant of'),
                      const SizedBox(height: 6),
                      _CharacterPickerTile(
                        selected: _targetCharacter,
                        characters: characters,
                        onPick: (c) =>
                            setState(() => _targetCharacter = c),
                        onClear: () =>
                            setState(() => _targetCharacter = null),
                      ),
                      const SizedBox(height: 10),
                      _label('Variant name'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _variantNameCtrl,
                        decoration: InputDecoration(hintText: payload.name),
                        style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
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
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_outlined, size: 15),
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
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withOpacity(0.08) : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected
                  ? AppTheme.accent.withOpacity(0.5)
                  : AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

// ── Character picker ──────────────────────────────────────────────

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
                  .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
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
                          style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final rc = AppTheme.raceColor(c.race);
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(color: rc, shape: BoxShape.circle),
                          ),
                          title: Text(c.name,
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                          subtitle: Text(
                              '${c.race} · ${c.gender} · ${c.variants.length} variant${c.variants.length == 1 ? '' : 's'}',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(selected!.name,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 14),
            color: AppTheme.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Inline card preview ───────────────────────────────────────────

class _InlineCardPreview extends StatelessWidget {
  final CardPayload payload;
  final List<TagData> tags;

  const _InlineCardPreview({required this.payload, required this.tags});

  @override
  Widget build(BuildContext context) {
    final raceColor = _raceColor(payload.race);
    final tier = payload.tier;

    return SizedBox(
      width: 220,
      height: 293,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (payload.thumbnailBytes != null)
              Image.memory(payload.thumbnailBytes!,
                  fit: BoxFit.cover, alignment: Alignment.topCenter)
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      raceColor.withOpacity(0.18),
                      const Color(0xFF0D1117),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.person_outline,
                      size: 80, color: raceColor.withOpacity(0.12)),
                ),
              ),

            Positioned(
              left: 0, right: 0, bottom: 0,
              height: tags.isNotEmpty ? 175 : 135,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0D1117).withOpacity(0.7),
                      const Color(0xFF0D1117).withOpacity(0.95),
                      const Color(0xFF0D1117),
                    ],
                    stops: const [0.0, 0.35, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: tags.take(6).map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.color.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.color.withOpacity(0.5)),
                          ),
                          child: Text(t.name,
                              style: TextStyle(
                                  color: t.color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  shadows: const [Shadow(blurRadius: 4, color: Colors.black54)])),
                        )).toList(),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            payload.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(blurRadius: 12, color: Colors.black87),
                                Shadow(blurRadius: 4, color: Colors.black54),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tier != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(tier.colorValue),
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black45)],
                            ),
                            child: Text(tier.label,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(color: raceColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text('${payload.race} · ${payload.gender}',
                            style: TextStyle(
                                color: raceColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                shadows: const [Shadow(blurRadius: 6, color: Colors.black87)])),
                      ],
                    ),
                  ),

                  Container(
                    color: const Color(0xFF0D1117),
                    padding: const EdgeInsets.fromLTRB(14, 7, 14, 10),
                    child: const Text('PSO2 Character Manager',
                        style: TextStyle(color: Color(0xFF3D444D), fontSize: 9)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _raceColor(String race) {
  switch (race.toLowerCase()) {
    case 'human':  return const Color(0xFF58A6FF);
    case 'newman': return const Color(0xFFBC8CFF);
    case 'deuman': return const Color(0xFFFF7B72);
    case 'cast':   return const Color(0xFF3FB950);
    default:       return const Color(0xFF8B949E);
  }
}
