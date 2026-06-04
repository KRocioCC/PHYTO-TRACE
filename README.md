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

Requisitos (entorno de desarrollo)
----------------------------------
- Flutter (Ver `pubspec.yaml`:
	- `sdk: '>=3.1.5 <4.0.0'`)
- Android: `compileSdkVersion` >= 34, `minSdkVersion` >= 26 (ajustado para `tflite_flutter` y dependencias nativas).


Instalación y ejecución local
-----------------------------

```bash
git clone <repo-url>
cd phyto_trace

flutter pub get

flutter run
```

## Imagenes de la App

<p align="center">
  <img src="https://github.com/user-attachments/assets/184a38d4-255f-4d8e-80f7-4b1aecfce429" width="250" />
  <img src="https://github.com/user-attachments/assets/286b791b-e922-43db-8357-4b64f2924307" width="250" />
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/728eaa1a-9daa-48b4-925e-3731c05847a1" width="250" />
  <img src="https://github.com/user-attachments/assets/5e7946b7-6de8-4281-9afd-7c307538102b" width="250" />
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/53fb8fed-73fd-4a88-bdd1-74fbd20f479f" width="250" />
  <img src="https://github.com/user-attachments/assets/26c36a8a-3051-4196-8897-55dc2fb57e49" width="250" />

	

</p>





