class Prediction {
  final String label;
  final double confidence;
  final String? heatmapAsset;
  final String? diagnostico;
  final String? accion;
  final String? urgencia;
  final List<Map<String, dynamic>> topPredictions;
  final List<String>? tecnicasNucleares;
  final List<String>? recomendacionesTecnologicas;
  final String? imagenRecomendacion;

  Prediction({
    required this.label,
    required this.confidence,
    this.heatmapAsset,
    this.diagnostico,
    this.accion,
    this.urgencia,
    this.topPredictions = const [],
    this.tecnicasNucleares,
    this.recomendacionesTecnologicas,
    this.imagenRecomendacion,
  });
}

