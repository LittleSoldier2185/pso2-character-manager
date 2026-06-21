import 'dart:math' show pi, sin, cos;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum TierBorderEffect {
  // shared
  none,
  shimmer,
  pulseGlow,
  particleSparks,
  plasmaWave,
  dashedRotation,
  doubleRing,
  // S-exclusive
  rainbow,
  auroraPulse,
  prismaticSparkle,
  holographic,
  // A-exclusive
  molten,
  // B-exclusive
  electricArc,
  // C-exclusive
  emberGlow,
  // D-exclusive
  subtlePulse,
  dimFlicker;

  String get displayName => switch (this) {
    TierBorderEffect.none             => 'None',
    TierBorderEffect.shimmer          => 'Shimmer',
    TierBorderEffect.pulseGlow        => 'Pulse Glow',
    TierBorderEffect.particleSparks   => 'Particle Sparks',
    TierBorderEffect.plasmaWave       => 'Plasma Wave',
    TierBorderEffect.dashedRotation   => 'Dashed Rotation',
    TierBorderEffect.doubleRing       => 'Double Ring',
    TierBorderEffect.rainbow          => 'Rainbow',
    TierBorderEffect.auroraPulse      => 'Aurora Pulse',
    TierBorderEffect.prismaticSparkle => 'Prismatic Sparkle',
    TierBorderEffect.holographic      => 'Holographic',
    TierBorderEffect.molten           => 'Molten',
    TierBorderEffect.electricArc      => 'Electric Arc',
    TierBorderEffect.emberGlow        => 'Ember Glow',
    TierBorderEffect.subtlePulse      => 'Subtle Pulse',
    TierBorderEffect.dimFlicker       => 'Dim Flicker',
  };
}

Widget buildTierBorder({
  required TierBorderEffect effect,
  required Color color,
  required Widget child,
}) =>
    switch (effect) {
      TierBorderEffect.none             => _PlainBorder(color: color, child: child),
      TierBorderEffect.shimmer          => _ShimmerBorder(color: color, child: child),
      TierBorderEffect.pulseGlow        => _PulseGlowBorder(color: color, child: child),
      TierBorderEffect.particleSparks   => _ParticleSparksBorder(color: color, child: child),
      TierBorderEffect.plasmaWave       => _PlasmaWaveBorder(color: color, child: child),
      TierBorderEffect.dashedRotation   => _DashedRotationBorder(color: color, child: child),
      TierBorderEffect.doubleRing       => _DoubleRingBorder(color: color, child: child),
      TierBorderEffect.rainbow          => _RainbowBorder(child: child),
      TierBorderEffect.auroraPulse      => _AuroraPulseBorder(child: child),
      TierBorderEffect.prismaticSparkle => _PrismaticSparkleBorder(child: child),
      TierBorderEffect.holographic      => _HolographicBorder(child: child),
      TierBorderEffect.molten           => _MoltenBorder(color: color, child: child),
      TierBorderEffect.electricArc      => _ElectricArcBorder(color: color, child: child),
      TierBorderEffect.emberGlow        => _EmberGlowBorder(color: color, child: child),
      TierBorderEffect.subtlePulse      => _SubtlePulseBorder(color: color, child: child),
      TierBorderEffect.dimFlicker       => _DimFlickerBorder(color: color, child: child),
    };

// ── Phase driver ──────────────────────────────────────────────────
// Drives a ValueNotifier<double> from raw elapsed microseconds.
// Using integer modulo avoids any AnimationController "completed"
// event — phase goes 0.9999→0.0001 with no boundary frame.

class _Phase with WidgetsBindingObserver {
  Ticker? _ticker;
  final notifier = ValueNotifier<double>(0.0);

  void start(TickerProvider vsync, int cycleUs) {
    WidgetsBinding.instance.addObserver(this);
    _ticker = vsync.createTicker(
      (e) => notifier.value =
          (e.inMicroseconds % cycleUs) / cycleUs.toDouble(),
    )..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ticker?.muted = state != AppLifecycleState.resumed;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.dispose();
    notifier.dispose();
  }
}

