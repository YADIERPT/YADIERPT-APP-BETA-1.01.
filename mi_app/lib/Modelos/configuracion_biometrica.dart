const Object _sentinel = Object();

class ConfiguracionBiometrica {
  bool biometriaHabilitada;
  String? usuarioVinculadoId;
  String? nombreHuella;
  String? fechaRegistro;
  String tipoConexion; // 'local', 'wifi', 'bluetooth', 'cable'
  String wifiHost;
  int wifiPuerto;
  String bluetoothDispositivo;
  String cablePuertoSerial;
  int cableBaudRate;
  String ultimoEstadoConexion;

  ConfiguracionBiometrica({
    this.biometriaHabilitada = false,
    this.usuarioVinculadoId,
    this.nombreHuella,
    this.fechaRegistro,
    this.tipoConexion = 'local',
    this.wifiHost = '192.168.1.100',
    this.wifiPuerto = 4370,
    this.bluetoothDispositivo = '',
    this.cablePuertoSerial = 'COM3',
    this.cableBaudRate = 9600,
    this.ultimoEstadoConexion = 'Desconectado',
  });

  bool get tieneHuellaRegistrada =>
      biometriaHabilitada &&
      usuarioVinculadoId != null &&
      usuarioVinculadoId!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'biometriaHabilitada': biometriaHabilitada ? 1 : 0,
      'usuarioVinculadoId': usuarioVinculadoId,
      'nombreHuella': nombreHuella,
      'fechaRegistro': fechaRegistro,
      'tipoConexion': tipoConexion,
      'wifiHost': wifiHost,
      'wifiPuerto': wifiPuerto,
      'bluetoothDispositivo': bluetoothDispositivo,
      'cablePuertoSerial': cablePuertoSerial,
      'cableBaudRate': cableBaudRate,
      'ultimoEstadoConexion': ultimoEstadoConexion,
    };
  }

  factory ConfiguracionBiometrica.fromMap(Map<String, dynamic> map) {
    return ConfiguracionBiometrica(
      biometriaHabilitada: map['biometriaHabilitada'] == 1,
      usuarioVinculadoId: map['usuarioVinculadoId'],
      nombreHuella: map['nombreHuella'],
      fechaRegistro: map['fechaRegistro'],
      tipoConexion: map['tipoConexion'] ?? 'local',
      wifiHost: map['wifiHost'] ?? '192.168.1.100',
      wifiPuerto: (map['wifiPuerto'] as num?)?.toInt() ?? 4370,
      bluetoothDispositivo: map['bluetoothDispositivo'] ?? '',
      cablePuertoSerial: map['cablePuertoSerial'] ?? 'COM3',
      cableBaudRate: (map['cableBaudRate'] as num?)?.toInt() ?? 9600,
      ultimoEstadoConexion: map['ultimoEstadoConexion'] ?? 'Desconectado',
    );
  }

  ConfiguracionBiometrica copyWith({
    bool? biometriaHabilitada,
    Object? usuarioVinculadoId = _sentinel,
    Object? nombreHuella = _sentinel,
    Object? fechaRegistro = _sentinel,
    String? tipoConexion,
    String? wifiHost,
    int? wifiPuerto,
    String? bluetoothDispositivo,
    String? cablePuertoSerial,
    int? cableBaudRate,
    String? ultimoEstadoConexion,
  }) {
    return ConfiguracionBiometrica(
      biometriaHabilitada: biometriaHabilitada ?? this.biometriaHabilitada,
      usuarioVinculadoId: identical(usuarioVinculadoId, _sentinel)
          ? this.usuarioVinculadoId
          : usuarioVinculadoId as String?,
      nombreHuella: identical(nombreHuella, _sentinel)
          ? this.nombreHuella
          : nombreHuella as String?,
      fechaRegistro: identical(fechaRegistro, _sentinel)
          ? this.fechaRegistro
          : fechaRegistro as String?,
      tipoConexion: tipoConexion ?? this.tipoConexion,
      wifiHost: wifiHost ?? this.wifiHost,
      wifiPuerto: wifiPuerto ?? this.wifiPuerto,
      bluetoothDispositivo: bluetoothDispositivo ?? this.bluetoothDispositivo,
      cablePuertoSerial: cablePuertoSerial ?? this.cablePuertoSerial,
      cableBaudRate: cableBaudRate ?? this.cableBaudRate,
      ultimoEstadoConexion: ultimoEstadoConexion ?? this.ultimoEstadoConexion,
    );
  }
}
