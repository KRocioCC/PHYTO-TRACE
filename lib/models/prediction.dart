class Prediction {
  final String label;
  final double confidence;
  final String? heatmapAsset;
  final Map<String, dynamic>? recommendation;
  final String cropType;

  Prediction({
    required this.label,
    required this.confidence,
    required this.cropType,
    this.heatmapAsset,
    this.recommendation,
  });
}