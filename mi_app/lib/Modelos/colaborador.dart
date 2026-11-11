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
  final String nombre;
  final String clave;
  final RolUsuario rol;

  Colaborador({
    required this.id,
    required this.nombre,
    required this.clave,
    this.rol = RolUsuario.empleado,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'clave': clave,
      'rol': rol.valor,
    };
  }

  factory Colaborador.fromMap(Map<String, dynamic> map) {
    return Colaborador(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      clave: map['clave']?.toString() ?? '',
      rol: RolUsuario.desdeString(map['rol']),
    );
  }

  Colaborador copyWith({
    String? id,
    String? nombre,
    String? clave,
    RolUsuario? rol,
  }) {
    return Colaborador(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      clave: clave ?? this.clave,
      rol: rol ?? this.rol,
    );
  }
}
