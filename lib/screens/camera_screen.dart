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
  String _selectedCrop = 'apple'; // cultivo seleccionado
  final ImagePicker _picker = ImagePicker();

  static const Map<String, String> _cropLabels = {
    'apple': 'Manzana 🍎',
    'potato': 'Papa 🥔',
    'tomato': 'Tomate 🍅',
  };

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked != null) {
        setState(() => _image = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _analyze() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una foto')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final service = context.read<TfliteService>();
      final prediction = await service.predictFromFile(_image!, _selectedCrop);

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/result',
          arguments: {
            'imagePath': _image!.path,
            'prediction': prediction,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al analizar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.agriculture, color: AppTheme.primary, size: 28),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Selector de cultivo ──────────────────────────────
              Text(
                'Selecciona el cultivo',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: _cropLabels.entries.map((entry) {
                  final isSelected = _selectedCrop == entry.key;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCrop = entry.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                              : [],
                        ),
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color:
                            isSelected ? Colors.white : AppTheme.textLight,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // ── Botón principal cámara ───────────────────────────
              GestureDetector(
                onTap:
                _isProcessing ? null : () => _pickImage(ImageSource.camera),
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
                      const Icon(Icons.photo_camera,
                          size: 64, color: Colors.white),
                      const SizedBox(height: 12),
                      Text(
                        'Tomar Foto',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cultivo: ${_cropLabels[_selectedCrop]}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Vista previa ─────────────────────────────────────
              if (_image != null) ...[
                Text(
                  'Vista Previa',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
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
                      onPressed: _isProcessing
                          ? null
                          : () => _pickImage(ImageSource.gallery),
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
                          backgroundColor: AppTheme.alert),
                    ),
                  ],
                ),
              ],

              // ── Botón analizar ───────────────────────────────────
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _analyze,
                  icon: _isProcessing
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(Icons.analytics),
                  label: Text(_isProcessing ? 'Analizando...' : 'Analizar'),
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