// ── None ──────────────────────────────────────────────────────────

class _PlainBorder extends StatelessWidget {
  final Color color;
  final Widget child;
  const _PlainBorder({required this.color, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1.5),
        ),
        child: child,
      );
}

// ── Rainbow ───────────────────────────────────────────────────────

class _RainbowBorder extends StatefulWidget {
  final Widget child;
  const _RainbowBorder({required this.child});
  @override
  State<_RainbowBorder> createState() => _RainbowBorderState();
}

class _RainbowBorderState extends State<_RainbowBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();
  static const _colors = [
    Color(0xFFFF0000), Color(0xFFFF7700), Color(0xFFFFFF00),
    Color(0xFF00CC00), Color(0xFF0077FF), Color(0xFF8B00FF),
    Color(0xFFFF0000),
  ];

  @override
  void initState() { super.initState(); _fx.start(this, 3000000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: SweepGradient(
              colors: _colors,
              transform: GradientRotation(_fx.notifier.value * 2 * pi),
            ),
          ),
          padding: const EdgeInsets.all(1.5),
          child: child,
        ),
        child: widget.child,
      );
}

// ── Rainbow text label ────────────────────────────────────────────

class RainbowText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const RainbowText(this.text, {required this.style, super.key});
  @override
  State<RainbowText> createState() => _RainbowTextState();
}

class _RainbowTextState extends State<RainbowText>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();
  static const _stops = [
    Color(0xFFFF0000), Color(0xFFFF7700), Color(0xFFFFFF00),
    Color(0xFF00CC00), Color(0xFF0077FF), Color(0xFF8B00FF),
    Color(0xFFFF0000),
  ];

  @override
  void initState() { super.initState(); _fx.start(this, 3000000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  Color get _color {
    final t = _fx.notifier.value * (_stops.length - 1);
    final i = t.floor().clamp(0, _stops.length - 2);
    return Color.lerp(_stops[i], _stops[i + 1], t - i)!;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, __) =>
            Text(widget.text, style: widget.style.copyWith(color: _color)),
      );
}

// ── Shimmer ───────────────────────────────────────────────────────

class _ShimmerBorder extends StatefulWidget {
  final Color color;
  final Widget child;
  const _ShimmerBorder({required this.color, required this.child});
  @override
  State<_ShimmerBorder> createState() => _ShimmerBorderState();
}

class _ShimmerBorderState extends State<_ShimmerBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();

  @override
  void initState() { super.initState(); _fx.start(this, 3000000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  List<Color> get _colors {
    final hsl = HSLColor.fromColor(widget.color);
    final dark  = hsl.withLightness((hsl.lightness * 0.5).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.25).clamp(0.0, 1.0)).toColor();
    return [dark, widget.color, light, widget.color, dark];
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: SweepGradient(
              colors: _colors,
              transform: GradientRotation(_fx.notifier.value * 2 * pi),
            ),
          ),
          padding: const EdgeInsets.all(1.5),
          child: child,
        ),
        child: widget.child,
      );
}

// ── Pulse Glow ────────────────────────────────────────────────────

class _PulseGlowBorder extends StatefulWidget {
  final Color color;
  final Widget child;
  const _PulseGlowBorder({required this.color, required this.child});
  @override
  State<_PulseGlowBorder> createState() => _PulseGlowBorderState();
}

class _PulseGlowBorderState extends State<_PulseGlowBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();

  @override
  void initState() { super.initState(); _fx.start(this, 1800000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) {
          final v = (1 - cos(_fx.notifier.value * 2 * pi)) / 2;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.color.withOpacity(0.3 + v * 0.7),
                width: 1.0 + v * 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(v * 0.5),
                  blurRadius: v * 14,
                  spreadRadius: v * 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: widget.child,
      );
}

// ── Particle Sparks ───────────────────────────────────────────────

