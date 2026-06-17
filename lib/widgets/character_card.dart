import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character_data.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';
import 'tag_chip.dart';

class CharacterCard extends StatelessWidget {
  final CharacterData character;
  final VoidCallback onTap;
  final int cardSize; // 0=S,1=M,2=L,3=XL

  const CharacterCard({
    super.key,
    required this.character,
    required this.onTap,
    this.cardSize = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final tier = character.tier;
        final tierColor = tier != null ? Color(tier.colorValue) : null;

        final borderColor = tierColor ?? (character.isApplied ? AppTheme.accent : AppTheme.borderColor);
        final borderWidth = (character.isApplied || tier != null) ? 1.5 : 1.0;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Thumbnail ────────────────────────────────────
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildThumbnail(),
                        // Race dot
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.raceColor(character.race),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Tier badge — top left below race dot
                        if (tier != null)
                          Positioned(
                            top: 20,
                            left: 5,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Color(tier.bgColorValue),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Center(
                                child: Text(
                                  tier.label,
                                  style: TextStyle(
                                    color: Color(tier.colorValue),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Favourite heart — bottom left
                        Positioned(
                          bottom: 5,
                          left: 5,
                          child: GestureDetector(
                            onTap: () => provider.toggleFavourite(character),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: character.isFavourite
                                    ? Colors.pinkAccent.withOpacity(0.85)
                                    : Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                character.isFavourite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 11,
                                color: character.isFavourite
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),
                        if (character.isApplied)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Applied',
                                style: TextStyle(
                                    color: AppTheme.bgDark,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // ── Info + apply button ───────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 7, 6, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name — always shown
                                Text(
                                  character.name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Race/gender — M, L, XL
                                if (cardSize >= 1) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${character.race} · ${character.gender[0]}',
                                    style: TextStyle(
                                        color: AppTheme.raceColor(
                                            character.race),
                                        fontSize: 10),
                                  ),
                                ],
                                // Description — XL only
                                if (cardSize >= 3 &&
                                    character.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    character.description,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          _ApplyToggleButton(character: character),
                        ],
                      ),
                      // Tags — L and XL only
                      if (cardSize >= 2 &&
                          character.tags.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Material(
                          type: MaterialType.transparency,
                          child: Wrap(
                            spacing: 3,
                            runSpacing: 3,
                            children: character.tags
                                .take(2)
                                .map((id) {
                                  final tag = provider.tagById(id);
                                  return tag != null
                                      ? TagChip(tag: tag)
                                      : const SizedBox.shrink();
                                })
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail() {
    if (character.thumbnailPath != null) {
      final file = File(character.thumbnailPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return const ColoredBox(color: AppTheme.bgSurface);
          },
        );
      }
    }
    return Container(
      color: AppTheme.bgSurface,
      child: Center(
        child: Icon(Icons.person_outline,
            size: 36,
            color:
                AppTheme.raceColor(character.race).withOpacity(0.35)),
      ),
    );
  }
}

// ── Apply toggle button ────────────────────────────────────────────

class _ApplyToggleButton extends StatefulWidget {
  final CharacterData character;
  const _ApplyToggleButton({required this.character});

  @override
  State<_ApplyToggleButton> createState() => _ApplyToggleButtonState();
}

class _ApplyToggleButtonState extends State<_ApplyToggleButton> {
  bool _loading = false;

  Future<void> _toggle() async {
    setState(() => _loading = true);
    final provider = context.read<CharacterProvider>();
    final error = await provider.toggleApply(widget.character);
    if (mounted) {
      setState(() => _loading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApplied = widget.character.isApplied;
    return GestureDetector(
      onTap: _loading ? null : _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isApplied ? AppTheme.accent : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: isApplied ? AppTheme.accent : AppTheme.borderColor),
        ),
        child: _loading
            ? Padding(
                padding: const EdgeInsets.all(5),
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppTheme.accent))
            : Icon(
                isApplied ? Icons.check_rounded : Icons.add_rounded,
                size: 16,
                color: isApplied ? AppTheme.bgDark : AppTheme.textSecondary),
      ),
    );
  }
}
