import 'dart:convert';

class ConfiguracionPerfil {
  int modoTema; // 0: Claro, 1: Oscuro, 2: Sistema
  double tipoCambioUSD;
  double porcentajeIvaDefecto;
  bool aplicarIva;
  List<String> etiquetas;

  ConfiguracionPerfil({
    this.modoTema = 2,
    this.tipoCambioUSD = 18.0,
    this.porcentajeIvaDefecto = 0.16,
    this.aplicarIva = true,
    this.etiquetas = const ['Interior', 'Suculentas', 'Macetas', 'Regalos'],
  });

  bool get temaOscuro => modoTema == 1;
  set temaOscuro(bool value) => modoTema = value ? 1 : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'temaOscuro': modoTema,
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
      } catch (_) {
        // En caso de error de parseo se mantienen las etiquetas por defecto
      }
    }

    final rawTema = map['temaOscuro'];
    int modo = 2;
    if (rawTema is int) {
      modo = rawTema;
    } else if (rawTema != null) {
      modo = rawTema == 1 ? 1 : 0;
    }

    return ConfiguracionPerfil(
      modoTema: modo,
      tipoCambioUSD: map['tipoCambioUSD'] != null
          ? (map['tipoCambioUSD'] as num).toDouble()
          : 18.0,
      porcentajeIvaDefecto: map['porcentajeIvaDefecto'] != null
          ? (map['porcentajeIvaDefecto'] as num).toDouble()
          : 0.16,
      aplicarIva: map['aplicarIva'] != null ? map['aplicarIva'] == 1 : true,
      etiquetas: etiq,
    );
  }

  void actualizarModoTema(int nuevoModo) {
    modoTema = nuevoModo;
  }

  void actualizarTema(bool oscuro) {
    modoTema = oscuro ? 1 : 0;
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