class _ParticleSparksBorder extends StatefulWidget {
  final Color color;
  final Widget child;
  const _ParticleSparksBorder({required this.color, required this.child});
  @override
  State<_ParticleSparksBorder> createState() => _ParticleSparksBorderState();
}

class _ParticleSparksBorderState extends State<_ParticleSparksBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();

  @override
  void initState() { super.initState(); _fx.start(this, 2000000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) => CustomPaint(
          painter: _ParticlesPainter(phase: _fx.notifier.value, color: widget.color),
          child: child,
        ),
        child: widget.child,
      );
}

class _ParticlesPainter extends CustomPainter {
  final double phase;
  final Color color;
  static const _count = 8;
  const _ParticlesPainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(9));

    canvas.drawRRect(rrect, Paint()
      ..color = color.withOpacity(0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke);

    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final total = metric.length;

    for (int i = 0; i < _count; i++) {
      final t = (phase + i / _count) % 1.0;

      final headPos = metric.getTangentForOffset(t * total)?.position;
      if (headPos != null) {
        canvas.drawCircle(headPos, 7, Paint()
          ..color = color.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      }

      for (int j = 0; j < 5; j++) {
        final trailT = ((t - j * 0.012) % 1.0 + 1.0) % 1.0;
        final pos = metric.getTangentForOffset(trailT * total)?.position;
        if (pos == null) continue;
        canvas.drawCircle(pos, (4.0 - j * 0.65).clamp(0.8, 4.0),
            Paint()..color = color.withOpacity((1.0 - j / 5) * 0.95));
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) =>
      old.phase != phase || old.color != color;
}

// ── Plasma Wave ───────────────────────────────────────────────────

class _PlasmaWaveBorder extends StatefulWidget {
  final Color color;
  final Widget child;
  const _PlasmaWaveBorder({required this.color, required this.child});
  @override
  State<_PlasmaWaveBorder> createState() => _PlasmaWaveBorderState();
}

class _PlasmaWaveBorderState extends State<_PlasmaWaveBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();

  @override
  void initState() { super.initState(); _fx.start(this, 2000000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) => CustomPaint(
          painter: _PlasmaWavePainter(phase: _fx.notifier.value, color: widget.color),
          child: child,
        ),
        child: widget.child,
      );
}

class _PlasmaWavePainter extends CustomPainter {
  final double phase;
  final Color color;
  const _PlasmaWavePainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(9));
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final total = metric.length;

    const steps = 40;
    for (int i = 0; i < steps; i++) {
      final t = i / steps;
      final intensity = (sin((t + phase) * 2 * pi * 4) + 1) / 2;
      final seg = metric.extractPath(t * total, ((i + 1) / steps) * total);

      if (intensity > 0.6) {
        canvas.drawPath(seg, Paint()
          ..color = color.withOpacity((intensity - 0.6) * 0.6)
          ..strokeWidth = 6.0 + intensity * 4.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }

      canvas.drawPath(seg, Paint()
        ..color = color.withOpacity(0.3 + intensity * 0.7)
        ..strokeWidth = 1.5 + intensity * 4.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_PlasmaWavePainter old) =>
      old.phase != phase || old.color != color;
}

// ── Dashed Rotation ───────────────────────────────────────────────

class _DashedRotationBorder extends StatefulWidget {
  final Color color;
  final Widget child;
  const _DashedRotationBorder({required this.color, required this.child});
  @override
  State<_DashedRotationBorder> createState() => _DashedRotationBorderState();
}

class _DashedRotationBorderState extends State<_DashedRotationBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();

  @override
  void initState() { super.initState(); _fx.start(this, 2000000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) => CustomPaint(
          painter: _DashedRotationPainter(phase: _fx.notifier.value, color: widget.color),
          child: child,
        ),
        child: widget.child,
      );
}

class _DashedRotationPainter extends CustomPainter {
  final double phase;
  final Color color;
  const _DashedRotationPainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(9));
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final total = metric.length;

    const dashLen = 16.0;
    const gapLen  = 8.0;
    const period  = dashLen + gapLen;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.45)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final solidPaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double d = -(phase * period);
    while (d < total) {
      final start = d.clamp(0.0, total);
      final end   = (d + dashLen).clamp(0.0, total);
      if (end > start) {
        final seg = metric.extractPath(start, end);
        canvas.drawPath(seg, glowPaint);
        canvas.drawPath(seg, solidPaint);
      }
      d += period;
    }
  }

  @override
  bool shouldRepaint(_DashedRotationPainter old) =>
      old.phase != phase || old.color != color;
}

