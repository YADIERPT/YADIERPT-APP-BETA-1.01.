import '../BaseDatos/base_datos.dart';
import '../Modelos/configuracion_biometrica.dart';
import '../Servicios/servicio_biometrico.dart';

class ControladorBiometrico {
  ConfiguracionBiometrica _config = ConfiguracionBiometrica();
  final ServicioBiometrico _servicio;

  ControladorBiometrico({ServicioBiometrico? servicio})
      : _servicio = servicio ?? ServicioBiometrico();

  ConfiguracionBiometrica get config => _config;
  ServicioBiometrico get servicio => _servicio;

  bool get tieneHuellaRegistrada => _config.tieneHuellaRegistrada;

  Future<void> inicializar() async {
    final db = await BaseDeDatos.instancia.database;
    final registros = await db.query(
      'configuracion_biometrica',
      where: 'id = 1',
    );
    if (registros.isNotEmpty) {
      _config = ConfiguracionBiometrica.fromMap(registros.first);
    } else {
      _config = ConfiguracionBiometrica();
      await db.insert('configuracion_biometrica', _config.toMap());
    }
  }

  Future<void> guardarConfiguracion(ConfiguracionBiometrica nuevaConfig) async {
    _config = nuevaConfig;
    final db = await BaseDeDatos.instancia.database;
    await db.update(
      'configuracion_biometrica',
      nuevaConfig.toMap(),
      where: 'id = 1',
    );
  }

  Future<void> activarBiometria(bool habilitar) async {
    _config.biometriaHabilitada = habilitar;
    await guardarConfiguracion(_config);
  }

  Future<bool> registrarHuella({
    required String colaboradorId,
    required String nombreHuella,
  }) async {
    final bool exito = await _servicio.autenticarHuella(
      motivo: 'Coloca tu dedo en el sensor para registrar tu huella dactilar',
    );

    if (exito) {
      _config.biometriaHabilitada = true;
      _config.usuarioVinculadoId = colaboradorId;
      _config.nombreHuella = nombreHuella.trim().isNotEmpty
          ? nombreHuella.trim()
          : 'Huella Principal';
      _config.fechaRegistro = DateTime.now().toIso8601String();
      await guardarConfiguracion(_config);
      return true;
    }
    return false;
  }

  Future<void> eliminarHuella() async {
    _config.biometriaHabilitada = false;
    _config.usuarioVinculadoId = null;
    _config.nombreHuella = null;
    _config.fechaRegistro = null;
    await guardarConfiguracion(_config);
  }

  Future<ResultadoConexionHardware> probarYActualizarConexion() async {
    ResultadoConexionHardware resultado;

    switch (_config.tipoConexion) {
      case 'wifi':
        resultado = await _servicio.probarConexionWifi(
          host: _config.wifiHost,
          puerto: _config.wifiPuerto,
        );
        break;
      case 'cable':
        resultado = await _servicio.probarConexionCable(
          puertoSerial: _config.cablePuertoSerial,
          baudRate: _config.cableBaudRate,
        );
        break;
      case 'bluetooth':
        resultado = await _servicio.probarConexionBluetooth(
          dispositivo: _config.bluetoothDispositivo,
        );
        break;
      case 'local':
      default:
        final bool compatible = await _servicio.verificarSoporteBiometrico();
        resultado = ResultadoConexionHardware(
          exito: compatible,
          mensaje: compatible
              ? 'Lector biométrico nativo detectado y listo para operar.'
              : 'No se detectó sensor biométrico nativo compatible en este equipo.',
        );
        break;
    }

    _config.ultimoEstadoConexion =
        resultado.exito ? 'Conectado' : 'Error de Conexión';
    await guardarConfiguracion(_config);

    return resultado;
  }

  Future<String?> autenticarAcceso() async {
    if (!_config.tieneHuellaRegistrada) {
      return null;
    }

    final bool autenticado = await _servicio.autenticarHuella(
      motivo: 'Verifica tu huella para acceder a Planteapp',
    );

    if (autenticado) {
      return _config.usuarioVinculadoId;
    }
    return null;
  }
}
