import 'dart:convert';

class ConfiguracionPerfil {
  bool temaOscuro;
  double tipoCambioUSD;
  double porcentajeIvaDefecto;
  bool aplicarIva;
  List<String> etiquetas;

  ConfiguracionPerfil({
    this.temaOscuro = false,
    this.tipoCambioUSD = 18.0,
    this.porcentajeIvaDefecto = 0.16,
    this.aplicarIva = true,
    this.etiquetas = const ['Interior', 'Suculentas', 'Macetas', 'Regalos'],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'temaOscuro': temaOscuro ? 1 : 0,
      'tipoCambioUSD': tipoCambioUSD,
      'porcentajeIvaDefecto': porcentajeIvaDefecto,
      'aplicarIva': aplicarIva ? 1 : 0,
      'etiquetasJson': jsonEncode(etiquetas),
    };
  }

  factory ConfiguracionPerfil.fromMap(Map<String, dynamic> map) {
    List<String> etiq = ['Interior', 'Suculentas', 'Macetas', 'Regalos'];
    if (map['etiquetasJson'] != null) {
      try {
        etiq = List<String>.from(jsonDecode(map['etiquetasJson']));
      } catch (e) {}
    }
    return ConfiguracionPerfil(
      temaOscuro: map['temaOscuro'] == 1,
      tipoCambioUSD: map['tipoCambioUSD'],
      porcentajeIvaDefecto: map['porcentajeIvaDefecto'],
      aplicarIva: map['aplicarIva'] != null ? map['aplicarIva'] == 1 : true,
      etiquetas: etiq,
    );
  }

  void actualizarTema(bool oscuro) {
    temaOscuro = oscuro;
  }

  void alternarAplicarIva(bool estado) {
    aplicarIva = estado;
  }

  void actualizarTipoCambio(double nuevoCambio) {
    if (nuevoCambio > 0) {
      tipoCambioUSD = nuevoCambio;
    } else {
      throw Exception('El tipo de cambio debe ser mayor a cero.');
    }
  }

  void actualizarIva(double nuevoIva) {
    if (nuevoIva >= 0 && nuevoIva <= 1) {
      porcentajeIvaDefecto = nuevoIva;
    } else {
      throw Exception('El IVA debe ser un valor decimal entre 0 y 1.');
    }
  }
}