// ── Double Ring ───────────────────────────────────────────────────

class _DoubleRingBorder extends StatefulWidget {
  final Color color;
  final Widget child;
  const _DoubleRingBorder({required this.color, required this.child});
  @override
  State<_DoubleRingBorder> createState() => _DoubleRingBorderState();
}

class _DoubleRingBorderState extends State<_DoubleRingBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();

  @override
  void initState() { super.initState(); _fx.start(this, 4000000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  List<Color> _palette(double bump) {
    final hsl = HSLColor.fromColor(widget.color);
    final bright = hsl.withLightness((hsl.lightness + bump).clamp(0.0, 1.0)).toColor();
    return [
      widget.color.withOpacity(0.2),
      widget.color,
      bright,
      widget.color,
      widget.color.withOpacity(0.2),
    ];
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: SweepGradient(
              colors: _palette(0.30),
              transform: GradientRotation(_fx.notifier.value * 2 * pi),
            ),
          ),
          padding: const EdgeInsets.all(2.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: SweepGradient(
                colors: _palette(0.15),
                transform: GradientRotation(-_fx.notifier.value * 2 * pi),
              ),
            ),
            padding: const EdgeInsets.all(1.5),
            child: child,
          ),
        ),
        child: widget.child,
      );
}

// ── Aurora Pulse (S) ──────────────────────────────────────────────

class _AuroraPulseBorder extends StatefulWidget {
  final Widget child;
  const _AuroraPulseBorder({required this.child});
  @override
  State<_AuroraPulseBorder> createState() => _AuroraPulseBorderState();
}

class _AuroraPulseBorderState extends State<_AuroraPulseBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();
  static const _colors = [
    Color(0xFF00FFCC), Color(0xFF0088FF), Color(0xFF8800FF),
    Color(0xFFFF00AA), Color(0xFF00FFCC),
  ];

  @override
  void initState() { super.initState(); _fx.start(this, 8000000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: SweepGradient(
              colors: _colors,
              transform: GradientRotation(_fx.notifier.value * 2 * pi),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0088FF)
                    .withOpacity(0.15 + sin(_fx.notifier.value * 2 * pi).abs() * 0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.all(2.0),
          child: child,
        ),
        child: widget.child,
      );
}

// ── Prismatic Sparkle (S) ─────────────────────────────────────────

class _PrismaticSparkleBorder extends StatefulWidget {
  final Widget child;
  const _PrismaticSparkleBorder({required this.child});
  @override
  State<_PrismaticSparkleBorder> createState() => _PrismaticSparkleState();
}

class _PrismaticSparkleState extends State<_PrismaticSparkleBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();

  @override
  void initState() { super.initState(); _fx.start(this, 3000000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) => CustomPaint(
          painter: _PrismaticSparklePainter(phase: _fx.notifier.value),
          child: child,
        ),
        child: widget.child,
      );
}

class _PrismaticSparklePainter extends CustomPainter {
  final double phase;
  const _PrismaticSparklePainter({required this.phase});

  static const _rc = [
    Color(0xFFFF0000), Color(0xFFFF7700), Color(0xFFFFFF00),
    Color(0xFF00CC00), Color(0xFF0077FF), Color(0xFF8B00FF),
    Color(0xFFFF0000),
  ];

  Color _colorAt(double t) {
    final i = (t * (_rc.length - 1)).floor().clamp(0, _rc.length - 2);
    return Color.lerp(_rc[i], _rc[i + 1], t * (_rc.length - 1) - i)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(9));
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final total = metric.length;

