import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Future<void> showShortcutsHelpDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: Row(
        children: [
          Icon(Icons.keyboard_outlined, color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          const Text('Keyboard shortcuts', style: TextStyle(fontSize: 15)),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ShortcutSection('Image viewer', [
              _Shortcut('Esc', 'Close'),
              _Shortcut('← / →', 'Previous / next image'),
              _Shortcut('+ / −', 'Zoom in / out'),
              _Shortcut('Scroll wheel', 'Zoom in / out'),
            ]),
            SizedBox(height: 16),
            _ShortcutSection('Album reader', [
              _Shortcut('Esc', 'Close reader'),
              _Shortcut('Space', 'Play / pause auto-play'),
              _Shortcut('← / → (↑ / ↓ vertical mode)', 'Previous / next page'),
              _Shortcut('+ / −', 'Zoom in / out'),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _ShortcutSection extends StatelessWidget {
  final String title;
  final List<_Shortcut> shortcuts;
  const _ShortcutSection(this.title, this.shortcuts);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ...shortcuts,
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  final String keys;
  final String action;
  const _Shortcut(this.keys, this.action);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(keys,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(action,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
