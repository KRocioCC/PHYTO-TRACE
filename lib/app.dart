import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/camera_screen.dart';
import 'screens/result_screen.dart';
import 'services/tflite_service.dart';
import 'themes/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TfliteService>(create: (_) {
          final service = TfliteService();
          service.loadModel(); // Inicializa al crear
          return service;
        }),
      ],
      child: MaterialApp(
        title: 'PHYTO-TRACE',
        theme: AppTheme.lightTheme(),
        initialRoute: '/',
        routes: {
          '/': (context) => const CameraScreen(),
          '/result': (context) => const ResultScreen(),
        },
      ),
    );
  }
}
