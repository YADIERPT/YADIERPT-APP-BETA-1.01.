class Colaborador {
  String id;
  String nombre;
  String clave;
  String rol;

  Colaborador({
    required this.id,
    required this.nombre,
    required this.clave,
    this.rol = 'cajero',
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'nombre': nombre, 'clave': clave, 'rol': rol};
  }

  factory Colaborador.fromMap(Map<String, dynamic> map) {
    return Colaborador(
      id: map['id'],
      nombre: map['nombre'],
      clave: map['clave'],
      rol: map['rol'],
    );
  }
}
