import 'dart:io';

import '../models/prediction.dart';

class TfliteService {
  Future<void> loadModel() async {
    // TODO: load Interpreter.fromAsset('model.tflite') here when model added
  }

  Future<Prediction> predictFromFile(File image) async {
    // Placeholder implementation: replace with real inference using tflite_flutter
    await Future.delayed(const Duration(milliseconds: 600));
    return Prediction(label: 'Fusarium Wilt', confidence: 0.92, heatmapAsset: 'assets/heatmaps/example_heatmap.png');
  }
}
