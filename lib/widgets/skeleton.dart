import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Shimmer scope ──────────────────────────────────────────────────
// A single AnimationController drives all SkeletonBox children so
// the shimmer sweeps in sync across every placeholder in the grid.

class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => _ShimmerScope(
        progress: _ctrl.value,
        child: child!,
      ),
      child: widget.child,
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  final double progress;
  const _ShimmerScope({required this.progress, required super.child});

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.progress ?? 0;

  @override
  bool updateShouldNotify(_ShimmerScope old) => progress != old.progress;
}

// ── SkeletonBox ────────────────────────────────────────────────────
// Primitive shimmer rectangle. Must be a descendant of SkeletonShimmer.

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  @override
  Widget build(BuildContext context) {
    final t = _ShimmerScope.of(context);
    // Highlight sweeps left to right: t=0 → off left, t=1 → off right
    final pos = t * 1.8 - 0.4;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0xFF1C2128),
            Color(0xFF2C3540),
            Color(0xFF1C2128),
          ],
          stops: [
            (pos - 0.35).clamp(0.0, 1.0),
            pos.clamp(0.0, 1.0),
            (pos + 0.35).clamp(0.0, 1.0),
          ],
        ),
      ),
    );
  }
}

// ── SkeletonCharacterCard ──────────────────────────────────────────
// Mirrors the CharacterCard layout so it doesn't cause layout shift
// when real cards replace it.

class SkeletonCharacterCard extends StatelessWidget {
  const SkeletonCharacterCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail placeholder — fills the Expanded area
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
              child: SkeletonBox(borderRadius: BorderRadius.zero),
            ),
          ),
          // Info row
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 6, 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(
                          height: 11,
                          borderRadius: BorderRadius.circular(3)),
                      const SizedBox(height: 5),
                      SkeletonBox(
                          width: 54,
                          height: 8,
                          borderRadius: BorderRadius.circular(3)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SkeletonBox(
                    width: 28,
                    height: 28,
                    borderRadius: BorderRadius.circular(7)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── SkeletonCardGrid ───────────────────────────────────────────────
// Drop-in replacement for the real character grid while isLoading.

class SkeletonCardGrid extends StatelessWidget {
  final int cardSize;

  static const List<double> _sizeExtents  = [120, 160, 200, 260];
  static const List<double> _aspectRatios = [0.58, 0.62, 0.68, 0.72];

  const SkeletonCardGrid({super.key, this.cardSize = 2});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _sizeExtents[cardSize],
          childAspectRatio: _aspectRatios[cardSize],
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 12,
        itemBuilder: (context, i) => const SkeletonCharacterCard(),
      ),
    );
  }
}

// ── SkeletonListTile ───────────────────────────────────────────────
// Generic skeleton for list-style screens (collections, tags, etc.)

class SkeletonListTile extends StatelessWidget {
  final double titleWidth;
  final double subtitleWidth;

  const SkeletonListTile({
    super.key,
    this.titleWidth = 140,
    this.subtitleWidth = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SkeletonBox(
              width: 40,
              height: 40,
              borderRadius: BorderRadius.circular(8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                    width: titleWidth,
                    height: 12,
                    borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 6),
                SkeletonBox(
                    width: subtitleWidth,
                    height: 9,
                    borderRadius: BorderRadius.circular(3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── SkeletonCollectionList ─────────────────────────────────────────

class SkeletonCollectionList extends StatelessWidget {
  const SkeletonCollectionList({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 6,
        itemBuilder: (context, i) => const SkeletonListTile(),
      ),
    );
  }
}

// ── SkeletonGalleryGrid ────────────────────────────────────────────

class SkeletonGalleryGrid extends StatelessWidget {
  const SkeletonGalleryGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 12,
        itemBuilder: (context, i) => SkeletonBox(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
