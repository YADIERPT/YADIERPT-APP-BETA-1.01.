# ==============================================================================
# Reglas de Ofuscación y Protección ProGuard / R8 para Planteapp
# ==============================================================================

# 1. Protección del Runtime de Flutter y Enlaces de Canales Nativos
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 2. SQLite y Motor Criptográfico SQLCipher (AES-256)
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-keep class net.sqlcipher.database.SQLiteDatabase { *; }
-keep class net.sqlcipher.database.SQLiteOpenHelper { *; }
-dontwarn net.sqlcipher.**

# 3. Almacenamiento Seguro de Llaves (flutter_secure_storage)
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# 4. Servicios Criptográficos de Java y Extensiones (JCE)
-keep class javax.crypto.** { *; }
-dontwarn javax.crypto.**

# 5. Soporte Biométrico y Lectores de Hardware (local_auth)
-keep class io.flutter.plugins.localauth.** { *; }

# 6. Cámara y Procesamiento de Imágenes
-keep class io.flutter.plugins.camera.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }

# 7. Supresión de advertencias para componentes opcionales de Google Play Store (App 100% offline)
-dontwarn com.google.android.play.core.**
