import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class XPProgressRing extends StatefulWidget {
  final double progress;
  final String centerLabel;
  final String subLabel;
  final double size;
  final double strokeWidth;

  const XPProgressRing({
    super.key,
    required this.progress,
    required this.centerLabel,
    this.subLabel = '',
    this.size = 120,
    this.strokeWidth = 10,
  });

  @override
  State<XPProgressRing> createState() => _XPProgressRingState();
}

class _XPProgressRingState extends State<XPProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _animation = Tween<double>(begin: 0, end: widget.progress)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(XPProgressRing old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _animation = Tween<double>(begin: old.progress, end: widget.progress)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _animation,
        builder: (_, __) => SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: _animation.value,
              strokeWidth: widget.strokeWidth,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.centerLabel,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: widget.size * 0.13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.subLabel.isNotEmpty)
                    Text(
                      widget.subLabel,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecond,
                        fontSize: widget.size * 0.09,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  const _RingPainter({required this.progress, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2;

    // Track
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = AppColors.primary);

    // Progress arc with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + 2 * math.pi,
      colors: const [AppColors.accent, Color(0xFF00BFAE)],
    );
    canvas.drawArc(
      rect,
      startAngle,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
