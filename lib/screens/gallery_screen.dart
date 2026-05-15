import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gallery_item.dart';
import '../models/character.dart';
import '../providers/character_provider.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import 'character_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String? _filterCharacterId;
  String _search = '';
  Set<String> _blurredItems = {};

  @override
  void initState() {
    super.initState();
    _blurredItems = HiveService().getBlurredItems();
  }

  Future<void> _toggleBlur(String itemId) async {
    await HiveService().toggleBlurredItem(itemId);
    setState(() {
      if (_blurredItems.contains(itemId)) {
        _blurredItems.remove(itemId);
      } else {
        _blurredItems.add(itemId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final allItems = provider.getAllGalleryItems();
        final characters = provider.allCharacters;

        // Filter by character
        var items = _filterCharacterId != null
            ? allItems
                .where((i) => i.characterId == _filterCharacterId)
                .toList()
            : allItems;

        // Filter by search (character name)
        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          items = items.where((i) {
            final char = _charForItem(i, characters);
            return char?.name.toLowerCase().contains(q) ?? false;
          }).toList();
        }

        // Build the unique character list for the filter bar
        final characterIdsWithImages = allItems
            .map((i) => i.characterId)
            .toSet()
            .toList();
        final charsWithImages = characters
            .where((c) => characterIdsWithImages.contains(c.id))
            .toList();

        return Column(
          children: [
            // ── Top bar ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(
                    bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Text(
                    items.isEmpty
                        ? 'Gallery'
                        : '${items.length} image${items.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  // Search bar
                  SizedBox(
                    width: 200,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search by character…',
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 15, color: AppTheme.textSecondary),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () =>
                                    setState(() => _search = ''),
                              )
                            : null,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                      ),
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // ── Character filter chips ────────────────────────
            if (charsWithImages.isNotEmpty)
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  color: AppTheme.bgCard,
                  border: Border(
                      bottom: BorderSide(color: AppTheme.borderColor)),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: charsWithImages.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      // "All" chip
                      final selected = _filterCharacterId == null;
                      return _FilterChip(
                        label: 'All',
                        count: allItems.length,
                        selected: selected,
                        color: AppTheme.accent,
                        onTap: () =>
                            setState(() => _filterCharacterId = null),
                      );
                    }
                    final char = charsWithImages[i - 1];
                    final count = allItems
                        .where((it) => it.characterId == char.id)
                        .length;
                    final selected = _filterCharacterId == char.id;
                    return _FilterChip(
                      label: char.name,
                      count: count,
                      selected: selected,
                      color: AppTheme.raceColor(char.race),
                      onTap: () => setState(
                          () => _filterCharacterId = char.id),
                    );
                  },
                ),
              ),

            // ── Grid ─────────────────────────────────────────
            Expanded(
              child: items.isEmpty
                  ? _buildEmpty(charsWithImages.isEmpty)
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final char =
                            _charForItem(item, characters);
                        return _GalleryGridCell(
                          item: item,
                          character: char,
                          allItems: items,
                          index: index,
                          isBlurred: _blurredItems.contains(item.id),
                          onToggleBlur: () => _toggleBlur(item.id),
                          onCharacterTap: char != null
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            CharacterDetailScreen(
                                                character: char)),
                                  )
                              : null,
                          onDelete: () => _confirmDelete(context, item),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Character? _charForItem(
      GalleryItem item, List<Character> characters) {
    return characters
        .where((c) => c.id == item.characterId)
        .firstOrNull;
  }

  Widget _buildEmpty(bool noImagesAtAll) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noImagesAtAll
                ? Icons.photo_library_outlined
                : Icons.search_off_rounded,
            size: 56,
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            noImagesAtAll
                ? 'No gallery images yet'
                : 'No images match your filter',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 15),
          ),
          if (noImagesAtAll) ...[
            const SizedBox(height: 8),
            const Text(
              'Open a character and add images to its gallery',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, GalleryItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Remove image?'),
        content: const Text(
            'This will permanently delete the image file from storage.',
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context
                  .read<CharacterProvider>()
                  .deleteGalleryItem(item);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? color : AppTheme.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: selected ? color : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w500 : FontWeight.normal),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(0.2)
                    : AppTheme.bgCard,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                    color: selected ? color : AppTheme.textSecondary,
                    fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gallery grid cell ──────────────────────────────────────────────

class _GalleryGridCell extends StatefulWidget {
  final GalleryItem item;
  final Character? character;
  final List<GalleryItem> allItems;
  final int index;
  final bool isBlurred;
  final VoidCallback onToggleBlur;
  final VoidCallback? onCharacterTap;
  final VoidCallback onDelete;

  const _GalleryGridCell({
    required this.item,
    required this.character,
    required this.allItems,
    required this.index,
    required this.isBlurred,
    required this.onToggleBlur,
    required this.onCharacterTap,
    required this.onDelete,
  });

  @override
  State<_GalleryGridCell> createState() => _GalleryGridCellState();
}

class _GalleryGridCellState extends State<_GalleryGridCell> {
  bool _hovered = false;

  void _viewFullscreen() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => _FullscreenViewer(
        items: widget.allItems,
        initialIndex: widget.index,
        characters: context.read<CharacterProvider>().allCharacters,
        onCharacterTap: (char) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CharacterDetailScreen(character: char)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileExists = File(widget.item.filePath).existsSync();
    final raceColor = widget.character != null
        ? AppTheme.raceColor(widget.character!.race)
        : AppTheme.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: fileExists ? _viewFullscreen : null,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _hovered
                    ? AppTheme.accent.withOpacity(0.5)
                    : AppTheme.borderColor),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image (with optional blur)
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: fileExists
                    ? widget.isBlurred
                        ? ImageFiltered(
                            imageFilter:
                                ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Image.file(
                              File(widget.item.filePath),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          )
                        : Image.file(
                            File(widget.item.filePath),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                    : Center(
                        child: Icon(Icons.broken_image_outlined,
                            size: 28,
                            color: AppTheme.textSecondary
                                .withOpacity(0.4)),
                      ),
              ),

              // Blurred overlay icon
              if (widget.isBlurred)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.visibility_off_outlined,
                        size: 18, color: Colors.white),
                  ),
                ),

              // Character name badge — bottom
              if (widget.character != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(7)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: raceColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.character!.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.onCharacterTap != null)
                            GestureDetector(
                              onTap: widget.onCharacterTap,
                              child: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 10,
                                  color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Hover controls
              if (_hovered) ...[
                // Blur toggle — top left
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: widget.onToggleBlur,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Icon(
                        widget.isBlurred
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_outlined,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Delete — top right
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.close,
                          size: 10, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Full-screen viewer ─────────────────────────────────────────────

class _FullscreenViewer extends StatefulWidget {
  final List<GalleryItem> items;
  final int initialIndex;
  final List<Character> characters;
  final void Function(Character) onCharacterTap;

  const _FullscreenViewer({
    required this.items,
    required this.initialIndex,
    required this.characters,
    required this.onCharacterTap,
  });

  @override
  State<_FullscreenViewer> createState() => _FullscreenViewerState();
}

class _FullscreenViewerState extends State<_FullscreenViewer> {
  late PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Character? get _currentChar {
    final item = widget.items[_currentIndex];
    return widget.characters
        .where((c) => c.id == item.characterId)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final char = _currentChar;

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Page view
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 0.5,
              maxScale: 6,
              child: Image.file(
                File(widget.items[i].filePath),
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
          // Close
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          // Counter
          if (widget.items.length > 1)
            Positioned(
              top: 10,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.items.length}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          // Character badge — bottom centre
          if (char != null)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => widget.onCharacterTap(char),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.raceColor(char.race)
                              .withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppTheme.raceColor(char.race),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(char.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(width: 6),
                        const Icon(Icons.open_in_new_rounded,
                            size: 11, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Left arrow
          if (_currentIndex > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _pageCtrl.previousPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.chevron_left_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          // Right arrow
          if (_currentIndex < widget.items.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _pageCtrl.nextPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
