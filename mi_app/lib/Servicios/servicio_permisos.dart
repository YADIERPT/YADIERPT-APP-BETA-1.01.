import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servicio centralizado para la gestión y solicitud de permisos en tiempo de ejecución.
/// Garantiza que la cámara, galería, biometría y conexiones de hardware soliciten
/// la autorización correspondiente antes de ser utilizadas.
class ServicioPermisos {
  ServicioPermisos._();
  static final ServicioPermisos instancia = ServicioPermisos._();

  /// Solicita el permiso de la cámara al usuario antes de abrir el visor.
  /// Si el permiso ya está concedido, retorna true directamente.
  /// Si es denegado de forma permanente, ofrece un diálogo para ir a Ajustes.
  Future<bool> solicitarPermisoCamara({BuildContext? context}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true; // En desktop no aplica el sistema de permisos en tiempo de ejecución
    }

    PermissionStatus estado = await Permission.camera.status;

    if (estado.isGranted || estado.isLimited) {
      return true;
    }

    // Solicita al sistema operativo que muestre el diálogo de permiso nativo
    estado = await Permission.camera.request();

    if (estado.isGranted || estado.isLimited) {
      return true;
    }

    if (context != null && context.mounted) {
      _mostrarDialogoExplicativo(
        context: context,
        titulo: 'Permiso de Cámara Requerido',
        mensaje:
            'Para tomar fotos de tus plantas y artículos directamente desde el dispositivo, es necesario otorgar permiso de cámara.',
        esPermanente: estado.isPermanentlyDenied,
      );
    }

    return false;
  }

  /// Solicita el permiso para acceder a fotos y galería.
  Future<bool> solicitarPermisoGaleria({BuildContext? context}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    // En Android 13+ (API 33+) se usa photos; en versiones anteriores storage
    Permission permission = Permission.photos;
    PermissionStatus estado = await permission.status;

    if (estado.isGranted || estado.isLimited) {
      return true;
    }

    estado = await permission.request();

    if (!estado.isGranted && !estado.isLimited) {
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted || storageStatus.isLimited) {
        return true;
      }
    } else {
      return true;
    }

    if (context != null && context.mounted) {
      _mostrarDialogoExplicativo(
        context: context,
        titulo: 'Permiso de Galería Requerido',
        mensaje:
            'Para seleccionar imágenes de tus productos guardadas en el dispositivo, concede acceso al almacenamiento de fotos.',
        esPermanente: estado.isPermanentlyDenied,
      );
    }

    return false;
  }

  /// Solicita permisos de Bluetooth para escaneo y conexión con lectores externos.
  Future<bool> solicitarPermisosBluetooth({BuildContext? context}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    final scanStatus = await Permission.bluetoothScan.request();
    final connectStatus = await Permission.bluetoothConnect.request();

    final exito = (scanStatus.isGranted || scanStatus.isLimited) &&
        (connectStatus.isGranted || connectStatus.isLimited);

    if (!exito && context != null && context.mounted) {
      _mostrarDialogoExplicativo(
        context: context,
        titulo: 'Permisos de Bluetooth Requeridos',
        mensaje:
            'Se requiere autorización de Bluetooth para detectar y conectar lectores biométricos externos.',
        esPermanente:
            scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied,
      );
    }

    return exito;
  }

  void _mostrarDialogoExplicativo({
    required BuildContext context,
    required String titulo,
    required String mensaje,
    required bool esPermanente,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security, color: Color(0xFF2E8B57)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          if (esPermanente)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E8B57),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
              child: const Text('Abrir Ajustes'),
            ),
        ],
      ),
    );
  }
}
