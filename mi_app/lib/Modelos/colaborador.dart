/// Enumeración fuertemente tipada de los roles de usuario del vivero.
///
/// Define la jerarquía de accesos y responsabilidades de Planteapp:
/// - [duena]: Acceso total al negocio (finanzas, auditoría, empleados, inventario y POS).
/// - [gerente]: Gestión operativa, compras, inventario, reportes y supervisión de ventas.
/// - [empleado]: Operación diaria focalizada exclusivamente en Punto de Venta (POS) y consulta básica.
enum RolUsuario {
  duena('duena', 'Dueña'),
  gerente('gerente', 'Gerente'),
  empleado('empleado', 'Empleado');

  final String valor;
  final String etiqueta;

  const RolUsuario(this.valor, this.etiqueta);

  // Getters semánticos para verificación rápida de rol
  bool get esDuena => this == RolUsuario.duena;
  bool get esGerente => this == RolUsuario.gerente;
  bool get esEmpleado => this == RolUsuario.empleado;

  /// Control de permisos de negocio
  bool get puedeVerFinanzas =>
      this == RolUsuario.duena || this == RolUsuario.gerente;

  bool get puedeModificarInventario =>
      this == RolUsuario.duena || this == RolUsuario.gerente;

  bool get puedeGestionarColaboradores =>
      this == RolUsuario.duena || this == RolUsuario.gerente;

  bool get soloPuntoDeVenta => this == RolUsuario.empleado;

  /// Conversión tolerante desde string (compatible con SQLite y esquemas legados)
  static RolUsuario desdeString(dynamic valor) {
    if (valor == null) return RolUsuario.empleado;
    final normalizado = valor.toString().toLowerCase().trim();
    switch (normalizado) {
      case 'duena':
      case 'dueña':
      case 'admin':
      case 'administrador':
      case 'owner':
        return RolUsuario.duena;
      case 'gerente':
      case 'manager':
        return RolUsuario.gerente;
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
