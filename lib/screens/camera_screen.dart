import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/tflite_service.dart';
import '../themes/app_theme.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _image;
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked != null) {
        setState(() {
          _image = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  void _analyze() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a photo')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Llamar a servicio para obtener predicción real
      final tfliteService = Provider.of<TfliteService>(context, listen: false);
      final prediction = await tfliteService.predictFromFile(_image!);

      setState(() => _isProcessing = false);

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/result',
          arguments: {
            'imagePath': _image!.path,
            'label': prediction.label,
            'confidence': prediction.confidence,
            'diagnostico': prediction.diagnostico,
            'accion': prediction.accion,
            'urgencia': prediction.urgencia,
            'topPredictions': prediction.topPredictions,
            'diseaseType': prediction.urgencia == 'BAJA' ? 'healthy' : 'localized',
            'tecnicasNucleares': prediction.tecnicasNucleares ?? [],
            'recomendacionesTecnologicas': prediction.recomendacionesTecnologicas ?? [],
            'imagenRecomendacion': prediction.imagenRecomendacion,
          },
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PHYTO-TRACE'),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.agriculture, color: AppTheme.primary, size: 28),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (BuildContext ctx) {
                  final tflite = Provider.of<TfliteService>(context, listen: false);
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Menu', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          ListTile(
                            leading: const Icon(Icons.book),
                            title: const Text('Quick Guide'),
                            onTap: () {
                              Navigator.pop(ctx);
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Quick Guide'),
                                  content: const Text('1) Take a photo\n2) Press Analyze\n3) Review recommendations and contact a specialist if needed'),
                                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.info),
                            title: const Text('Model Information'),
                            onTap: () async {
                              Navigator.pop(ctx);
                              try {
                                final labelsCount = tflite.getLabelsCount();
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Model'),
                                    content: Text('Model: phyto_trace_corn.tflite\nLabels loaded: $labelsCount'),
                                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                                  ),
                                );
                              } catch (e) {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Modelo'),
                                    content: Text('No se pudo cargar información del modelo: $e'),
                                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
                                  ),
                                );
                              }
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.email),
                            title: const Text('Contactar Experto'),
                            onTap: () {
                              Navigator.pop(ctx);
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Contactar'),
                                  content: const Text('Envíe los resultados a su especialista local o use los canales institucionales.'),
                                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: AppTheme.primary),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Main CTA Button
              GestureDetector(
                onTap: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_camera,
                        size: 64,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tomar Foto',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Captura una foto de la hoja',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Image Preview Section
              if (_image != null)
                Column(
                  children: [
                    Text(
                      'Vista Previa',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primary, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _image!,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.image),
                          label: const Text('Galería'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondary,
                            foregroundColor: Colors.black,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _image = null),
                          icon: const Icon(Icons.clear),
                          label: const Text('Borrar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.alert,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              // Heatmap Placeholder Section
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      'Damage Heatmap',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primary.withOpacity(0.1),
                            AppTheme.secondary.withOpacity(0.1),
                            AppTheme.alert.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _image != null ? 'Processing...' : 'Upload a photo to see the map',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Analyze Button
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _analyze,
                  icon: _isProcessing ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ) : const Icon(Icons.analytics),
                  label: Text(_isProcessing ? 'Analyzing...' : 'Analyze'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
