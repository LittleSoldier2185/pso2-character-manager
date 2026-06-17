import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../patch_notes.dart';
import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

/// Custom title bar that replaces the native Windows title bar.
/// Must be placed at the top of every full-screen route because the native
/// title bar is hidden globally (TitleBarStyle.hidden in main).
class AppTitleBar extends StatefulWidget {
  const AppTitleBar({super.key});

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximized() async {
    final v = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = v);
  }

  @override
  void onWindowMaximize()   => setState(() => _isMaximized = true);
  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: AppTheme.bgDark,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          // Drag area + branding
          Expanded(
            child: DragToMoveArea(
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'PSO2 Character Manager',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
          // Patch notes
          Tooltip(
            message: "What's new in v$kAppVersion",
            preferBelow: true,
            child: _WinBtn(
              icon: Icons.article_outlined,
              onTap: () => showPatchNotesDialog(context),
            ),
          ),
          // Window controls
          _WinBtn(
            icon: Icons.remove_rounded,
            onTap: () => windowManager.minimize(),
          ),
          _WinBtn(
            icon: _isMaximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            onTap: () async => _isMaximized
                ? await windowManager.unmaximize()
                : await windowManager.maximize(),
          ),
          _WinBtn(
            icon: Icons.close_rounded,
            isClose: true,
            onTap: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

// ── Window control button ─────────────────────────────────────────

class _WinBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;

  const _WinBtn({
    required this.icon,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hovered
        ? (widget.isClose ? const Color(0xFFE81123) : AppTheme.bgSurface)
        : Colors.transparent;
    final iconColor = (_hovered && widget.isClose)
        ? Colors.white
        : AppTheme.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 46,
          height: 36,
          color: bg,
          child: Center(
            child: Icon(widget.icon, size: 14, color: iconColor),
          ),
        ),
      ),
    );
  }
}
