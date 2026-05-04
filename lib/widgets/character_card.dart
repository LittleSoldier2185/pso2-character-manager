import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';
import 'tag_chip.dart';

class CharacterCard extends StatelessWidget {
  final Character character;
  final VoidCallback onTap;

  const CharacterCard({super.key, required this.character, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: character.isApplied ? AppTheme.accent : AppTheme.borderColor,
            width: character.isApplied ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumbnail(),
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
                    if (character.isApplied && character.slotNumber != null)
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
                          child: Text(
                            'Slot ${character.slotNumber}',
                            style: const TextStyle(
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
                            const SizedBox(height: 2),
                            Text(
                              '${character.race} · ${character.gender[0]}',
                              style: TextStyle(
                                  color: AppTheme.raceColor(character.race),
                                  fontSize: 10),
                            ),
                            if (character.description.isNotEmpty) ...[
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
                  if (character.tags.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 3,
                      runSpacing: 3,
                      children: character.tags
                          .take(2)
                          .map((tag) => TagChip(label: tag))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (character.thumbnailPath != null) {
      final file = File(character.thumbnailPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Container(
      color: AppTheme.bgSurface,
      child: Center(
        child: Icon(Icons.person_outline,
            size: 36,
            color: AppTheme.raceColor(character.race).withOpacity(0.35)),
      ),
    );
  }
}

class _ApplyToggleButton extends StatefulWidget {
  final Character character;
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
        // No const here — accent is dynamic
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
