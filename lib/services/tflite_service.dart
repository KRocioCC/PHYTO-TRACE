import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:developer' as developer;
import '../models/prediction.dart';

class TfliteService {
  Map<String, dynamic> _recommendations = {};
  List<String> _labels = [];
  bool _isInitialized = false;
  Interpreter? _interpreter;

  static const String _modelAssetPath = 'models/phyto_trace_corn.tflite';
  static const String _modelBundlePath = 'assets/models/phyto_trace_corn.tflite';

  Future<void> loadModel() async {
    try {
      developer.log('TfliteService: Iniciando carga de modelo...');

      _interpreter = await _loadInterpreterFromAsset();
      developer.log('TfliteService: Modelo cargado desde $_modelAssetPath');
      
      // Cargar recomendaciones del JSON
      final String jsonString = await rootBundle.loadString('assets/data/corn_recommendations.json');
      _recommendations = jsonDecode(jsonString);
      developer.log('TfliteService: JSON cargado. Claves: ${_recommendations.keys.toList()}');

      // Cargar labels del TXT
      final String labelsString = await rootBundle.loadString('assets/data/corn_labels.txt');
      _labels = labelsString.split('\n').where((line) => line.isNotEmpty).map((line) {
        // Formato: "0:Nombre", extraer solo el nombre
        return line.split(':').sublist(1).join(':').trim();
      }).toList();
      
      developer.log('TfliteService: Labels cargados: $_labels');
      _isInitialized = true;
      developer.log('TfliteService: Inicialización completada');
    } catch (e) {
      developer.log('TfliteService ERROR al cargar: $e');
      rethrow;
    }
  }

  Future<Interpreter> _loadInterpreterFromAsset() async {
    final baseOptions = InterpreterOptions()..threads = 2;
    try {
      return Interpreter.fromAsset(_modelBundlePath, options: baseOptions);
    } catch (e) {
      developer.log('TfliteService: Error creando interpreter base: $e');
    }

    final nnApiOptions = InterpreterOptions()
      ..threads = 1
      ..useNnApiForAndroid = true;
    return Interpreter.fromAsset(_modelBundlePath, options: nnApiOptions);
  }

  Future<Prediction> predictFromFile(File image) async {
    try {
      if (!_isInitialized) {
        developer.log('TfliteService: No inicializado, cargando ahora...');
        await loadModel();
      }

      if (_interpreter == null) {
        throw Exception('El modelo no está inicializado');
      }

      if (_labels.isEmpty) {
        throw Exception('No se encontraron etiquetas en assets/data/corn_labels.txt');
      }

      developer.log('TfliteService: Procesando imagen...');

      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      final inputShape = inputTensor.shape;
      final outputShape = outputTensor.shape;

      if (inputShape.length != 4 || inputShape[0] != 1 || inputShape[3] != 3) {
        throw Exception('Forma de entrada no soportada: $inputShape');
      }

      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];

      final imageBytes = await image.readAsBytes();
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        throw Exception('No se pudo decodificar la imagen seleccionada');
      }

      final resized = img.copyResize(decoded, width: inputWidth, height: inputHeight);
      final input = _buildInputTensor(resized);

      final outputClasses = outputShape.isNotEmpty ? outputShape.last : _labels.length;
      final output = List.generate(1, (_) => List<double>.filled(outputClasses, 0));

      _interpreter!.run(input, output);

      final rawScores = (output.first as List).map((value) => (value as num).toDouble()).toList();
      final scores = _normalizeScores(rawScores);

      var bestIndex = 0;
      var bestScore = scores[0];
      for (var i = 1; i < scores.length; i++) {
        if (scores[i] > bestScore) {
          bestScore = scores[i];
          bestIndex = i;
        }
      }

      final normalizedIndex = bestIndex < _labels.length ? bestIndex : _labels.length - 1;
      final predictedLabel = _labels[normalizedIndex];
      final confidence = bestScore.clamp(0.0, 1.0);

      final topPredictions = <Map<String, dynamic>>[];
      for (var i = 0; i < math.min(scores.length, _labels.length); i++) {
        topPredictions.add({
          'label': _labels[i],
          'score': scores[i],
        });
      }
      topPredictions.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

      developer.log('TfliteService: Label predicho: $predictedLabel (confianza: $confidence)');

      // Obtén recomendación del JSON
      final recommendation = _recommendations[predictedLabel] ?? {
        'diagnostico': 'Análisis completado',
        'accion': 'Revisar resultado',
        'urgencia': 'MEDIA'
      };

      developer.log('TfliteService: Recomendación: $recommendation');

