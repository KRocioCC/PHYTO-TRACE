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

  /// Genera un mapa de calor sintético para visualización educativa.
  /// No intenta localizar daño real; solo simula zonas probables según
  /// etiqueta, confianza y urgencia.
  List<List<double>> generateSyntheticHeatmap(
    String label,
    double confidence,
    String urgencia, {
    int rows = 24,
    int cols = 24,
  }) {
    final heatmap = List.generate(rows, (_) => List<double>.filled(cols, 0.0));
    final normalizedConfidence = confidence.clamp(0.0, 1.0);
    final key = label.toLowerCase();

    final hotspots = <Map<String, double>>[];
    if (key == 'healthy') {
      hotspots.add({'x': 0.5, 'y': 0.5, 'strength': 0.08});
    } else if (key.contains('rust')) {
      hotspots.addAll([
        {'x': 0.33, 'y': 0.26, 'strength': 0.96},
        {'x': 0.66, 'y': 0.57, 'strength': 0.72},
      ]);
    } else if (key.contains('blight')) {
      hotspots.addAll([
        {'x': 0.50, 'y': 0.34, 'strength': 1.00},
        {'x': 0.47, 'y': 0.69, 'strength': 0.60},
      ]);
    } else if (key.contains('cercospora') || key.contains('spot')) {
      hotspots.addAll([
        {'x': 0.29, 'y': 0.33, 'strength': 0.84},
        {'x': 0.73, 'y': 0.63, 'strength': 0.66},
      ]);
    } else {
      hotspots.addAll([
        {'x': 0.44, 'y': 0.31, 'strength': 0.88},
        {'x': 0.60, 'y': 0.65, 'strength': 0.72},
      ]);
    }

    final urgencyBoost = urgencia.toUpperCase() == 'ALTA'
        ? 1.15
        : urgencia.toUpperCase() == 'MEDIA'
            ? 1.0
            : 0.85;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final x = cols == 1 ? 0.5 : c / (cols - 1);
        final y = rows == 1 ? 0.5 : r / (rows - 1);

        var value = 0.0;
        for (final hotspot in hotspots) {
          final hx = hotspot['x'] ?? 0.5;
          final hy = hotspot['y'] ?? 0.5;
          final strength = hotspot['strength'] ?? 0.5;
          final dx = x - hx;
          final dy = y - hy;
          final distance = math.sqrt((dx * dx) + (dy * dy));
          final sigma = key == 'healthy' ? 0.22 : 0.11;
          final gaussian = math.exp(-((distance * distance) / (2 * sigma * sigma)));
          value += gaussian * strength;
        }

        // Suavizado base para que no quede un mapa totalmente vacío.
        value *= (0.42 + normalizedConfidence * 1.15) * urgencyBoost;
        value = math.pow(value.clamp(0.0, 1.0), 0.65).toDouble();
        heatmap[r][c] = value.clamp(0.0, 1.0);
      }
    }

    return heatmap;
  }

  /// Genera un mapa de calor a partir de la imagen real.
  /// Las zonas oscuras o con menor presencia de verde se pintan con mayor intensidad.
  List<List<double>> generateImageDamageHeatmap(
    File imageFile, {
    int rows = 28,
    int cols = 28,
  }) {
    final bytes = imageFile.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return List.generate(rows, (_) => List<double>.filled(cols, 0.0));
    }

    final analyzed = img.copyResize(decoded, width: 224, height: 224, interpolation: img.Interpolation.average);
    final totalWidth = analyzed.width.toDouble();
    final totalHeight = analyzed.height.toDouble();
    final cellWidth = totalWidth / cols;
    final cellHeight = totalHeight / rows;

    final heatmap = List.generate(rows, (_) => List<double>.filled(cols, 0.0));
    final brightnessMap = List.generate(rows, (_) => List<double>.filled(cols, 0.0));

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final startX = (col * cellWidth).floor().clamp(0, analyzed.width - 1);
        final endX = (((col + 1) * cellWidth).ceil()).clamp(startX + 1, analyzed.width);
        final startY = (row * cellHeight).floor().clamp(0, analyzed.height - 1);
        final endY = (((row + 1) * cellHeight).ceil()).clamp(startY + 1, analyzed.height);

        double sumRed = 0;
        double sumGreen = 0;
        double sumBlue = 0;
        var count = 0;

        for (var y = startY; y < endY; y++) {
          for (var x = startX; x < endX; x++) {
            final pixel = analyzed.getPixel(x, y);
            sumRed += pixel.r;
            sumGreen += pixel.g;
            sumBlue += pixel.b;
            count++;
          }
        }

        if (count == 0) {
          continue;
        }

        final avgRed = sumRed / count;
        final avgGreen = sumGreen / count;
        final avgBlue = sumBlue / count;

        final luminance = ((0.299 * avgRed) + (0.587 * avgGreen) + (0.114 * avgBlue)) / 255.0;
        final darkness = (1.0 - luminance).clamp(0.0, 1.0);
        final maxChannel = math.max(avgRed, math.max(avgGreen, avgBlue));
        final minChannel = math.min(avgRed, math.min(avgGreen, avgBlue));
        final saturation = maxChannel <= 0 ? 0.0 : ((maxChannel - minChannel) / maxChannel).clamp(0.0, 1.0);

        final greenDominance = ((avgGreen - math.max(avgRed, avgBlue)) / 255.0).clamp(-1.0, 1.0);
        final brownDominance = (((avgRed * 0.70) + (avgBlue * 0.10)) - (avgGreen * 0.82)) / 255.0;
        final brownness = brownDominance.clamp(0.0, 1.0);
        final leafPresence = (((greenDominance + 1.0) * 0.30) + (brownness * 0.55) + (saturation * 0.15)).clamp(0.0, 1.0);

        brightnessMap[row][col] = luminance;

        // Brown/damaged pixels should dominate the score; healthy green zones should stay calm.
        var score = (brownness * 0.68) + (darkness * 0.18) + ((1.0 - saturation) * 0.14);

        // Penalize clearly healthy green tissue.
        if (greenDominance > 0.10 && brownness < 0.28) {
          score *= 0.15;
        }

        // Emphasize likely disease texture: dark, brown, and inside the leaf.
        if (brownness > 0.30 && darkness > 0.22) {
          score = math.min(1.0, score * 1.42 + 0.08);
        }

        // Gate out background noise.
        score *= leafPresence;

        heatmap[row][col] = score.clamp(0.0, 1.0);
      }
    }

    final smoothed = _smoothHeatmap(heatmap);
    return _focusHeatmap(smoothed, brightnessMap);
  }

  List<List<double>> _smoothHeatmap(List<List<double>> source) {
    if (source.isEmpty || source.first.isEmpty) {
      return source;
    }

    final rows = source.length;
    final cols = source.first.length;
    final result = List.generate(rows, (_) => List<double>.filled(cols, 0.0));

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        double sum = 0;
        var count = 0;

        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final ny = row + dy;
            final nx = col + dx;
            if (ny < 0 || ny >= rows || nx < 0 || nx >= cols) {
              continue;
            }
            sum += source[ny][nx];
            count++;
          }
        }

        final averaged = count == 0 ? source[row][col] : sum / count;
        result[row][col] = math.pow(averaged.clamp(0.0, 1.0), 0.85).toDouble();
      }
    }

    return result;
  }

  List<List<double>> _focusHeatmap(List<List<double>> source, List<List<double>> brightnessMap) {
    if (source.isEmpty || source.first.isEmpty) {
      return source;
    }

    final rows = source.length;
    final cols = source.first.length;
    final values = <double>[];

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        values.add(source[row][col]);
      }
    }

    final mean = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
    final variance = values.isEmpty
        ? 0.0
        : values.map((v) => math.pow(v - mean, 2).toDouble()).reduce((a, b) => a + b) / values.length;
    final std = math.sqrt(variance);
    final threshold = (mean + (std * 0.32)).clamp(0.08, 0.88);

    final focused = List.generate(rows, (_) => List<double>.filled(cols, 0.0));

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final v = source[row][col].clamp(0.0, 1.0);
        final brightness = brightnessMap[row][col].clamp(0.0, 1.0);
        var adjusted = v;

        if (v <= threshold) {
          adjusted = v * 0.28;
        } else {
          final emphasis = ((v - threshold) / (1.0 - threshold)).clamp(0.0, 1.0);
          adjusted = math.min(1.0, 0.18 + (emphasis * emphasis * 0.82));
        }

        // Very dark pixels get a stronger boost, healthy bright pixels are kept calm.
        if (brightness < 0.35) {
          adjusted = math.min(1.0, adjusted * 1.15 + 0.08);
        } else if (brightness > 0.58 && adjusted < 0.40) {
          adjusted *= 0.72;
        }

        focused[row][col] = adjusted.clamp(0.0, 1.0);
      }
    }

    return _smoothHeatmap(focused);
  }
}


