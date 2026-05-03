import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/character_card.dart';
import 'character_detail_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final results = provider.filteredCharacters;
        final collections = provider.allCollections;
        return Scaffold(
          appBar: AppBar(
            title: TextField(
              onChanged: provider.setSearch,
              decoration: InputDecoration(
                hintText: 'Search characters...',
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search,
                    color: AppTheme.textSecondary),
                suffixIcon: provider.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => provider.setSearch(''),
                      )
                    : null,
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
          body: Column(
            children: [
              _buildFilterBar(context, provider, collections),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          provider.hasActiveFilters
                              ? 'No characters match your filters'
                              : 'Start typing to search',
                          style: const TextStyle(
                              color: AppTheme.textSecondary),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final c = results[index];
                            return CharacterCard(
                              character: c,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CharacterDetailScreen(character: c),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar(
      BuildContext context, CharacterProvider provider, List collections) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text('Filter:',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(width: 8),
            _dropdownChip(
              context: context,
              label: provider.filterRace ?? 'Race',
              icon: Icons.person,
              isActive: provider.filterRace != null,
              options: const ['Human', 'Newman', 'Deuman', 'CAST'],
              onSelected: provider.setFilterRace,
              onClear: () => provider.setFilterRace(null),
            ),
            const SizedBox(width: 6),
            _dropdownChip(
              context: context,
              label: provider.filterGender ?? 'Gender',
              icon: Icons.wc,
              isActive: provider.filterGender != null,
              options: const ['Male', 'Female'],
              onSelected: provider.setFilterGender,
              onClear: () => provider.setFilterGender(null),
            ),
            const SizedBox(width: 6),
            if (provider.hasActiveFilters)
              ActionChip(
                label: const Text('Clear all',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
                onPressed: provider.clearAllFilters,
                backgroundColor: Colors.red.withOpacity(0.1),
                side: const BorderSide(color: Colors.red, width: 0.5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isActive,
    required List<String> options,
    required Function(String) onSelected,
    required VoidCallback onClear,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: isActive ? AppTheme.accent : AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color:
                      isActive ? AppTheme.accent : AppTheme.textSecondary)),
          if (isActive) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close,
                  size: 12, color: AppTheme.accent),
            ),
          ],
        ],
      ),
      selected: isActive,
      onSelected: (_) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final RenderBox overlay = Navigator.of(context)
            .overlay!
            .context
            .findRenderObject() as RenderBox;
        final offset = box.localToGlobal(
            Offset(0, box.size.height),
            ancestor: overlay);
        showMenu<String>(
          context: context,
          color: AppTheme.bgSurface,
          position: RelativeRect.fromLTRB(
              offset.dx, offset.dy, offset.dx + 150, offset.dy + 200),
          items: options
              .map((o) => PopupMenuItem(value: o, child: Text(o)))
              .toList(),
        ).then((v) {
          if (v != null) onSelected(v);
        });
      },
      selectedColor: AppTheme.accent.withOpacity(0.15),
      backgroundColor: AppTheme.bgSurface,
      checkmarkColor: Colors.transparent,
      side: BorderSide(
          color: isActive ? AppTheme.accent : AppTheme.borderColor),
    );
  }
}
