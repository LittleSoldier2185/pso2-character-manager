import 'dart:io';
import 'package:flutter/material.dart';
import '../models/character_data.dart';
import '../models/tag_data.dart';

/// Visual card widget — used both as export preview and for RepaintBoundary capture.
/// Fixed size 480×640. Full-bleed thumbnail with gradient overlay and content at bottom.
class CharacterCardPreview extends StatelessWidget {
  final CharacterData character;
  final List<TagData> tags;
  final String? thumbnailOverridePath;
  final String? nameOverride;

  const CharacterCardPreview({
    super.key,
    required this.character,
    required this.tags,
    this.thumbnailOverridePath,
    this.nameOverride,
  });

  @override
  Widget build(BuildContext context) {
    final raceColor = _raceColor(character.race);
    final tier = character.tier;
    final displayName = nameOverride ?? character.name;
    final thumbPath = thumbnailOverridePath ?? character.thumbnailPath;
    final hasThumb = thumbPath != null && File(thumbPath).existsSync();

    return SizedBox(
      width: 480,
      height: 640,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background / thumbnail (full bleed) ───────────────
            if (hasThumb)
              Image.file(
                File(thumbPath!),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              )
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
                      size: 120, color: raceColor.withOpacity(0.12)),
                ),
              ),

            // ── Bottom gradient scrim ──────────────────────────────
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: tags.isNotEmpty ? 260 : 200,
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

            // ── Content anchored to bottom ─────────────────────────
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tags
                  if (tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.take(8).map((t) => _TagChip(tag: t)).toList(),
                      ),
                    ),

                  // Name + tier
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
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
                          const SizedBox(width: 10),
                          _TierBadge(tier: tier),
                        ],
                      ],
                    ),
                  ),

                  // Race · Gender
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                              color: raceColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${character.race} · ${character.gender}',
                          style: TextStyle(
                            color: raceColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(blurRadius: 6, color: Colors.black87),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer strip
                  Container(
                    color: const Color(0xFF0D1117),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                    child: Row(
                      children: [
                        const Icon(Icons.person_pin_rounded,
                            size: 13, color: Color(0xFF3D444D)),
                        const SizedBox(width: 6),
                        const Text(
                          'PSO2 Character Manager',
                          style: TextStyle(
                            color: Color(0xFF3D444D),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          character.race[0].toUpperCase() +
                              character.gender[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF3D444D),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
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

// ── Tier badge ─────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  final CharacterTier tier;
  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color(tier.colorValue),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black45)],
      ),
      child: Text(
        tier.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Tag chip ───────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final TagData tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tag.color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tag.color.withOpacity(0.5)),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          color: tag.color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
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
