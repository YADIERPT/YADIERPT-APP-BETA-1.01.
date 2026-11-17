import 'package:uuid/uuid.dart';

/// Enumeración fuertemente tipada de los roles de usuario del vivero.
///
/// Define la jerarquía de accesos y responsabilidades de Planteapp con política simplificada de 2 roles:
/// - [duena]: Acceso total al negocio (Dueño/a: finanzas, auditoría, empleados, inventario y POS).
/// - [empleado]: Operación diaria focalizada exclusivamente en Punto de Venta (POS) y consulta básica.
enum RolUsuario {
  duena('dueño', 'Dueño'),
  empleado('empleado', 'Empleado');

  final String valor;
  final String etiqueta;

  const RolUsuario(this.valor, this.etiqueta);

  // Getters semánticos para verificación rápida de rol
  bool get esDuena => this == RolUsuario.duena;
  bool get esDueno => this == RolUsuario.duena;
  bool get esEmpleado => this == RolUsuario.empleado;

  /// Control de permisos de negocio y operación RBAC
  bool get puedeVerFinanzas => this == RolUsuario.duena;

  /// Permite crear productos, editar detalles, ajustar stock y deshabilitar (Dueño y Empleado)
  bool get puedeModificarInventario =>
      this == RolUsuario.duena || this == RolUsuario.empleado;

  /// Exclusivo del Dueño: ver catálogo deshabilitado, restaurar o eliminar definitivamente (Hard Delete)
  bool get puedeEliminarDefinitivamente => this == RolUsuario.duena;

  bool get puedeGestionarColaboradores => this == RolUsuario.duena;

  bool get soloPuntoDeVenta => this == RolUsuario.empleado;

  /// Conversión tolerante desde string (compatible con SQLite y esquemas legados)
  static RolUsuario desdeString(dynamic valor) {
    if (valor == null) return RolUsuario.empleado;
    final normalizado = valor.toString().toLowerCase().trim();
    switch (normalizado) {
      case 'duena':
      case 'dueña':
      case 'dueno':
      case 'dueño':
      case 'admin':
      case 'administrador':
      case 'owner':
        return RolUsuario.duena;
      case 'gerente':
      case 'manager':
      case 'empleado':
      case 'cajero':
      case 'colaborador':
      case 'staff':
      default:
        return RolUsuario.empleado;
    }
  }
}
class Colaborador {
  final String id;
  final String uuid;
  final String nombre;
  final String clave;
  final RolUsuario rol;
  final String? authUserId;
  final String? email;
  final String? updatedAt;
  final String? deletedAt;
  final String syncEstado;
  final String? dispositivoId;

  Colaborador({
    required this.id,
    String? uuid,
    required this.nombre,
    required this.clave,
    this.rol = RolUsuario.empleado,
    this.authUserId,
    this.email,
    this.updatedAt,
    this.deletedAt,
    this.syncEstado = 'pendiente',
    this.dispositivoId,
  }) : uuid = (uuid != null && uuid.isNotEmpty) ? uuid : const Uuid().v4();

  /// Email efectivo para Supabase Auth.
  /// Si no se proporcionó un email explícito, deriva una dirección estándar
  /// bajo el dominio de la empresa basada en el código local del colaborador (ej. vo4092@biznaga.planteapp.com).
  String get emailAutenticacion {
    if (email != null && email!.trim().isNotEmpty) {
      return email!.trim().toLowerCase();
    }
    final codigoSanitizado = id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$codigoSanitizado@biznaga.planteapp.com';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'nombre': nombre,
      'clave': clave,
      'rol': rol.valor,
      'auth_user_id': authUserId,
      'email': email,
      'updated_at': updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': deletedAt,
      'sync_estado': syncEstado,
      'dispositivo_id': dispositivoId,
    };
  }

  factory Colaborador.fromMap(Map<String, dynamic> map) {
    return Colaborador(
      id: map['id']?.toString() ?? '',
      uuid: map['uuid']?.toString(),
      nombre: map['nombre']?.toString() ?? '',
      clave: map['clave']?.toString() ?? '',
      rol: RolUsuario.desdeString(map['rol']),
      authUserId: (map['auth_user_id'] ?? map['authUserId'])?.toString(),
      email: map['email']?.toString(),
      updatedAt: map['updated_at']?.toString(),
      deletedAt: map['deleted_at']?.toString(),
      syncEstado: map['sync_estado']?.toString() ?? 'pendiente',
      dispositivoId: map['dispositivo_id']?.toString(),
    );
  }

  Colaborador copyWith({
    String? id,
    String? uuid,
    String? nombre,
    String? clave,
    RolUsuario? rol,
    String? authUserId,
    String? email,
    String? updatedAt,
    String? deletedAt,
    String? syncEstado,
    String? dispositivoId,
  }) {
    return Colaborador(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nombre: nombre ?? this.nombre,
      clave: clave ?? this.clave,
      rol: rol ?? this.rol,
      authUserId: authUserId ?? this.authUserId,
      email: email ?? this.email,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncEstado: syncEstado ?? this.syncEstado,
      dispositivoId: dispositivoId ?? this.dispositivoId,
    );
  }
}
