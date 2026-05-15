import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tag.dart';
import '../theme/app_theme.dart';

class TagChip extends StatelessWidget {
  /// Pass [tag] (uses Tag colour) or [label]+[color] for plain strings.
  final Tag? tag;
  final String? label;
  final Color? color;
  final VoidCallback? onDeleted;

  const TagChip({
    super.key,
    this.tag,
    this.label,
    this.color,
    this.onDeleted,
  }) : assert(tag != null || label != null, 'Provide tag or label');

  @override
  Widget build(BuildContext context) {
    final Color c = tag?.color ?? color ?? AppTheme.accent;
    final String text = tag?.name ?? label ?? '';

    return Material(
      type: MaterialType.transparency,
      child: Chip(
        label: Text(text),
        deleteIcon:
            onDeleted != null ? const Icon(Icons.close, size: 14) : null,
        onDeleted: onDeleted,
        backgroundColor: c.withOpacity(0.1),
        side: BorderSide(color: c.withOpacity(0.6), width: 0.5),
        labelStyle: TextStyle(color: c, fontSize: 11),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ── Colour picker dialog ───────────────────────────────────────────

/// Opens a colour picker dialog. Returns the selected colour, or null if cancelled.
Future<Color?> showColorPickerDialog(
  BuildContext context,
  Color initialColor, {
  String title = 'Pick a colour',
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(
      initialColor: initialColor,
      title: title,
    ),
  );
}

// ── HSV math helpers ──────────────────────────────────────────────

List<double> _colorToHsv(Color c) {
  final r = c.r, g = c.g, b = c.b;
  final max = [r, g, b].reduce((a, b) => a > b ? a : b);
  final min = [r, g, b].reduce((a, b) => a < b ? a : b);
  final delta = max - min;
  double h = 0;
  if (delta != 0) {
    if (max == r)      h = 60 * (((g - b) / delta) % 6);
    else if (max == g) h = 60 * (((b - r) / delta) + 2);
    else               h = 60 * (((r - g) / delta) + 4);
  }
  if (h < 0) h += 360;
  final s = max == 0 ? 0.0 : delta / max;
  final v = max.toDouble();
  return [h, s, v];
}

Color _hsvToColor(double h, double s, double v) {
  final hi = (h / 60).floor() % 6;
  final f = h / 60 - (h / 60).floor();
  final p = v * (1 - s);
  final q = v * (1 - f * s);
  final t = v * (1 - (1 - f) * s);
  late double r, g, b;
  switch (hi) {
    case 0: r = v; g = t; b = p;
    case 1: r = q; g = v; b = p;
    case 2: r = p; g = v; b = t;
    case 3: r = p; g = q; b = v;
    case 4: r = t; g = p; b = v;
    default: r = v; g = p; b = q;
  }
  return Color.fromARGB(255, (r * 255).round(), (g * 255).round(), (b * 255).round());
}

String _toHex(Color c) =>
    '#${c.red.toRadixString(16).padLeft(2, '0')}${c.green.toRadixString(16).padLeft(2, '0')}${c.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();

// ── HSV square painter ────────────────────────────────────────────

class _HsvSquarePainter extends CustomPainter {
  final double hue;
  const _HsvSquarePainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // White → hue gradient (saturation)
    final hueColor = _hsvToColor(hue, 1, 1);
    final satGrad = LinearGradient(
      colors: [Colors.white, hueColor],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = satGrad);
    // Transparent → black gradient (value)
    final valGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = valGrad);
  }

  @override
  bool shouldRepaint(_HsvSquarePainter old) => old.hue != hue;
}

// ── Hue bar painter ───────────────────────────────────────────────

class _HueBarPainter extends CustomPainter {
  const _HueBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final grad = LinearGradient(colors: [
      const Color(0xFFFF0000), const Color(0xFFFFFF00), const Color(0xFF00FF00),
      const Color(0xFF00FFFF), const Color(0xFF0000FF), const Color(0xFFFF00FF),
      const Color(0xFFFF0000),
    ]).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..shader = grad,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Dialog ────────────────────────────────────────────────────────

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;
  const _ColorPickerDialog({
    required this.initialColor,
    required this.title,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _h, _s, _v;
  late TextEditingController _hexCtrl;
  bool _hexError = false;

  static const _presets = [
    Color(0xFF00B4D8), Color(0xFF3B82F6), Color(0xFFBC8CFF),
    Color(0xFFFFC107), Color(0xFF3FB950), Color(0xFFFF7B72),
    Color(0xFFFF6B9D), Color(0xFFFF9500), Color(0xFF00E5FF),
    Color(0xFFE040FB), Color(0xFF69F0AE), Color(0xFFFFD54F),
  ];

  Color get _current => _hsvToColor(_h, _s, _v);

  @override
  void initState() {
    super.initState();
    final hsv = _colorToHsv(widget.initialColor);
    _h = hsv[0]; _s = hsv[1]; _v = hsv[2];
    _hexCtrl = TextEditingController(text: _toHex(_current));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  void _setColor(Color c) {
    final hsv = _colorToHsv(c);
    setState(() {
      _h = hsv[0]; _s = hsv[1]; _v = hsv[2];
      _hexCtrl.text = _toHex(_current);
      _hexError = false;
    });
  }

  void _onHexSubmit(String val) {
    final clean = val.replaceAll('#', '').trim();
    if (clean.length == 6) {
      try {
        final c = Color(int.parse('FF$clean', radix: 16));
        _setColor(c);
        return;
      } catch (_) {}
    }
    setState(() => _hexError = true);
  }

  Widget _buildHsvSquare() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = constraints.maxWidth;
      return GestureDetector(
        onPanDown: (d) => _onSquareDrag(d.localPosition, size),
        onPanUpdate: (d) => _onSquareDrag(d.localPosition, size),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: size, height: size * 0.6,
            child: Stack(children: [
              CustomPaint(
                size: Size(size, size * 0.6),
                painter: _HsvSquarePainter(_h),
              ),
              // Crosshair
              Positioned(
                left: _s * size - 7,
                top: (1 - _v) * size * 0.6 - 7,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 2)],
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }

  void _onSquareDrag(Offset pos, double size) {
    setState(() {
      _s = (pos.dx / size).clamp(0.0, 1.0);
      _v = 1 - (pos.dy / (size * 0.6)).clamp(0.0, 1.0);
      _hexCtrl.text = _toHex(_current);
    });
  }

  Widget _buildHueBar() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        onPanDown: (d) => _onHueDrag(d.localPosition.dx, width),
        onPanUpdate: (d) => _onHueDrag(d.localPosition.dx, width),
        child: SizedBox(
          height: 20,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: CustomPaint(painter: const _HueBarPainter()),
            ),
            // Thumb
            Positioned(
              left: (_h / 360) * width - 9,
              top: -2,
              child: Container(
                width: 18, height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 3, offset: const Offset(0, 1))],
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }

  void _onHueDrag(double dx, double width) {
    setState(() {
      _h = ((dx / width) * 360).clamp(0.0, 360.0);
      _hexCtrl.text = _toHex(_current);
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: Text(widget.title,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HSV square ──
              _buildHsvSquare(),
              const SizedBox(height: 12),
              // ── Hue slider ──
              _buildHueBar(),
              const SizedBox(height: 14),
              // ── Swatch + hex ──
              Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: current,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _hexCtrl,
                    onSubmitted: _onHexSubmit,
                    onEditingComplete: () => _onHexSubmit(_hexCtrl.text),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: _hexCtrl.text.startsWith('#') ? '' : '# ',
                      prefixStyle: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      filled: true,
                      fillColor: AppTheme.bgSurface,
                      errorText: _hexError ? 'Invalid hex' : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.accent),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              // ── Presets ──
              const Text('Quick presets',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _presets.map((c) {
                  final selected = current.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () => _setColor(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              // ── Preview chip ──
              Row(children: [
                const Text('Preview: ',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: current.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: current.withOpacity(0.6), width: 0.5),
                  ),
                  child: Text('Tag name',
                      style: TextStyle(
                          color: current, fontSize: 11, fontWeight: FontWeight.w500)),
                ),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: current),
          onPressed: () => Navigator.pop(context, current),
          child: Text('Select',
              style: TextStyle(
                  color: current.computeLuminance() > 0.4
                      ? Colors.black87
                      : Colors.white)),
        ),
      ],
    );
  }
}