    // Rainbow base — integer multiplier on phase
    const steps = 60;
    for (int i = 0; i < steps; i++) {
      final t = i / steps;
      final seg = metric.extractPath(t * total, ((i + 1) / steps) * total);
      canvas.drawPath(seg, Paint()
        ..color = _colorAt((t + phase) % 1.0).withOpacity(0.7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }

    // Sparkle dots — integer multiplier on phase, color from position
    for (int i = 0; i < 8; i++) {
      final t = (phase + i / 8.0) % 1.0;
      final brightness = (sin(phase * 2 * pi * 3 + i * pi / 2) + 1) / 2;
      if (brightness < 0.35) continue;
      final pos = metric.getTangentForOffset(t * total)?.position;
      if (pos == null) continue;
      final c = _colorAt(t);
      final r = 1.5 + brightness * 3.0;
      canvas.drawCircle(pos, r + 3, Paint()
        ..color = c.withOpacity(brightness * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawCircle(pos, r,
          Paint()..color = Colors.white.withOpacity(brightness * 0.9));
    }
  }

  @override
  bool shouldRepaint(_PrismaticSparklePainter old) => old.phase != phase;
}

// ── Holographic (S) ───────────────────────────────────────────────

class _HolographicBorder extends StatefulWidget {
  final Widget child;
  const _HolographicBorder({required this.child});
  @override
  State<_HolographicBorder> createState() => _HolographicBorderState();
}

class _HolographicBorderState extends State<_HolographicBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();
  static const _colors = [
    Color(0xFFFF00DD), Color(0xFF00FFCC), Color(0xFF4400FF),
    Color(0xFFCC00FF), Color(0xFF00FF88), Color(0xFFFF00DD),
  ];

  @override
  void initState() { super.initState(); _fx.start(this, 4000000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) {
          final a = _fx.notifier.value * 2 * pi;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment(cos(a), sin(a)),
                end: Alignment(-cos(a), -sin(a)),
                colors: _colors,
              ),
            ),
            padding: const EdgeInsets.all(2.0),
            child: child,
          );
        },
        child: widget.child,
      );
}

// ── Molten (A) ────────────────────────────────────────────────────

class _MoltenBorder extends StatefulWidget {
  final Color color;
  final Widget child;
  const _MoltenBorder({required this.color, required this.child});
  @override
  State<_MoltenBorder> createState() => _MoltenBorderState();
}

class _MoltenBorderState extends State<_MoltenBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();

  List<Color> get _colors {
    final hsl = HSLColor.fromColor(widget.color);
    final dark   = hsl.withLightness((hsl.lightness * 0.35).clamp(0.0, 1.0)).toColor();
    final bright = hsl.withLightness((hsl.lightness + 0.25).clamp(0.0, 1.0)).toColor();
    final mid    = hsl.withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0)).toColor();
    return [dark, widget.color, bright, mid, dark];
  }

  @override
  void initState() { super.initState(); _fx.start(this, 6000000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: SweepGradient(
              colors: _colors,
              transform: GradientRotation(_fx.notifier.value * 2 * pi),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8C00)
                    .withOpacity(0.15 + sin(_fx.notifier.value * 2 * pi * 2).abs() * 0.2),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.all(2.0),
          child: child,
        ),
        child: widget.child,
      );
}

// ── Electric Arc (B) ──────────────────────────────────────────────

class _ElectricArcBorder extends StatefulWidget {
  final Color color;
  final Widget child;
  const _ElectricArcBorder({required this.color, required this.child});
  @override
  State<_ElectricArcBorder> createState() => _ElectricArcBorderState();
}

class _ElectricArcBorderState extends State<_ElectricArcBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();

  @override
  void initState() { super.initState(); _fx.start(this, 1400000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) => CustomPaint(
          painter: _ElectricArcPainter(phase: _fx.notifier.value, color: widget.color),
          child: child,
        ),
        child: widget.child,
      );
}

