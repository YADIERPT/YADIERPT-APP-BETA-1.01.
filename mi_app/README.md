# Planteapp (Biznaga Kíix) - Flutter App 🌱

Aplicación móvil oficial de **Planteapp** para el vivero botánico **Biznaga Kíix**, desarrollada en **Flutter** con arquitectura **100% Offline-First** y respaldo multi-dispositivo en **Supabase**.

---

## 🌿 Características Destacadas

- **Punto de Venta (POS):** Escaneo de código de barras por cámara o lector USB/BT, carrito reactivo, desglose de impuestos y pagos en efectivo, tarjeta o transferencia.
- **Inventario Botánico con Movimientos Append-Only:** Control atómico de existencias en `movimientos_inventario` para evitar inconsistencias y sobreescrituras en terminales concurrentes.
- **Cuentas por Cobrar (Deudores):** Registro de ventas a crédito, control de clientes y seguimiento de abonos.
- **Cifrado de Alta Seguridad:** Base de datos local cifrada en reposo mediante **SQLCipher AES-256** con llave maestra protegida en Android Keystore / iOS Keychain (`flutter_secure_storage`).
- **Autenticación y Roles Estrictos (RBAC):** Hash PBKDF2-HMAC-SHA256 local y sincronización con Supabase Auth bajo dos únicos roles: **Dueño** y **Empleado**.
- **Sincronización Inteligente en la Nube:** Motor propio con cola *Outbox*, *Pull Incremental* por cursor temporal y avisos reactivos con *Supabase Realtime*.
- **Modo Local Puro:** Si no se configuran llaves de Supabase, la app opera sin restricciones de forma 100% offline.
- **Imágenes Optimizadas:** Compresión WebP en cliente (1000px y 300px), almacenamiento en Supabase Storage y visualización instantánea a 60 FPS desde caché local en disco.
- **Tickets e Impresión:** Generación de recibos PDF e impresión térmica por Bluetooth (ESC/POS).

---

## 🛠 Requisitos Previos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión 3.24.0 o superior).
- Android Studio o VS Code con extensiones Flutter y Dart.
- Dispositivo Android (API 26+) / iOS (13+) físico o emulador.

---

## 🚀 Comandos de Instalación y Ejecución

### 1. Descargar dependencias
```bash
flutter pub get
```

### 2. Ejecutar la aplicación

#### Modo Local Puro (Offline autónomo)
```bash
flutter run
```

#### Con Sincronización Remota (Supabase)
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=tu-anon-key-publica
```

### 3. Ejecutar la Suite de Pruebas
El proyecto cuenta con una cobertura de 163 pruebas unitarias y de widgets:
```bash
flutter test
```

### 4. Compilación para Producción (Release)

#### APK para Android
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=tu-anon-key-publica
```
*Binario generado en:* `build/app/outputs/flutter-apk/app-release.apk`

#### App Bundle para Google Play (AAB)
```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=tu-anon-key-publica
```

---

## 📁 Estructura del Código Fuente (`lib/`)

```text
lib/
├── main.dart                             # Punto de entrada, configuración de servicios y MultiProvider
├── controladores/                        # Gestores de estado (MVVM)
│   ├── controlador_autenticacion.dart    # Login, sesiones y roles
│   ├── controlador_inventario.dart       # Catálogo, lotes y existencias
│   ├── controlador_ventas.dart           # POS, carrito y cobranza
│   ├── controlador_sincronizacion.dart   # Orquestador del estado de sincronización
│   └── controlador_ia_compras.dart       # Motor de recomendaciones en Isolate
├── modelos/                              # Entidades del dominio y mapeo JSON/SQLite
├── servicios/                            # Infraestructura de bajo nivel
│   ├── base_datos.dart                   # SQLite v15 cifrado con SQLCipher
│   ├── servicio_supabase.dart            # Cliente Supabase seguro y fallback local
│   ├── servicio_sincronizacion.dart      # Motor Push/Pull incremental
│   ├── servicio_realtime.dart            # Suscripción a avisos en vivo
│   ├── servicio_autenticacion_supabase.dart # Sesión remota silenciosa
│   ├── servicio_almacenamiento_imagenes.dart # Compresión WebP, caché y Storage
│   └── secure_storage_service.dart       # Acceso a Keystore / Keychain
└── vistas/                               # Pantallas y componentes UI
    ├── inicio_vista.dart                 # Shell principal con navegación
    ├── pos_vista.dart                    # Caja de cobro y lector
    ├── inventario_vista.dart             # Gestión de productos y stock
    ├── deudores_vista.dart               # Cuentas por cobrar y abonos
    ├── sincronizacion_vista.dart         # Panel de respaldo y cola outbox
    └── widgets/                          # Componentes reutilizables (IndicadorSincronizacion, ImagenProductoWidget)
```

---

## 📑 Documentación Adicional
Para detalles exhaustivos de arquitectura, auditorías y guías de validación, consulta la carpeta `../docs/`:
- [Contexto General de Arquitectura](../docs/contexto_general_planteapp.md)
- [Informe Final de Integración Supabase](../docs/informe_integracion_supabase.md)
- [Guía de Pruebas Manuales](../docs/guia_pruebas_manuales_fase7.md)
