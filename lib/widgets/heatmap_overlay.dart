import 'package:flutter/material.dart';

class HeatmapOverlay extends StatelessWidget {
  final String asset;
  final double opacity;
  const HeatmapOverlay({super.key, required this.asset, this.opacity = 0.5});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(asset, fit: BoxFit.cover),
    );
  }
}