class _ElectricArcPainter extends CustomPainter {
  final double phase;
  final Color color;
  const _ElectricArcPainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(9));
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final total = metric.length;

    canvas.drawRRect(rrect, Paint()
      ..color = color.withOpacity(0.22)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke);

    for (int i = 0; i < 4; i++) {
      final t = ((sin(phase * 2 * pi * (5 + i * 4)) + 1) / 2 * 0.8 + i * 0.22) % 1.0;
      final arcLen = 0.07 + sin(phase * 2 * pi * (8 + i * 2)).abs() * 0.04;
      final end = (t + arcLen).clamp(0.0, 1.0);
      if (end <= t) continue;
      final brightness = (sin(phase * 2 * pi * (9 + i * 3)) + 1) / 2;
      if (brightness < 0.25) continue;
      final seg = metric.extractPath(t * total, end * total);
      canvas.drawPath(seg, Paint()
        ..color = Colors.white.withOpacity(brightness * 0.45)
        ..strokeWidth = 8.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawPath(seg, Paint()
        ..color = Colors.white.withOpacity(brightness * 0.95)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_ElectricArcPainter old) =>
      old.phase != phase || old.color != color;
}

// ── Ember Glow (C) ────────────────────────────────────────────────

class _EmberGlowBorder extends StatefulWidget {
  final Color color;
  final Widget child;
  const _EmberGlowBorder({required this.color, required this.child});
  @override
  State<_EmberGlowBorder> createState() => _EmberGlowBorderState();
}

class _EmberGlowBorderState extends State<_EmberGlowBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();

  @override
  void initState() { super.initState(); _fx.start(this, 4500000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) {
          final v = (1 - cos(_fx.notifier.value * 2 * pi)) / 2;
          final warm = Color.lerp(
              const Color(0xFF7A2200), const Color(0xFFFF7700), v)!;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: warm.withOpacity(0.4 + v * 0.4), width: 1.0 + v * 0.8),
              boxShadow: [
                BoxShadow(
                  color: warm.withOpacity(v * 0.35),
                  blurRadius: v * 12,
                  spreadRadius: v * 1.5,
                ),
              ],
            ),
            child: child,
          );
        },
        child: widget.child,
      );
}

// ── Subtle Pulse (D) ──────────────────────────────────────────────

class _SubtlePulseBorder extends StatefulWidget {
  final Color color;
  final Widget child;
  const _SubtlePulseBorder({required this.color, required this.child});
  @override
  State<_SubtlePulseBorder> createState() => _SubtlePulseBorderState();
}

class _SubtlePulseBorderState extends State<_SubtlePulseBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();

  @override
  void initState() { super.initState(); _fx.start(this, 2500000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) {
          final v = (1 - cos(_fx.notifier.value * 2 * pi)) / 2;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.color.withOpacity(0.12 + v * 0.22),
                width: 1.0 + v * 0.5,
              ),
              boxShadow: v > 0.5
                  ? [BoxShadow(
                      color: widget.color.withOpacity((v - 0.5) * 0.25),
                      blurRadius: (v - 0.5) * 8,
                    )]
                  : null,
            ),
            child: child,
          );
        },
        child: widget.child,
      );
}

// ── Dim Flicker (D) ───────────────────────────────────────────────

class _DimFlickerBorder extends StatefulWidget {
  final Color color;
  final Widget child;
  const _DimFlickerBorder({required this.color, required this.child});
  @override
  State<_DimFlickerBorder> createState() => _DimFlickerBorderState();
}

class _DimFlickerBorderState extends State<_DimFlickerBorder>
    with SingleTickerProviderStateMixin {
  final _fx = _Phase();

  @override
  void initState() { super.initState(); _fx.start(this, 600000); }
  @override
  void dispose() { _fx.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _fx.notifier,
        builder: (_, child) {
          final t = _fx.notifier.value * 2 * pi;
          final flicker = (sin(t * 3) * 0.4 + sin(t * 7) * 0.3 + 1) / 2;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.color.withOpacity(0.10 + flicker * 0.28),
                width: 1.0,
              ),
            ),
            child: child,
          );
        },
        child: widget.child,
      );
}
