import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../themes/app_theme.dart';
import '../services/tflite_service.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int _selectedDay = 3; // Default to 3 days

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final imagePath = args?['imagePath'] as String? ?? '';
    final label = args?['label'] as String? ?? 'Enfermedad Detectada';
    final confidence = args?['confidence'] as double? ?? 0.87;
    final diagnostico = args?['diagnostico'] as String? ?? 'Análisis en progreso';
    final accion = args?['accion'] as String? ?? 'Revisar con especialista';
    final urgencia = args?['urgencia'] as String? ?? 'MEDIA';
    final topPredictions = (args?['topPredictions'] as List<dynamic>? ?? const [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
    final tecnicasNucleares = (args?['tecnicasNucleares'] as List<dynamic>? ?? const [])
      .map((item) => item.toString())
      .toList();
    final recomendacionesTecnologicas = (args?['recomendacionesTecnologicas'] as List<dynamic>? ?? const [])
      .map((item) => item.toString())
      .toList();
    // final imagenRecomendacion = args?['imagenRecomendacion'] as String?; (removed - images not displayed)

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado del Análisis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with Heatmap Overlay
              _buildImageWithHeatmap(imagePath),

              const SizedBox(height: 20),

              // Disease Prediction Card
              _buildPredictionCard(label, confidence),

              const SizedBox(height: 20),

              // Temporal Prediction Section
              _buildTemporalPrediction(label, confidence, urgencia),

              const SizedBox(height: 20),

              // Crop Loss Indicator
              _buildCropLossIndicator(label, confidence, urgencia),

              const SizedBox(height: 20),

              const SizedBox(height: 20),

              // Nuclear Recommendation Card
              _buildNuclearRecommendation(label, diagnostico, accion, urgencia),

              const SizedBox(height: 12),
              // Technological Recommendations (if available)
              if (recomendacionesTecnologicas.isNotEmpty)
                _buildTecnologicalRecommendations(recomendacionesTecnologicas),

              const SizedBox(height: 12),
              // Nuclear techniques suggestions
              _buildNuclearTechniques(label, urgencia),

              const SizedBox(height: 20),

              _buildTopPredictions(topPredictions),

              const SizedBox(height: 20),

              // Action Buttons
              _buildActionButtons(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.primary,
        selectedItemColor: AppTheme.secondary,
        unselectedItemColor: Colors.white70,
        onTap: (index) => _onNavTap(context, index, label, diagnostico, accion, urgencia),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.camera), label: 'Diagnóstico'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: 'Tratamiento'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  void _onNavTap(BuildContext context, int index, String label, String diagnostico, String accion, String urgencia) {
    switch (index) {
      case 0: // Diagnóstico -> scroll to top / show summary
        showModalBottomSheet(
          context: context,
          builder: (_) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resumen del Diagnóstico', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Diagnóstico: $diagnostico'),
                const SizedBox(height: 6),
                Text('Acción recomendada: $accion'),
                const SizedBox(height: 6),
                Text('Urgencia: $urgencia'),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
        break;
      case 1: // Tratamiento -> show suggested treatments and techniques
        showModalBottomSheet(
          context: context,
          builder: (_) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tratamientos sugeridos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(accion),
                const SizedBox(height: 12),
                Text('Técnicas nucleares relacionadas', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...Provider.of<TfliteService>(context, listen: false).getNuclearTechniquesFor(label, urgencia).map((t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('• $t'),
                    )),
              ],
            ),
          ),
        );
        break;
      case 2: // Historial -> placeholder
        showModalBottomSheet(
          context: context,
          builder: (_) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historial', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('No hay entradas en el historial local. Realiza más análisis para poblar el historial.'),
              ],
            ),
          ),
        );
        break;
      case 3: // Perfil -> about
        showModalBottomSheet(
          context: context,
          builder: (_) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Perfil', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('PHYTO-TRACE v1.0 - Herramienta de apoyo. Consulte con especialistas para intervenciones.'),
              ],
            ),
          ),
        );
        break;
    }
  }

  Widget _buildImageWithHeatmap(String imagePath) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.file(
              File(imagePath),
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            // Heatmap overlay (red tint for disease)
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    Colors.red.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Badge showing status
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.alert,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Activa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionCard(String label, double confidence) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: AppTheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                    ),
                    Text(
                      '${(confidence * 100).toStringAsFixed(0)}% de confianza',
                      style: TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: confidence,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                confidence > 0.8 ? AppTheme.alert : AppTheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemporalPrediction(String label, double confidence, String urgencia) {
    final tflite = Provider.of<TfliteService>(context, listen: false);
    final pred = tflite.getTemporalPrediction(label, confidence, _selectedDay, urgencia);
    final minArea = pred['area_min'] as double? ?? 0.0;
    final maxArea = pred['area_max'] as double? ?? 0.0;

    String formatArea(double v) {
      if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} km²';
      if (v >= 1) return '${v.toStringAsFixed(1)} m²';
      return '${(v * 10000).toStringAsFixed(1)} cm²';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: AppTheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Predicción Temporal',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimelineDay(3, '3 días'),
              _buildTimelineDay(7, '7 días'),
              _buildTimelineDay(14, '14 días'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Área afectada estimada en $_selectedDay días: ${formatArea(minArea)} - ${formatArea(maxArea)}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDay(int day, String label) {
    final isSelected = _selectedDay == day;
    return GestureDetector(
      onTap: () => setState(() => _selectedDay = day),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppTheme.primary : Colors.grey.shade200,
              border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.textLight,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropLossIndicator(String label, double confidence, String urgencia) {
    final tflite = Provider.of<TfliteService>(context, listen: false);
    final isHealthy = label.toLowerCase() == 'healthy';
    
    // Override values for healthy plants
    final finalUrgencia = isHealthy ? 'BAJA' : urgencia;
    final pred = isHealthy 
      ? {'loss_percent': 0.0, 'days': _selectedDay, 'area_min': 0.0, 'area_max': 0.0}
      : tflite.getTemporalPrediction(label, confidence, _selectedDay, urgencia);
    
    final lossPercent = (pred['loss_percent'] as double? ?? 0.0) / 100.0;
    final displayPercent = ((lossPercent * 100)).clamp(0.0, 100.0).toStringAsFixed(0);
    final urgencyText = finalUrgencia.toUpperCase();
    
    // Choose color based on urgency
    final indicatorColor = urgencyText == 'ALTA'
        ? AppTheme.alert
        : urgencyText == 'MEDIA'
            ? AppTheme.secondary
            : Colors.green.shade600;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: indicatorColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_down, color: indicatorColor, size: 24),
              const SizedBox(width: 8),
              Text(
                'Pérdida de Cosecha Estimada',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: indicatorColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                displayPercent + '%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: indicatorColor,
                    ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: lossPercent.clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            urgencyText == 'ALTA' ? 'ALTA - Intervenir en 24h' : urgencyText == 'MEDIA' ? 'MEDIA - Monitorizar' : 'BAJA - Seguimiento rutinario',
            style: TextStyle(
              fontSize: 12,
              color: indicatorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNuclearRecommendation(String label, String diagnostico, String accion, String urgencia) {
    final isHealthy = label.toLowerCase() == 'healthy';
    final title = isHealthy ? 'Cultivo Saludable' : 'Recomendación de Acción';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgencia == 'ALTA'
              ? AppTheme.alert
              : urgencia == 'MEDIA'
                  ? AppTheme.secondary
                  : AppTheme.primary,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                urgencia == 'BAJA' ? Icons.check_circle : Icons.warning,
                color: urgencia == 'ALTA'
                    ? AppTheme.alert
                    : urgencia == 'MEDIA'
                        ? AppTheme.secondary
                        : AppTheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  diagnostico,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  accion,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Urgencia: $urgencia',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: urgencia == 'ALTA'
                        ? AppTheme.alert
                        : urgencia == 'MEDIA'
                            ? AppTheme.secondary
                            : AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNuclearTechniques(String label, String urgencia) {
    final tflite = Provider.of<TfliteService>(context, listen: false);
    final techniques = tflite.getNuclearTechniquesFor(label, urgencia);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science, color: AppTheme.primary, size: 22),
              const SizedBox(width: 8),
              Text('Técnicas sugeridas', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ...techniques.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right, size: 18, color: Colors.black54),
                    const SizedBox(width: 6),
                    Expanded(child: Text(t)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.photo_camera),
          label: const Text('Nueva Foto'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondary,
            foregroundColor: Colors.black,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
            final imagePath = args?['imagePath'] as String? ?? '';
            final label = args?['label'] as String? ?? '';
            final confidence = args?['confidence'] as double? ?? 0.0;

            final summary = 'Resultado: $label\nConfianza: ${(confidence * 100).toStringAsFixed(1)}%';
            try {
              if (imagePath.isNotEmpty) {
                await Share.shareXFiles([XFile(imagePath)], text: summary);
              } else {
                await Share.share(summary);
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al compartir: $e')));
            }
          },
          icon: const Icon(Icons.share),
          label: const Text('Compartir'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTopPredictions(List<Map<String, dynamic>> topPredictions) {
    if (topPredictions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppTheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Resultados del Modelo',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...topPredictions.take(4).map((item) {
            final label = item['label']?.toString() ?? 'Clase';
            final score = (item['score'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('${(score * 100).toStringAsFixed(2)}%'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: score.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Recommendation images removed per user request

  Widget _buildTecnologicalRecommendations(List<String> recommendations) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build, color: Colors.blue.shade700, size: 22),
              const SizedBox(width: 8),
              Text('Recomendaciones Tecnológicas', 
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recommendations.map((rec) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(rec, style: const TextStyle(fontSize: 13))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
