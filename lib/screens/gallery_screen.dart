import 'dart:io';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import '../models/album_data.dart';
import '../models/gallery_data.dart';
import '../models/character_data.dart';
import '../providers/character_provider.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton.dart';
import '../widgets/shortcuts_help_dialog.dart';
import 'character_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String? _filterCharacterId;
  String _search = '';
  int _sizeIndex = 3; // 0=S,1=M,2=L,3=XL
  bool _bulkMode = false;
  final List<String> _bulkSelected = []; // ordered by pick time

  // maxCrossAxisExtent per size
  static const List<double> _sizeExtents = [100, 160, 220, 300];
  // info level: 0=none,1=name,2=name+filename,3=name+filename+date
  static const List<int> _infoLevel = [0, 1, 2, 3];

  IconData _gallerySizeIcon(int size) {
    switch (size) {
      case 0: return Icons.grid_on_rounded;
      case 1: return Icons.grid_view_rounded;
      case 2: return Icons.view_agenda_outlined;
      case 3: return Icons.crop_free_rounded;
      default: return Icons.grid_view_rounded;
    }
  }

  PopupMenuItem<int> _gallerySizeItem(
      int value, String label, IconData icon) {
    final selected = _sizeIndex == value;
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 15,
              color: selected ? AppTheme.accent : AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: selected ? AppTheme.accent : AppTheme.textPrimary)),
          if (selected) ...[
            const Spacer(),
            Icon(Icons.check_rounded, size: 13, color: AppTheme.accent),
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final size = await DataService.instance.getGallerySize();
    if (mounted) setState(() => _sizeIndex = size);
  }

  Future<void> _toggleBlur(GalleryItemData item) async {
    await context.read<CharacterProvider>().toggleGalleryItemBlur(item);
  }

  void _toggleSelect(String itemId) {
    setState(() {
      if (_bulkSelected.contains(itemId)) {
        _bulkSelected.remove(itemId);
      } else {
        _bulkSelected.add(itemId);
      }
    });
  }

  void _exitBulk() => setState(() { _bulkMode = false; _bulkSelected.clear(); });

  Future<void> _bulkAddToAlbum(BuildContext context) async {
    final albums = context.read<CharacterProvider>().allAlbums;
    await showDialog(
      context: context,
      builder: (_) => _AddToAlbumDialog(
        itemIds: List.from(_bulkSelected),
        albums: albums,
      ),
    );
    _exitBulk();
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
            return (char?.name.toLowerCase().contains(q) ?? false)
                || (i.caption?.toLowerCase().contains(q) ?? false);
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
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(
                    bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: _bulkMode
                  ? Row(
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 15, color: AppTheme.accent),
                        const SizedBox(width: 8),
                        Text(
                          _bulkSelected.isEmpty
                              ? 'Select images'
                              : '${_bulkSelected.length} selected',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _bulkSelected.isNotEmpty
                              ? () => _bulkAddToAlbum(context)
                              : null,
                          icon: const Icon(
                              Icons.photo_album_outlined, size: 14),
                          label: const Text('Add to album'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppTheme.accent,
                              textStyle: const TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: _exitBulk,
                          child: const Text('Cancel'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              textStyle: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Text(
                          items.isEmpty
                              ? 'Gallery'
                              : '${items.length} image${items.length == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        // Select button
                        if (items.isNotEmpty)
                          Tooltip(
                            message: 'Select images',
                            child: IconButton(
                              onPressed: () =>
                                  setState(() => _bulkMode = true),
                              icon: const Icon(
                                  Icons.checklist_rounded, size: 16),
                              color: AppTheme.textSecondary,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 16,
                            ),
                          ),
                        const SizedBox(width: 8),
                        // Size picker dropdown
                        PopupMenuButton<int>(
                          color: AppTheme.bgCard,
                          tooltip: 'Gallery size',
                          icon: Icon(
                            _gallerySizeIcon(_sizeIndex),
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: AppTheme.borderColor),
                          ),
                          onSelected: (i) async {
                            setState(() => _sizeIndex = i);
                            await DataService.instance.saveGallerySize(i);
                          },
                          itemBuilder: (_) => [
                            _gallerySizeItem(3, 'Extra large',
                                Icons.crop_free_rounded),
                            _gallerySizeItem(2, 'Large',
                                Icons.view_agenda_outlined),
                            _gallerySizeItem(1, 'Medium',
                                Icons.grid_view_rounded),
                            _gallerySizeItem(0, 'Small',
                                Icons.grid_on_rounded),
                          ],
                        ),
                        const SizedBox(width: 8),
                        // Search bar
                        SizedBox(
                          width: 200,
                          child: TextField(
                            onChanged: (v) => setState(() => _search = v),
                            decoration: InputDecoration(
                              hintText: 'Search by character…',
                              prefixIcon: Icon(Icons.search_rounded,
                                  size: 15, color: AppTheme.textSecondary),
                              suffixIcon: _search.isNotEmpty
                                  ? IconButton(
                                      icon:
                                          const Icon(Icons.clear, size: 14),
                                      onPressed: () =>
                                          setState(() => _search = ''),
                                    )
                                  : null,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              isDense: true,
                            ),
                            style: TextStyle(
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
                decoration: BoxDecoration(
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
              child: provider.isLoading
                  ? const SkeletonGalleryGrid()
                  : items.isEmpty
                  ? _buildEmpty(charsWithImages.isEmpty)
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: _sizeExtents[_sizeIndex],
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: _infoLevel[_sizeIndex] == 0
                            ? 1.0
                            : _infoLevel[_sizeIndex] == 1
                                ? 0.82
                                : _infoLevel[_sizeIndex] == 2
                                    ? 0.74
                                    : 0.68,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final char =
                            _charForItem(item, characters);
                        final selIdx = _bulkSelected.indexOf(item.id);
                        return _GalleryGridCell(
                          item: item,
                          character: char,
                          allItems: items,
                          index: index,
                          isBlurred: item.isBlurred,
                          infoLevel: _infoLevel[_sizeIndex],
                          onToggleBlur: () => _toggleBlur(item),
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
                          bulkMode: _bulkMode,
                          selectionOrder:
                              selIdx >= 0 ? selIdx + 1 : null,
                          onSelect: () => _toggleSelect(item.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  CharacterData? _charForItem(
      GalleryItemData item, List<CharacterData> characters) {
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
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 15),
          ),
          if (noImagesAtAll) ...[
            const SizedBox(height: 8),
            Text(
              'Open a character and add images to its gallery',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, GalleryItemData item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Remove image?'),
        content: Text(
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

enum _GalleryCtxAction { copy, editCaption, addToAlbum }

class _GalleryGridCell extends StatefulWidget {
  final GalleryItemData item;
  final CharacterData? character;
  final List<GalleryItemData> allItems;
  final int index;
  final bool isBlurred;
  final int infoLevel; // 0=none,1=name,2=name+filename,3=name+filename+date
  final VoidCallback onToggleBlur;
  final VoidCallback? onCharacterTap;
  final VoidCallback onDelete;
  final bool bulkMode;
  final int? selectionOrder; // null = not selected; 1+ = pick order
  final VoidCallback? onSelect;

  const _GalleryGridCell({
    required this.item,
    required this.character,
    required this.allItems,
    required this.index,
    required this.isBlurred,
    required this.infoLevel,
    required this.onToggleBlur,
    required this.onCharacterTap,
    required this.onDelete,
    this.bulkMode = false,
    this.selectionOrder,
    this.onSelect,
  });

  @override
  State<_GalleryGridCell> createState() => _GalleryGridCellState();
}

class _GalleryGridCellState extends State<_GalleryGridCell> {
  bool _hovered = false;

  Future<void> _copyToClipboard() async {
    try {
      final bytes = await File(widget.item.filePath(widget.character!.folderPath)).readAsBytes();
      await Pasteboard.writeImage(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Image copied to clipboard'),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (_) {}
  }

  void _showContextMenu(BuildContext ctx, Offset pos) async {
    final size = MediaQuery.of(ctx).size;
    final result = await showMenu<_GalleryCtxAction>(
      context: ctx,
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      position: RelativeRect.fromLTRB(
          pos.dx, pos.dy, size.width - pos.dx, size.height - pos.dy),
      items: [
        PopupMenuItem(
          value: _GalleryCtxAction.copy,
          child: _menuRow(Icons.copy_rounded, 'Copy to clipboard'),
        ),
        PopupMenuItem(
          value: _GalleryCtxAction.editCaption,
          child: _menuRow(
            Icons.edit_note_rounded,
            (widget.item.caption?.isNotEmpty ?? false) ? 'Edit caption' : 'Add caption',
          ),
        ),
        PopupMenuItem(
          value: _GalleryCtxAction.addToAlbum,
          child: _menuRow(Icons.photo_album_outlined, 'Add to album'),
        ),
      ],
    );
    if (!mounted) return;
    switch (result) {
      case _GalleryCtxAction.copy:
        await _copyToClipboard();
      case _GalleryCtxAction.editCaption:
        await _editCaption();
      case _GalleryCtxAction.addToAlbum:
        await _addToAlbum();
      case null:
        break;
    }
  }

  Future<void> _addToAlbum() async {
    if (!mounted) return;
    final albums = context.read<CharacterProvider>().allAlbums;
    await showDialog(
      context: context,
      builder: (_) => _AddToAlbumDialog(itemIds: [widget.item.id], albums: albums),
    );
  }

  Future<void> _editCaption() async {
    final ctrl = TextEditingController(text: widget.item.caption ?? '');
    final hasCaption = widget.item.caption?.isNotEmpty ?? false;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text(hasCaption ? 'Edit caption' : 'Add caption',
            style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 200,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(hintText: 'Caption…', counterText: ''),
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (hasCaption)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text('Clear', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && mounted) {
      await context.read<CharacterProvider>()
          .updateGalleryItemCaption(widget.item, result.isEmpty ? null : result);
    }
  }

  Widget _menuRow(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppTheme.textSecondary),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
    ],
  );

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
    final resolvedPath = widget.character != null
        ? widget.item.filePath(widget.character!.folderPath)
        : '';
    final fileExists = resolvedPath.isNotEmpty && File(resolvedPath).existsSync();
    final raceColor = widget.character != null
        ? AppTheme.raceColor(widget.character!.race)
        : AppTheme.textSecondary;

    final isSelected = widget.selectionOrder != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.bulkMode
            ? widget.onSelect
            : fileExists
                ? _viewFullscreen
                : null,
        onSecondaryTapUp: (!widget.bulkMode && fileExists)
            ? (d) => _showContextMenu(context, d.globalPosition)
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isSelected
                    ? AppTheme.accent
                    : _hovered
                        ? AppTheme.accent.withOpacity(0.5)
                        : AppTheme.borderColor,
                width: isSelected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image area ──────────────────────────────────
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: widget.infoLevel == 0
                          ? BorderRadius.circular(7)
                          : const BorderRadius.vertical(
                              top: Radius.circular(7)),
                      child: fileExists
                          ? widget.isBlurred
                              ? ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                      sigmaX: 18, sigmaY: 18),
                                  child: Image.file(
                                    File(resolvedPath),
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  ),
                                )
                              : Image.file(
                                  File(resolvedPath),
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

                    // Hover overlay name badge — only shown on S size (infoLevel 0)
                    if (widget.infoLevel == 0 && widget.character != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedOpacity(
                          opacity: _hovered ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            padding:
                                const EdgeInsets.fromLTRB(6, 4, 6, 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(7)),
                            ),
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
                        ),
                      ),

                    // Bulk selection overlay + number badge
                    if (widget.bulkMode) ...[
                      if (isSelected)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: widget.infoLevel == 0
                                ? BorderRadius.circular(6)
                                : const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                            child: ColoredBox(
                              color:
                                  AppTheme.accent.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accent
                                : Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: isSelected
                                ? Text(
                                    '${widget.selectionOrder}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  )
                                : const Icon(Icons.add_rounded,
                                    size: 12, color: Colors.white70),
                          ),
                        ),
                      ),
                    ],

                    // Hover controls
                    if (!widget.bulkMode && _hovered) ...[
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

              // ── Info panel (M / L / XL only) ────────────────
              if (widget.infoLevel >= 1)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Character name — M, L, XL
                      if (widget.character != null)
                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: raceColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.character!.name,
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.onCharacterTap != null)
                              GestureDetector(
                                onTap: widget.onCharacterTap,
                                child: Icon(
                                    Icons.open_in_new_rounded,
                                    size: 9,
                                    color: AppTheme.textSecondary),
                              ),
                          ],
                        ),
                      // Filename — L, XL
                      if (widget.infoLevel >= 2) ...[
                        const SizedBox(height: 2),
                        Text(
                          resolvedPath.split(r'\').last.split('/').last,
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 9),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // Date added — XL only
                      if (widget.infoLevel >= 3) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Added ${_formatDate(widget.item.addedAt)}',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 9),
                        ),
                      ],
                      // Caption — L and XL
                      if (widget.infoLevel >= 2 && (widget.item.caption?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.item.caption!,
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 9,
                              fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ── Full-screen viewer ─────────────────────────────────────────────

class _FullscreenViewer extends StatefulWidget {
  final List<GalleryItemData> items;
  final int initialIndex;
  final List<CharacterData> characters;
  final void Function(CharacterData) onCharacterTap;

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
  final _revealedIds = <String>{};
  double _zoomLevel = 1.0;
  final _transformCtrl = TransformationController();
  Size _viewerSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  void _setZoom(double z) {
    final v = z.clamp(1.0, 6.0);
    _zoomAtCursor(Offset(_viewerSize.width / 2, _viewerSize.height / 2), v);
  }

  void _zoomAtCursor(Offset cursor, double newScale) {
    final v = newScale.clamp(1.0, 6.0);
    if (v == _zoomLevel) return;
    if (v == 1.0) { _resetZoom(); setState(() {}); return; }
    final change = v / _zoomLevel;
    final pivot = Matrix4.identity()
      ..translate(cursor.dx, cursor.dy, 0.0)
      ..scale(change, change, 1.0)
      ..translate(-cursor.dx, -cursor.dy, 0.0);
    pivot.multiply(_transformCtrl.value);
    _transformCtrl.value = pivot;
    setState(() => _zoomLevel = v);
  }

  void _resetZoom() {
    _transformCtrl.value = Matrix4.identity();
    _zoomLevel = 1.0;
  }

  CharacterData? get _currentChar {
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
      child: Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) {
            final z = (_zoomLevel - e.scrollDelta.dy * 0.005).clamp(1.0, 6.0);
            _zoomAtCursor(e.localPosition, z);
          }
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, e) {
            if (e is! KeyDownEvent) return KeyEventResult.ignored;
            final k = e.logicalKey;
            if (k == LogicalKeyboardKey.escape) {
              Navigator.pop(context);
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.arrowLeft && _currentIndex > 0) {
              _pageCtrl.previousPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut);
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.arrowRight &&
                _currentIndex < widget.items.length - 1) {
              _pageCtrl.nextPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut);
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.numpadAdd ||
                k == LogicalKeyboardKey.equal) {
              _setZoom(_zoomLevel + 0.5);
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.numpadSubtract ||
                k == LogicalKeyboardKey.minus) {
              _setZoom(_zoomLevel - 0.5);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: LayoutBuilder(builder: (_, constraints) {
            _viewerSize = constraints.biggest;
            return Stack(
        children: [
          // Page view
          PageView.builder(
            controller: _pageCtrl,
            physics: _zoomLevel > 1.0
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.items.length,
            onPageChanged: (i) {
              _resetZoom();
              setState(() => _currentIndex = i);
            },
            itemBuilder: (_, i) {
              final item = widget.items[i];
              final char = widget.characters
                  .where((c) => c.id == item.characterId)
                  .firstOrNull;
              final path = item.filePath(char?.folderPath ?? '');
              final blurStrict = context.read<CharacterProvider>().blurSensitiveInViews;
              final needsReveal = blurStrict && item.isBlurred && !_revealedIds.contains(item.id);
              return needsReveal
                  ? GestureDetector(
                      onTap: () => setState(() => _revealedIds.add(item.id)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Image.file(File(path), fit: BoxFit.contain, gaplessPlayback: true),
                          ),
                          const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility_off_outlined, size: 48, color: Colors.white70),
                                SizedBox(height: 10),
                                Text('Click to reveal',
                                    style: TextStyle(color: Colors.white54, fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : InteractiveViewer(
                      transformationController: _transformCtrl,
                      scaleEnabled: false,
                      panEnabled: _zoomLevel > 1.0,
                      child: Image.file(File(path), fit: BoxFit.contain, gaplessPlayback: true),
                    );
            },
          ),
          // Shortcuts help
          Positioned(
            top: 8,
            right: 44,
            child: GestureDetector(
              onTap: () => showShortcutsHelpDialog(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.help_outline,
                    color: Colors.white, size: 18),
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
          // Caption — above character badge
          if (widget.items[_currentIndex].caption?.isNotEmpty ?? false)
            Positioned(
              bottom: char != null ? 52 : 12,
              left: 24,
              right: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.items[_currentIndex].caption!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
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
          // Zoom bar
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _setZoom(_zoomLevel - 0.5),
                    child: Icon(Icons.zoom_out_rounded,
                        color: _zoomLevel > 1.0
                            ? Colors.white70
                            : Colors.white30,
                        size: 15),
                  ),
                  SizedBox(
                    width: 140,
                    child: Slider(
                      value: _zoomLevel,
                      min: 1.0,
                      max: 6.0,
                      activeColor: AppTheme.accent,
                      inactiveColor: Colors.white24,
                      onChanged: _setZoom,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _setZoom(_zoomLevel + 0.5),
                    child: Icon(Icons.zoom_in_rounded,
                        color: _zoomLevel < 6.0
                            ? Colors.white70
                            : Colors.white30,
                        size: 15),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_zoomLevel.toStringAsFixed(1)}×',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
            );
          }),
        ),
      ),
    );
  }
}

// ── Add-to-album dialog ────────────────────────────────────────────

class _AddToAlbumDialog extends StatefulWidget {
  final List<String> itemIds;
  final List<AlbumData> albums;

  const _AddToAlbumDialog({required this.itemIds, required this.albums});

  @override
  State<_AddToAlbumDialog> createState() => _AddToAlbumDialogState();
}

class _AddToAlbumDialogState extends State<_AddToAlbumDialog> {
  final _ctrl = TextEditingController();
  bool _showNew = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CharacterProvider>();
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: Text(
        widget.itemIds.length > 1
            ? 'Add ${widget.itemIds.length} images to album'
            : 'Add to album',
        style: const TextStyle(fontSize: 15),
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.albums.isEmpty && !_showNew)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('No albums yet.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ...widget.albums.map((album) {
              final newCount = widget.itemIds
                  .where((id) => !album.itemIds.contains(id))
                  .length;
              final already = newCount == 0;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  already ? Icons.check_circle_rounded : Icons.photo_album_outlined,
                  size: 18,
                  color: already ? AppTheme.accent : AppTheme.textSecondary,
                ),
                title: Text(album.name,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                subtitle: Text(
                  already
                      ? 'Already added'
                      : widget.itemIds.length > 1
                          ? 'Adds $newCount image${newCount == 1 ? '' : 's'}'
                          : '${album.itemIds.length} image${album.itemIds.length == 1 ? '' : 's'}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                onTap: already ? null : () async {
                  await provider.addItemsToAlbum(album, widget.itemIds);
                  if (context.mounted) Navigator.pop(context);
                },
              );
            }),
            if (_showNew) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Album name…', isDense: true),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                onSubmitted: (name) async {
                  if (name.trim().isEmpty) return;
                  final album = await provider.createAlbum(name.trim());
                  await provider.addItemsToAlbum(album, widget.itemIds);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!_showNew)
          TextButton(
            onPressed: () => setState(() => _showNew = true),
            child: const Text('New album'),
          )
        else
          ElevatedButton(
            onPressed: () async {
              final name = _ctrl.text.trim();
              if (name.isEmpty) return;
              final album = await provider.createAlbum(name);
              await provider.addItemsToAlbum(album, widget.itemIds);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create & add'),
          ),
      ],
    );
  }
}
