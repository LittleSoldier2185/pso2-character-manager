import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TagChip extends StatelessWidget {
  final String label;
  final VoidCallback? onDeleted;

  const TagChip({super.key, required this.label, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      deleteIcon:
          onDeleted != null ? const Icon(Icons.close, size: 14) : null,
      onDeleted: onDeleted,
      backgroundColor: AppTheme.bgSurface,
      side: BorderSide(color: AppTheme.accent, width: 0.5),
      labelStyle: TextStyle(color: AppTheme.accent, fontSize: 11),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
