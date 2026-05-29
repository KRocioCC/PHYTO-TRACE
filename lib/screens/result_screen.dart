import 'dart:io';
import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../themes/app_theme.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int _selectedDay = 3;

  @override
  Widget build(BuildContext context) {
    final args =
    ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    final imagePath = args?['imagePath'] as String? ?? '';
    final prediction = args?['prediction'] as Prediction?;

    final label = prediction?.label ?? 'Sin diagnóstico';
    final confidence = prediction?.confidence ?? 0.0;
    final reco = prediction?.recommendation as Map<String, dynamic>?;

    // ¿Es planta sana?
    final isHealthy = label.toLowerCase().contains('healthy');

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
              _buildImageWithHeatmap(imagePath, isHealthy),
              const SizedBox(height: 20),
              _buildPredictionCard(label, confidence, isHealthy),
              const SizedBox(height: 20),
              if (!isHealthy) ...[
                _buildTemporalPrediction(),
                const SizedBox(height: 20),
                _buildCropLossIndicator(confidence),
                const SizedBox(height: 20),
                if (reco != null) _buildRecommendationCard(reco),
                if (reco == null) _buildNoRecoCard(),
                const SizedBox(height: 20),
              ] else
                _buildHealthyCard(),
              const SizedBox(height: 20),
              _buildActionButtons(context),
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
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.camera), label: 'Diagnóstico'),
          BottomNavigationBarItem(
              icon: Icon(Icons.medical_services), label: 'Tratamiento'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: 'Historial'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildImageWithHeatmap(String imagePath, bool isHealthy) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.file(File(imagePath),
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 300,
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.broken_image, size: 60)),
                )),
            // Overlay de color según estado
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    (isHealthy ? Colors.green : Colors.red).withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isHealthy ? Colors.green : AppTheme.alert,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isHealthy ? Icons.check_circle : Icons.warning,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      isHealthy ? 'Sana' : 'Activa',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
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

  Widget _buildPredictionCard(
      String label, double confidence, bool isHealthy) {
    final color = isHealthy ? Colors.green : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08), blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  isHealthy ? Icons.eco : Icons.bug_report,
                  color: color,
                  size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      '${(confidence * 100).toStringAsFixed(1)}% de confianza',
                      style: TextStyle(color: AppTheme.textLight, fontSize: 12),
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
                  confidence > 0.8 ? AppTheme.alert : AppTheme.secondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemporalPrediction() {
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
          Row(children: [
            Icon(Icons.schedule, color: AppTheme.primary, size: 24),
            const SizedBox(width: 8),
            Text('Predicción Temporal',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [3, 7, 14]
                .map((day) => _buildTimelineDay(day, '$day días'))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Área afectada estimada en $_selectedDay días: ${_selectedDay == 3 ? '15-25' : _selectedDay == 7 ? '30-50' : '60-80'} m²',
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
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppTheme.primary : Colors.grey.shade200,
          border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              width: 2),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textLight,
                fontSize: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildCropLossIndicator(double confidence) {
    // Estimación simple basada en confianza del modelo
    final lossPercent = (confidence * 55).clamp(10.0, 80.0);
    final lossDisplay = lossPercent.toStringAsFixed(0);
    final severity = lossPercent > 60
        ? '🔴 CRÍTICA'
        : lossPercent > 40
        ? '⚠️ ALTA'
        : '🟡 MODERADA';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.alert.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.alert.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.trending_down, color: AppTheme.alert, size: 24),
            const SizedBox(width: 8),
            Text('Pérdida de Cosecha Estimada',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.alert)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Text('$lossDisplay%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.alert)),
            const SizedBox(width: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: lossPercent / 100,
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.alert),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text('$severity - Intervenir pronto',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.alert,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> reco) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.medical_services, color: AppTheme.primary, size: 24),
            const SizedBox(width: 8),
            Text('Recomendaciones',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ]),
          const SizedBox(height: 12),
          // Renderiza dinámicamente todas las claves del JSON
          ...reco.entries.map((entry) => _buildRecoSection(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildRecoSection(String key, dynamic value) {
    // Formatea la clave (snake_case → Title Case)
    final title = key
        .split('_')
        .map((w) => w.isNotEmpty
        ? '${w[0].toUpperCase()}${w.substring(1)}'
        : '')
        .join(' ');

    String content;
    if (value is List) {
      content = value.map((e) => '• $e').join('\n');
    } else {
      content = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Text(content,
                style: const TextStyle(fontSize: 12, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRecoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No se encontró recomendación específica para esta enfermedad. Consulta a un agrónomo.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¡Planta Saludable!',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green)),
                const SizedBox(height: 4),
                Text(
                  'No se detectaron enfermedades. Continúa con las buenas prácticas agrícolas.',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.photo_camera),
          label: const Text('Nueva Foto'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.black),
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.share),
          label: const Text('Compartir'),
          style:
          ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
        ),
      ],
    );
  }
}