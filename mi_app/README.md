# Vivero POS (Punto de Venta) 🌿

Una aplicación móvil desarrollada en **Flutter** para la gestión de ventas, inventario y finanzas de un vivero botánico. 

##  Requisitos Previos

Antes de ejecutar este proyecto, asegúrate de tener instalado:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Recomendado versión estable más reciente)
- Android Studio o VS Code con las extensiones de Flutter y Dart.
- Un dispositivo Android/iOS físico conectado o un emulador en ejecución.

## 🛠Comandos de Instalación y Ejecución

Sigue estos pasos en tu terminal para poner en marcha el proyecto:

### 1. Descargar dependencias
Este comando descargará todos los paquetes necesarios (como `mobile_scanner`, `printing`, `pdf`, etc.) definidos en el archivo `pubspec.yaml`.
```bash
flutter pub get
```

### 2. Ejecutar la aplicación
Conecta tu celular o inicia un emulador y ejecuta:
```bash
flutter run
```
*Si tienes múltiples dispositivos conectados, Flutter te pedirá que elijas uno. Puedes especificarlo directamente con `flutter run -d <device_id>`.*

### 3. Analizar el código (Opcional)
Para comprobar que no haya errores de sintaxis o advertencias en el código:
```bash
flutter analyze
```

## Compilación para Producción (Build)

Cuando estés listo para generar los instalables de la aplicación para distribuirlos:

### Generar APK para Android
Esto creará un archivo instalable `.apk` que puedes compartir e instalar en dispositivos Android.
```bash
flutter build apk --release
```
*El archivo generado estará ubicado en: `build/app/outputs/flutter-apk/app-release.apk`*

### Generar App Bundle para Google Play (AAB)
Si planeas subir la app a la Google Play Store, utiliza este comando:
```bash
flutter build appbundle --release
```

## Funcionalidades Principales
* **Punto de Venta (POS):** Escáner de código de barras para búsqueda rápida, gestión del carrito y procesamiento de pagos (efectivo, tarjeta, transferencia).
* **Inventario:** Control de stock, creación de nuevos lotes, alertas de escasez y catálogo fotográfico.
* **Tickets:** Generación e impresión de tickets de venta en formato PDF compatibles con impresoras térmicas.
* **Finanzas y Reportes:** Gráficos de ingresos, ticket promedio y un historial detallado de las transacciones diarias.

## Diseños y Mockups
El proyecto incluye un directorio llamado `MOCKUPS/` donde se encuentran los archivos SVG de alta fidelidad que sirven de referencia visual del diseño UI/UX (ideales para importar a Figma).
