import 'dart:io';
import 'dart:math' show pi;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character_data.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';
import 'tag_chip.dart';
import 'tier_border.dart';

class CharacterCard extends StatelessWidget {
  final CharacterData character;
  final VoidCallback onTap;
  final int cardSize; // 0=S,1=M,2=L,3=XL
  final String? variantFolderName;
  final bool? selected; // null = not in selection mode
  final VoidCallback? onLongPress;

  const CharacterCard({
    super.key,
    required this.character,
    required this.onTap,
    this.cardSize = 2,
    this.variantFolderName,
    this.selected,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppTheme.tierEffectNotifier,
      builder: (context, _, __) => Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final tier = character.tier;
        final isSTier = tier == CharacterTier.s;
        final hasTierBorder = tier != null;
        final tierColor = tier != null ? Color(tier.colorValue) : null;

        final borderColor = tierColor ?? (character.isApplied ? AppTheme.accent : AppTheme.borderColor);
        final borderWidth = (character.isApplied || tier != null) ? 1.5 : 1.0;

        final card = InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: hasTierBorder ? null : Border.all(
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
                            child: isSTier
                                ? const _RainbowBadge()
                                : Container(
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
                              child: Text(
                                'Applied',
                                style: TextStyle(
                                    color: AppTheme.bgDark,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        // Selection overlay
                        if (selected != null)
                          Positioned.fill(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: selected!
                                    ? AppTheme.accent.withOpacity(0.35)
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        if (selected != null)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: selected!
                                    ? AppTheme.accent
                                    : Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected!
                                      ? AppTheme.accent
                                      : Colors.white.withOpacity(0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: selected!
                                  ? const Icon(Icons.check_rounded,
                                      size: 13, color: Colors.white)
                                  : null,
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
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Variant label
                                if (variantFolderName != null) Builder(builder: (context) {
                                  final v = character.variants.where((v) => v.folderName == variantFolderName).firstOrNull;
                                  if (v == null) return const SizedBox.shrink();
                                  return Text(
                                    v.displayName,
                                    style: TextStyle(color: AppTheme.accent, fontSize: 9),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }),
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
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          ApplyToggleButton(character: character),
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

        final hasCustom = character.customBorderEffect != null ||
            character.customBorderColor != null;
        if (tier == null && !hasCustom) return card;

        final TierBorderEffect effect;
        if (character.customBorderEffect != null) {
          effect = TierBorderEffect.values.firstWhere(
            (e) => e.name == character.customBorderEffect,
            orElse: () => tier != null
                ? AppTheme.effectForTier(tier)
                : TierBorderEffect.shimmer,
          );
        } else {
          effect = tier != null
              ? AppTheme.effectForTier(tier)
              : TierBorderEffect.shimmer;
        }

        final Color effectColor = character.customBorderColor != null
            ? Color(character.customBorderColor!)
            : tier != null
                ? Color(tier.colorValue)
                : AppTheme.accent;

        return buildTierBorder(
          effect: effect,
          color: effectColor,
          child: card,
        );
      },
      ),
    );
  }

  Widget _buildThumbnail() {
    final isVariant = variantFolderName != null;
    final thumbPath = isVariant
        ? character.thumbnailForVariant(variantFolderName!)
        : character.thumbnailPath;
    final isBlurred = isVariant
        ? (character.variants
                .where((v) => v.folderName == variantFolderName)
                .firstOrNull
                ?.thumbnailBlurred ??
            false)
        : character.thumbnailBlurred ||
            (character.mainVariantData?.thumbnailBlurred ?? false);

    if (thumbPath != null) {
      final file = File(thumbPath);
      if (file.existsSync()) {
        Widget img = Image.file(
          file,
          key: ValueKey(file.lastModifiedSync()),
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return ColoredBox(color: AppTheme.bgSurface);
          },
        );
        if (isBlurred) {
          img = ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: img,
          );
        }
        return img;
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

// ── S tier badge ──────────────────────────────────────────────────

class _RainbowBadge extends StatefulWidget {
  const _RainbowBadge();

  @override
  State<_RainbowBadge> createState() => _RainbowBadgeState();
}

class _RainbowBadgeState extends State<_RainbowBadge>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _ctrl;

  static const _colors = [
    Color(0xFFFF0000),
    Color(0xFFFF7700),
    Color(0xFFFFFF00),
    Color(0xFF00CC00),
    Color(0xFF0077FF),
    Color(0xFF8B00FF),
    Color(0xFFFF0000),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    state == AppLifecycleState.resumed ? _ctrl.repeat() : _ctrl.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          gradient: SweepGradient(
            colors: _colors,
            transform: GradientRotation(_ctrl.value * 2 * pi),
          ),
        ),
        child: const Center(
          child: Text(
            'S',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 2, offset: Offset( 1,  1)),
                Shadow(color: Colors.black, blurRadius: 2, offset: Offset(-1, -1)),
                Shadow(color: Colors.black, blurRadius: 2, offset: Offset( 1, -1)),
                Shadow(color: Colors.black, blurRadius: 2, offset: Offset(-1,  1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Apply toggle button ────────────────────────────────────────────

class ApplyToggleButton extends StatefulWidget {
  final CharacterData character;
  const ApplyToggleButton({required this.character});

  @override
  State<ApplyToggleButton> createState() => ApplyToggleButtonState();
}

class ApplyToggleButtonState extends State<ApplyToggleButton> {
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
