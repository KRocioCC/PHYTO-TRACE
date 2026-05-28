class Prediction {
  final String label;
  final double confidence;
  final String? heatmapAsset;

  Prediction({required this.label, required this.confidence, this.heatmapAsset});
}
