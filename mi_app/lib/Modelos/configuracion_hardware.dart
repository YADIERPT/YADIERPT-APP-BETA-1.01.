/// Modelo de configuración de Hardware y Periféricos para Planteapp.
/// Almacena los parámetros del lector biométrico y de la impresora térmica POS.
class ConfiguracionHardware {
  // Lector Biométrico
  String tipoLector; // 'local', 'wifi', 'bluetooth', 'cable'
  String wifiHost;
  int wifiPuerto;
  String bluetoothDispositivo;
  String cablePuertoSerial;
  int cableBaudRate;
  String ultimoEstadoLector;

  // Impresora Térmica POS (ESC/POS)
  String impresoraTipo; // 'bluetooth', 'usb', 'red'
  String impresoraNombre;
  String impresoraMac;
  String impresoraAnchoPapel; // '58mm', '80mm'
  bool impresoraConectada;

  ConfiguracionHardware({
    this.tipoLector = 'local',
    this.wifiHost = '192.168.1.100',
    this.wifiPuerto = 4370,
    this.bluetoothDispositivo = '',
    this.cablePuertoSerial = 'COM3',
    this.cableBaudRate = 9600,
    this.ultimoEstadoLector = 'Desconectado',
    this.impresoraTipo = 'bluetooth',
    this.impresoraNombre = '',
    this.impresoraMac = '',
    this.impresoraAnchoPapel = '80mm',
    this.impresoraConectada = false,
  });

  bool get tieneImpresoraVinculada =>
      impresoraMac.trim().isNotEmpty || impresoraNombre.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'tipoLector': tipoLector,
      'wifiHost': wifiHost,
      'wifiPuerto': wifiPuerto,
      'bluetoothDispositivo': bluetoothDispositivo,
      'cablePuertoSerial': cablePuertoSerial,
      'cableBaudRate': cableBaudRate,
      'ultimoEstadoLector': ultimoEstadoLector,
      'impresoraTipo': impresoraTipo,
      'impresoraNombre': impresoraNombre,
      'impresoraMac': impresoraMac,
      'impresoraAnchoPapel': impresoraAnchoPapel,
      'impresoraConectada': impresoraConectada ? 1 : 0,
    };
  }

  factory ConfiguracionHardware.fromMap(Map<String, dynamic> map) {
    return ConfiguracionHardware(
      tipoLector: map['tipoLector'] ?? 'local',
      wifiHost: map['wifiHost'] ?? '192.168.1.100',
      wifiPuerto: (map['wifiPuerto'] as num?)?.toInt() ?? 4370,
      bluetoothDispositivo: map['bluetoothDispositivo'] ?? '',
      cablePuertoSerial: map['cablePuertoSerial'] ?? 'COM3',
      cableBaudRate: (map['cableBaudRate'] as num?)?.toInt() ?? 9600,
      ultimoEstadoLector: map['ultimoEstadoLector'] ?? 'Desconectado',
      impresoraTipo: map['impresoraTipo'] ?? 'bluetooth',
      impresoraNombre: map['impresoraNombre'] ?? '',
      impresoraMac: map['impresoraMac'] ?? '',
      impresoraAnchoPapel: map['impresoraAnchoPapel'] ?? '80mm',
      impresoraConectada: map['impresoraConectada'] == 1,
    );
  }

  ConfiguracionHardware copyWith({
    String? tipoLector,
    String? wifiHost,
    int? wifiPuerto,
    String? bluetoothDispositivo,
    String? cablePuertoSerial,
    int? cableBaudRate,
    String? ultimoEstadoLector,
    String? impresoraTipo,
    String? impresoraNombre,
    String? impresoraMac,
    String? impresoraAnchoPapel,
    bool? impresoraConectada,
  }) {
    return ConfiguracionHardware(
      tipoLector: tipoLector ?? this.tipoLector,
      wifiHost: wifiHost ?? this.wifiHost,
      wifiPuerto: wifiPuerto ?? this.wifiPuerto,
      bluetoothDispositivo: bluetoothDispositivo ?? this.bluetoothDispositivo,
      cablePuertoSerial: cablePuertoSerial ?? this.cablePuertoSerial,
      cableBaudRate: cableBaudRate ?? this.cableBaudRate,
      ultimoEstadoLector: ultimoEstadoLector ?? this.ultimoEstadoLector,
      impresoraTipo: impresoraTipo ?? this.impresoraTipo,
      impresoraNombre: impresoraNombre ?? this.impresoraNombre,
      impresoraMac: impresoraMac ?? this.impresoraMac,
      impresoraAnchoPapel: impresoraAnchoPapel ?? this.impresoraAnchoPapel,
      impresoraConectada: impresoraConectada ?? this.impresoraConectada,
    );
  }
}

/// Representación desacoplada de un periférico de impresión detectado.
class DispositivoImpresora {
  final String nombre;
  final String macOUrl;
  final String tipo;
  final bool esPredeterminada;

  const DispositivoImpresora({
    required this.nombre,
    required this.macOUrl,
    this.tipo = 'bluetooth',
    this.esPredeterminada = false,
  });
}
