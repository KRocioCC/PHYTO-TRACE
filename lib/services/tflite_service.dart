import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/prediction.dart';

class TfliteService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  Map<String, dynamic> _recommendations = {};
  String? _loadedCrop;

  static const Map<String, String> _modelPaths = {
    'apple':  'assets/models/phyto_trace_apple.tflite',
    'potato': 'assets/models/phyto_trace_potato.tflite',
    'tomato': 'assets/models/phyto_trace_tomato.tflite',
  };

  static const Map<String, String> _labelPaths = {
    'apple':  'assets/models/apple_labels.txt',
    'potato': 'assets/models/potato_labels.txt',
    'tomato': 'assets/models/tomato_labels.txt',
  };

  static const Map<String, String> _recoPaths = {
    'apple':  'assets/models/apple_recommendations.json',
    'potato': 'assets/models/potato_recommendations.json',
    'tomato': 'assets/models/tomato_recommendations.json',
  };

  Future<void> loadModel(String crop) async {
    if (_loadedCrop == crop) return;

    _interpreter?.close();
    _interpreter = await Interpreter.fromAsset(_modelPaths[crop]!);

    // Labels: cada línea es "índice:nombre" o solo "nombre"
    final labelData = await rootBundle.loadString(_labelPaths[crop]!);
    _labels = labelData
        .trim()
        .split('\n')
        .map((l) => l.contains(':') ? l.split(':').last.trim() : l.trim())
        .toList();

    // Recomendaciones JSON
    final recoData = await rootBundle.loadString(_recoPaths[crop]!);
    _recommendations = jsonDecode(recoData);

    _loadedCrop = crop;
  }

  Future<Prediction> predictFromFile(File imageFile, String crop) async {
    await loadModel(crop);

    // Leer y redimensionar imagen
    final bytes = await imageFile.readAsBytes();
    final rawImage = img.decodeImage(bytes);
    if (rawImage == null) throw Exception('No se pudo decodificar la imagen');
    final resized = img.copyResize(rawImage, width: 224, height: 224);

    // Construir tensor [1, 224, 224, 3] — image v4 API
    final input = List.generate(
      1,
          (_) => List.generate(
        224,
            (y) => List.generate(
          224,
              (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );

    // Output shape [1, numClasses]
    final output = List.generate(1, (_) => List.filled(_labels.length, 0.0));

    _interpreter!.run(input, output);

    final scores = output[0];
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final maxIndex = scores.indexOf(maxScore);
    final labelName = _labels[maxIndex];

    // Buscar recomendación: clave tipo "Apple___Apple_scab"
    final recoKey =
        '${_capitalize(crop)}___${labelName.replaceAll(' ', '_')}';
    final reco = _recommendations[recoKey] as Map<String, dynamic>?;

    return Prediction(
      label: labelName,
      confidence: maxScore,
      cropType: crop,
      recommendation: reco,
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void dispose() {
    _interpreter?.close();
  }
}