      return Prediction(
        label: predictedLabel,
        confidence: confidence,
        heatmapAsset: 'assets/heatmaps/example_heatmap.png',
        diagnostico: recommendation['diagnostico'] ?? '',
        accion: recommendation['accion'] ?? '',
        urgencia: recommendation['urgencia'] ?? 'MEDIA',
        topPredictions: topPredictions,
        tecnicasNucleares: (recommendation['tecnicas_nucleares'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
        recomendacionesTecnologicas: (recommendation['recomendaciones_tecnologicas'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
        imagenRecomendacion: recommendation['imagen'] as String?,
      );
    } catch (e) {
      developer.log('TfliteService ERROR en predicción: $e');
      rethrow;
    }
  }

  dynamic _buildInputTensor(img.Image resized) {
    final inputType = _interpreter!.getInputTensor(0).type;
    final height = resized.height;
    final width = resized.width;

    if (inputType == TensorType.float32) {
      return [
        List.generate(height, (y) {
          return List.generate(width, (x) {
            final pixel = resized.getPixel(x, y);
            return [
              _preprocessChannel(pixel.r),
              _preprocessChannel(pixel.g),
              _preprocessChannel(pixel.b),
            ];
          });
        }),
      ];
    }

    return [
      List.generate(height, (y) {
        return List.generate(width, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
          ];
        });
      }),
    ];
  }

  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) {
      return const [];
    }
    final maxLogit = logits.reduce(math.max);
    final expValues = logits.map((value) => math.exp(value - maxLogit)).toList();
    final sum = expValues.reduce((a, b) => a + b);
    if (sum == 0) {
      return List<double>.filled(logits.length, 1 / logits.length);
    }
    return expValues.map((value) => value / sum).toList();
  }

  double _preprocessChannel(num channel) {
    return (channel.toDouble() / 127.5) - 1.0;
  }

  List<double> _normalizeScores(List<double> scores) {
    if (scores.isEmpty) {
      return const [];
    }

    final sum = scores.fold<double>(0.0, (accumulator, value) => accumulator + value);
    final looksLikeProbabilities = sum > 0.9 && sum < 1.1 && scores.every((value) => value >= 0 && value <= 1);

    if (looksLikeProbabilities) {
      return scores;
    }

    return _softmax(scores);
  }

  /// Devuelve una lista de recomendaciones de "técnicas nucleares" según
  /// la etiqueta pronosticada o el nivel de urgencia.
  /// Esta función entrega recomendaciones generales y siempre sugiere
  /// consultar con un especialista y respetar la normativa local.
  List<String> getNuclearTechniquesFor(String label, String urgencia) {
    final key = label.toLowerCase();
    final List<String> techniques = [];

    if (urgencia.toUpperCase() == 'ALTA') {
      techniques.addAll([
        'Mapeo isotópico con trazadores (ej. 15N) para seguimiento de nutrientes',
        'Medición no destructiva mediante sensores nucleares para detección temprana',
        'Análisis de marcadores isotópicos para identificar ruta de infección'
      ]);
    } else if (urgencia.toUpperCase() == 'MEDIA') {
      techniques.addAll([
        'Monitoreo isotópico periódico para evaluar eficacia de medidas agronómicas',
        'Técnicas de marcador estable para cuantificar absorción de fertilizantes'
      ]);
    } else {
      techniques.addAll([
        'Monitoreo rutinario con muestreos representativos',
        'Uso de trazadores para estudios experimentales localizados'
      ]);
    }

    // Ajustes por etiqueta conocida (ejemplos)
    if (key.contains('stunt') || key.contains('necrosis') || key.contains('spot')) {
      techniques.add('Análisis isotópico en tejidos afectados para verificar progresión');
    }

    techniques.add('Consultar con un especialista en técnicas nucleares y cumplir la normativa');

    return techniques;
  }

  /// Devuelve la cantidad de labels cargadas (si están disponibles)
  int getLabelsCount() {
    return _labels.length;
  }

  /// Estima el área afectada (m²) para una etiqueta dada en `days` días.
  /// Esta función usa un modelo heurístico simple basado en la confianza
  /// del modelo y en la urgencia reportada.
  Map<String, double> estimateAffectedArea(String label, double confidence, int days, String urgencia) {
    // Base area factor: más confianza => mayor área inicial estimada
    final baseArea = (confidence.clamp(0.0, 1.0) * 100.0); // 0..100 m² base

    // Urgency multiplier
    final urg = urgencia.toUpperCase();
    double urgencyFactor = 1.0;
    if (urg == 'ALTA') urgencyFactor = 1.6;
    else if (urg == 'MEDIA') urgencyFactor = 1.0;
    else urgencyFactor = 0.6;

    // Growth per day factor (example heuristic)
    final dailyGrowth = 0.06 + (confidence * 0.08); // between 0.06 and 0.14

    final projected = baseArea * urgencyFactor * (1 + dailyGrowth * days);

    // Provide a small range +/- 20%
    final min = (projected * 0.8).clamp(0.0, double.infinity);
    final max = (projected * 1.2).clamp(0.0, double.infinity);

    return {'min': min, 'max': max};
  }

  /// Estima el porcentaje de pérdida de cosecha esperado en `days` días.
  /// Retorna 0..100.
  double estimateCropLossPercent(String label, double confidence, int days, String urgencia) {
    final conf = confidence.clamp(0.0, 1.0);
    final urg = urgencia.toUpperCase();
    double severity = 1.0;
    if (urg == 'ALTA') severity = 1.4;
    else if (urg == 'MEDIA') severity = 0.9;
    else severity = 0.5;

    // basic growth of impact over days
    final dayFactor = 1 + (days / 14.0); // 1.0 -> 1 + days/14

    // Label-based modifier (minor heuristic)
    double labelModifier = 1.0;
    final key = label.toLowerCase();
    if (key.contains('severe') || key.contains('blight') || key.contains('necrosis')) labelModifier = 1.2;
    if (key.contains('spot') || key.contains('mild')) labelModifier = 0.85;

    final raw = conf * severity * dayFactor * labelModifier;
    final percent = (raw * 100).clamp(0.0, 100.0);
    return percent;
  }

  /// Combine estimations into a temporal prediction map
  Map<String, dynamic> getTemporalPrediction(String label, double confidence, int days, String urgencia) {
    final area = estimateAffectedArea(label, confidence, days, urgencia);
    final loss = estimateCropLossPercent(label, confidence, days, urgencia);
    return {
      'days': days,
      'area_min': area['min'],
      'area_max': area['max'],
      'loss_percent': loss,
    };
  }
}


