import 'dart:convert';

/// Opciones de alineación de texto para el estándar ESC/POS
enum AlineacionEscPos { izquierda, centro, derecha }

/// Tamaños de fuente soportados por miniprinters térmicas
enum TamanoFuenteEscPos { normal, dobleAlto, dobleAncho, grande }

/// Generador de secuencias de bytes para impresoras térmicas ESC/POS (58mm y 80mm).
///
/// Produce comandos binarios estándar compatibles con impresoras Bluetooth/WiFi/USB
/// (Epson, ZJ, MPT-II, POS-5802, GOOJPRT, Xprinter, etc.) eliminando la necesidad
/// de compilar documentos PDF completos.
class GeneradorEscPos {
  final bool es80mm;
  final List<int> _buffer = [];

  GeneradorEscPos({this.es80mm = false}) {
    inicializar();
  }

  /// Retorna el ancho en caracteres por línea según el rollo de papel
  /// - 58mm: 32 caracteres (Font A)
  /// - 80mm: 48 caracteres (Font A)
  int get maxColumnas => es80mm ? 48 : 32;

  /// Retorna la secuencia completa de bytes ESC/POS lista para transmisión por Socket
  List<int> obtenerBytes() => List.unmodifiable(_buffer);

  /// Inicializa la impresora y establece la tabla de caracteres Latin-1 (Español)
  void inicializar() {
    _buffer.clear();
    // ESC @ (0x1B 0x40): Hardware Reset / Inicializar impresora
    _buffer.addAll([0x1B, 0x40]);
    // ESC t 16 (0x1B 0x74 0x10): Tabla de caracteres WPC1252 / Latin-1 (á, é, í, ó, ú, ñ)
    _buffer.addAll([0x1B, 0x74, 16]);
  }

  /// Establece la alineación horizontal de los siguientes textos
  void alinear(AlineacionEscPos alineacion) {
    int valor = 0; // Izquierda
    if (alineacion == AlineacionEscPos.centro) valor = 1;
    if (alineacion == AlineacionEscPos.derecha) valor = 2;
    _buffer.addAll([0x1B, 0x61, valor]);
  }

  /// Activa o desactiva el modo de texto resaltado (Negrita / Emphasized)
  void negrita(bool activar) {
    _buffer.addAll([0x1B, 0x45, activar ? 1 : 0]);
  }

  /// Configura el escalado de tamaño de texto
  void tamano(TamanoFuenteEscPos tamano) {
    int valor = 0x00;
    switch (tamano) {
      case TamanoFuenteEscPos.normal:
        valor = 0x00;
        break;
      case TamanoFuenteEscPos.dobleAlto:
        valor = 0x01;
        break;
      case TamanoFuenteEscPos.dobleAncho:
        valor = 0x10;
        break;
      case TamanoFuenteEscPos.grande:
        valor = 0x11; // Doble ancho + doble alto
        break;
    }
    _buffer.addAll([0x1D, 0x21, valor]);
  }

  /// Codificación segura en Latin1 (ISO-8859-1) para miniprinters térmicas,
  /// transcodificando caracteres especiales de puntuación Unicode a sus equivalentes Latin1/ASCII.
  static List<int> codificarLatin1Seguro(String str) {
    final saneada = str
        .replaceAll('•', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'");
    return saneada.runes.map((r) => r <= 255 ? r : 0x3F).toList();
  }

  /// Escribe una línea de texto formateada con salto de línea opcional
  void texto(
    String contenido, {
    AlineacionEscPos alineacion = AlineacionEscPos.izquierda,
    bool esNegrita = false,
    TamanoFuenteEscPos tamanoFuente = TamanoFuenteEscPos.normal,
    bool saltoLinea = true,
  }) {
    alinear(alineacion);
    negrita(esNegrita);
    tamano(tamanoFuente);

    // Codificación segura Latin1 para caracteres en español
    final bytesTexto = codificarLatin1Seguro(contenido);
    _buffer.addAll(bytesTexto);

    if (saltoLinea) {
      _buffer.add(0x0A); // LF (Line Feed)
    }
  }

  /// Dibuja una línea separadora continua según el ancho del papel
  void lineaDivisoria([String caracter = '-']) {
    alinear(AlineacionEscPos.centro);
    negrita(false);
    tamano(TamanoFuenteEscPos.normal);
    final linea = caracter * maxColumnas;
    texto(linea, saltoLinea: true);
  }

  /// Escribe dos columnas en una sola línea (ej. Producto a la izquierda, Total a la derecha)
  void filaDosColumnas(
    String izquierda,
    String derecha, {
    bool esNegrita = false,
    TamanoFuenteEscPos tamanoFuente = TamanoFuenteEscPos.normal,
  }) {
    alinear(AlineacionEscPos.izquierda);
    negrita(esNegrita);
    tamano(tamanoFuente);

    final total = maxColumnas;
    final derLong = derecha.length;
    final izqMax = total - derLong - 1;

    String izqAjustado = izquierda;
    if (izqAjustado.length > izqMax) {
      izqAjustado = izqAjustado.substring(0, izqMax);
    }

    final int espacios = total - izqAjustado.length - derLong;
    final String padding = ' ' * (espacios > 0 ? espacios : 1);

    final linea = '$izqAjustado$padding$derecha';
    final bytesTexto = codificarLatin1Seguro(linea);
    _buffer.addAll(bytesTexto);
    _buffer.add(0x0A);
  }

  /// Avanza [n] líneas de papel
  void alimentarLineas(int n) {
    _buffer.addAll([0x1B, 0x64, n.clamp(1, 10)]);
  }

  /// Emite el comando de corte de papel (automático en impresoras con guillotina)
  void cortarPapel({bool corteParcial = false}) {
    alimentarLineas(3);
    // GS V (0x1D 0x56): Corte completo (0x00) o parcial (0x01)
    _buffer.addAll([0x1D, 0x56, corteParcial ? 0x01 : 0x00]);
  }

  /// Envía el pulso eléctrico al pin del conector RJ11 para abrir el cajón de dinero
  void abrirCajonDinero() {
    // ESC p 0 25 250: Pulso eléctrico estándar de 50ms al solenoide
    _buffer.addAll([0x1B, 0x70, 0x00, 0x19, 0xFA]);
  }
}

