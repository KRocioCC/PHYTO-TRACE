PHYTO-TRACE
===========

Resumen
-------
PHYTO-TRACE es una aplicación móvil (Flutter) para diagnóstico rápido de problemas foliares del maíz a partir de fotografías. La app ejecuta un modelo TensorFlow Lite en el dispositivo para clasificar la imagen y presenta:

- Etiqueta de diagnóstico (ej. `Common rust`, `healthy`, etc.) y probabilidades.
- Recomendaciones agronómicas y tecnológicas mapeadas desde `assets/data/corn_recommendations.json`.
- Sugerencias conceptuales de "técnicas nucleares" (solo informativas/educativas).
- Predicción temporal heurística (3 / 7 / 14 días) con estimación de área afectada y pérdida de cosecha (visualización heurística, no determinística).
- Capacidad para compartir resultados desde el dispositivo.

Importante: la aplicación NO utiliza ni controla materiales radiactivos ni instruye sobre su uso. Las menciones de técnicas isotópicas son meramente informativas y requieren instalaciones, permisos y personal especializado para cualquier ejecución real.

Contenido del repositorio
-------------------------
- `lib/` : código fuente Flutter (pantallas, servicios, modelos).
	- `lib/services/tflite_service.dart` : carga y ejecución del modelo TFLite, lectura de recomendaciones y heurísticas de predicción temporal.
	- `lib/screens/camera_screen.dart` : captura/selección de imagen y envío a inferencia.
	- `lib/screens/result_screen.dart` : visualización del resultado, recomendaciones y métricas.
	- `lib/models/prediction.dart` : DTO para resultados de predicción.
- `assets/models/phyto_trace_corn.tflite` : modelo TFLite utilizado para inferencia (convertido desde Keras/HDF5 en `tools/`).
- `assets/data/corn_recommendations.json` : recomendaciones y textos por etiqueta.
- `assets/data/corn_labels.txt` : etiquetas usadas por el modelo.
- `assets/images/` : carpeta para imágenes referenciales (opcional).
- `tools/convert_to_tflite.py` : scripts y utilidades usados para convertir `.h5` a `.tflite` (experimentos realizados durante desarrollo).

Requisitos (entorno de desarrollo)
----------------------------------
- Flutter (versión usada en el repo, por ejemplo Flutter 3.x / Dart 3.x). Ver `pubspec.yaml`:
	- `sdk: '>=3.1.5 <4.0.0'`
- Android: `compileSdkVersion` >= 34, `minSdkVersion` >= 26 (ajustado para `tflite_flutter` y dependencias nativas).
- Dependencias principales (declaradas en `pubspec.yaml`):
	- `tflite_flutter` (para inferencia TFLite)
	- `image`, `image_picker`, `provider`, `share_plus`

Instalación y ejecución local
-----------------------------
1. Clona el repositorio y muévete al directorio del proyecto:

```bash
git clone <repo-url>
cd phyto_trace
```

2. Instala dependencias Flutter:

```bash
flutter pub get
```

3. Ejecuta en un dispositivo/emulador conectado:

```bash
flutter run
```

4. Para generar un APK de prueba:

```bash
flutter build apk --debug
# o para release (firmar con keystore apropiada):
flutter build apk --release
```

Dónde está el APK:
- `build/app/outputs/flutter-apk/app-debug.apk` (o `app-release.apk` para release).

Notas sobre el modelo TFLite
---------------------------
- El proyecto incluye `tools/convert_to_tflite.py` que contiene las rutinas usadas para intentar convertir el `.h5` original a `.tflite`. Durante el desarrollo se probó con varias versiones de TensorFlow (por compatibilidad de op-versions en el runtime Android).
- Si cambias o actualizas el modelo, recuerda:
	- Mantener una versión de `tflite_flutter` y `minSdkVersion` compatibles.
	- Si ves errores en el dispositivo como "Didn't find op for builtin opcode 'CONV_2D' version 'X'", conviene reexportar el modelo con una versión de TF que produzca op-versions compatibles con la librería TFLite embebida.

Estructura de datos / cómo editar recomendaciones
-----------------------------------------------
- `assets/data/corn_recommendations.json` contiene un objeto por etiqueta con campos:
	- `diagnostico`, `accion`, `urgencia`, `tecnicas_nucleares` (lista), `recomendaciones_tecnologicas` (lista) y `imagen` (ruta, opcional).
- Edita este JSON para ajustar textos, agregar nuevas enfermedades o cambiar recomendaciones sin tocar código.

Simulaciones isotópicas (educativas)
------------------------------------
- La app puede mostrar visualizaciones heurísticas (simulaciones educativas) que representan una "concentración" ficticia de trazador en un mapa de calor superpuesto. Estas simulaciones son puramente visuales y NO implican uso de materiales radiactivos.
- Cualquier uso real de técnicas isotópicas requiere permisos, instalaciones y personal habilitado.

Seguridad, legal y ética
------------------------
- Las recomendaciones mostradas son orientativas. No sustituir pruebas de laboratorio ni el consejo de especialistas.
- Las menciones de técnicas nucleares son informativas. No seguir ninguna instrucción para manipular material radioactivo desde esta app.
- Incluye un aviso/disclaimer visible en la app: "Contenido informativo; consulte especialistas y normativa local antes de realizar muestreos o intervenciones."

Resolución de problemas comunes
-------------------------------
- Error de instalación en dispositivo (conflicto de paquete): pedir al usuario que desinstale versiones previas con firmas distintas o usar `adb uninstall <package>` y volver a instalar.
- Errores de runtime TFLite relacionados con op versions: reexportar/converter el `.tflite` usando una versión de TF compatible con el runtime del plugin.
- Si las predicciones son constantes: verificar que el `.tflite` generado contenga pesos (no sea un modelo vacío) y que la preprocesamiento de la imagen coincida con el que se usó en entrenamiento (normalización, tamaño).

Siguiente pasos recomendados
----------------------------
- Validación en campo: recolectar imágenes etiquetadas en condiciones reales y comparar con diagnósticos de referencia (laboratorio/agronomo).
- Calibrar heurísticas: usar datos reales para ajustar los parámetros de estimación temporal y pérdida de cosecha.
- Historial y telemetría: añadir `sqflite` o backend para almacenar diagnósticos y mejorar modelos vía reentrenamiento.
- Interfaz y UX: mejorar el flujo de compartir, exportar resultados, y agregar consentimientos/aviso legal.

Contribuir
----------
- Cualquier PR o issue es bienvenido. Si vas a añadir nuevas etiquetas o recomendaciones, actualiza `assets/data/corn_recommendations.json` y `assets/data/corn_labels.txt` (mantén el orden si el modelo espera indexado específico).

Contacto
--------
- El repositorio pertenece a `KRocioCC` (rama `rocio` en este workspace). Para preguntas detalladas sobre conversión de modelos o despliegue, contacta al mantenedor del repositorio.

Licencia
--------
- Este repositorio no incluye una licencia explícita por defecto. Añade la licencia apropiada antes de usar en producción si corresponde.


Disclaimer final
----------------
PHYTO-TRACE es una herramienta de apoyo. Las indicaciones sobre técnicas isotópicas son informativas y no constituyen instrucciones ni autorización para el uso de material radioactivo. Cumpla la normativa y consulte especialistas certificados para procedimientos que impliquen riesgos.

