import 'dart:math' as math;

import 'package:flutter/material.dart';

class HeatmapOverlay extends StatelessWidget {
  final List<List<double>> heatmap;
  final double opacity;
  const HeatmapOverlay({super.key, required this.heatmap, this.opacity = 0.5});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HeatmapPainter(heatmap: heatmap, opacity: opacity),
        size: Size.infinite,
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<List<double>> heatmap;
  final double opacity;

  _HeatmapPainter({required this.heatmap, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (heatmap.isEmpty || heatmap.first.isEmpty) {
      return;
    }

    final rows = heatmap.length;
    final cols = heatmap.first.length;
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    final paint = Paint()..style = PaintingStyle.fill;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final value = heatmap[r][c].clamp(0.0, 1.0);
        if (value <= 0.06) continue;

        final displayValue = math.pow(value, 0.55).toDouble().clamp(0.0, 1.0);
        paint.color = _colorForValue(displayValue).withOpacity((displayValue * opacity).clamp(0.0, 0.95));
        final rect = Rect.fromLTWH(
          c * cellWidth,
          r * cellHeight,
          cellWidth + 0.5,
          cellHeight + 0.5,
        );
        canvas.drawRect(rect, paint);
      }
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, math.min(size.shortestSide / 90, 6.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final value = heatmap[r][c].clamp(0.0, 1.0);
        if (value <= 0.55) continue;

        glowPaint.color = Colors.redAccent.withOpacity(((value - 0.45) * opacity).clamp(0.0, 0.8));
        final center = Offset((c + 0.5) * cellWidth, (r + 0.5) * cellHeight);
        final radius = math.max(cellWidth, cellHeight) * (1.1 + value * 0.9);
        canvas.drawCircle(center, radius, glowPaint);
      }
    }
  }

  Color _colorForValue(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (clamped < 0.25) {
      return const Color(0xFFFFF176);
    }
    if (clamped < 0.5) {
      return const Color(0xFFFFD54F);
    }
    if (clamped < 0.75) {
      return const Color(0xFFFF8F00);
    }
    return const Color(0xFFFF1744);
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.heatmap != heatmap || oldDelegate.opacity != opacity;
  }
}
