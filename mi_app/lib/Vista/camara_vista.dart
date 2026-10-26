import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../Tema/app_theme.dart';
import '../Servicios/servicio_permisos.dart';

/// Pantalla de cámara interna en la aplicación.
/// Diseñada para prevenir el cierre de la app y la pantalla negra en dispositivos con ColorOS/Realme UI
/// al no delegar en la app de cámara pesada del sistema operativo Android.
class CamaraVista extends StatefulWidget {
  const CamaraVista({super.key});

  @override
  State<CamaraVista> createState() => _CamaraVistaState();
}

class _CamaraVistaState extends State<CamaraVista> with WidgetsBindingObserver {
  List<CameraDescription> _camaras = [];
  CameraController? _controller;
  int _indiceCamaraSeleccionada = 0;
  bool _estaInicializando = true;
  bool _estaCapturando = false;
  String? _mensajeError;
  FlashMode _modoFlash = FlashMode.auto;

  // Foto tomada pendiente de confirmación
  XFile? _fotoCapturada;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inicializarCamaras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _inicializarCamaraConIndice(_indiceCamaraSeleccionada);
    }
  }

  Future<void> _inicializarCamaras() async {
    try {
      final bool permiso =
          await ServicioPermisos.instancia.solicitarPermisoCamara(context: context);
      if (!permiso) {
        if (mounted) {
          setState(() {
            _mensajeError = 'Permiso de cámara denegado';
            _estaInicializando = false;
          });
        }
        return;
      }

      _camaras = await availableCameras();
      if (_camaras.isEmpty) {
        if (mounted) {
          setState(() {
            _mensajeError = 'No se encontró ningún sensor de cámara en este dispositivo';
            _estaInicializando = false;
          });
        }
        return;
      }

      await _inicializarCamaraConIndice(0);
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajeError = 'Error al iniciar la cámara: $e';
          _estaInicializando = false;
        });
      }
    }
  }

  Future<void> _inicializarCamaraConIndice(int indice) async {
    if (_camaras.isEmpty) return;

    if (mounted) {
      setState(() {
        _estaInicializando = true;
        _mensajeError = null;
      });
    }

    await _controller?.dispose();

    final nuevoController = CameraController(
      _camaras[indice],
      ResolutionPreset.medium, // Resolución óptima (720p/1080p) para catálogo sin sobrecarga de memoria
      enableAudio: false, // Deshabilita audio para no requerir permiso de micrófono
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await nuevoController.initialize();
      await nuevoController.setFlashMode(_modoFlash);

      if (mounted) {
        setState(() {
          _controller = nuevoController;
          _indiceCamaraSeleccionada = indice;
          _estaInicializando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajeError = 'No se pudo configurar el sensor: $e';
          _estaInicializando = false;
        });
      }
    }
  }

  Future<void> _alternarCamara() async {
    if (_camaras.length < 2 || _estaCapturando) return;
    final nuevoIndice = (_indiceCamaraSeleccionada + 1) % _camaras.length;
    await _inicializarCamaraConIndice(nuevoIndice);
  }

  Future<void> _ciclarFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    FlashMode nuevoModo;
    switch (_modoFlash) {
      case FlashMode.auto:
        nuevoModo = FlashMode.always;
        break;
      case FlashMode.always:
        nuevoModo = FlashMode.off;
        break;
      case FlashMode.off:
      default:
        nuevoModo = FlashMode.auto;
        break;
    }

    try {
      await _controller!.setFlashMode(nuevoModo);
      if (mounted) {
        setState(() {
          _modoFlash = nuevoModo;
        });
      }
    } catch (_) {}
  }

  Future<void> _capturarFoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _estaCapturando ||
        _estaInicializando) {
      return;
    }

    setState(() {
      _estaCapturando = true;
    });

    try {
      final XFile foto = await _controller!.takePicture();
      final file = File(foto.path);
      if (await file.exists() && await file.length() > 0) {
        if (mounted) {
          setState(() {
            _fotoCapturada = foto;
            _estaCapturando = false;
          });
        }
      } else {
        throw Exception('El archivo capturado está vacío');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _estaCapturando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al capturar foto: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _descartarFoto() {
    if (_fotoCapturada != null) {
      try {
        final f = File(_fotoCapturada!.path);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (_) {}
    }
    setState(() {
      _fotoCapturada = null;
    });
  }

  void _confirmarFoto() {
    if (_fotoCapturada != null) {
      Navigator.of(context).pop(_fotoCapturada!.path);
    }
  }

  Future<void> _elegirDeGaleria() async {
    final bool permitido =
        await ServicioPermisos.instancia.solicitarPermisoGaleria(context: context);
    if (!permitido) return;

    try {
      final picker = ImagePicker();
      final XFile? imagen = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (imagen != null && imagen.path.isNotEmpty && mounted) {
        Navigator.of(context).pop(imagen.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir galería: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  IconData _obtenerIconoFlash() {
    switch (_modoFlash) {
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
      default:
        return Icons.flash_auto;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Visor de la cámara o previsualización de la foto capturada
            if (_fotoCapturada != null)
              _construirPrevisualizacionFoto()
            else if (_mensajeError != null)
              _construirPantallaError()
            else if (_estaInicializando || _controller == null || !_controller!.value.isInitialized)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else
              _construirVisorCamara(),

            // 2. Barra Superior (Controles rápidos)
            if (_fotoCapturada == null && _mensajeError == null)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_obtenerIconoFlash(), color: Colors.white, size: 24),
                          onPressed: _ciclarFlash,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                          ),
                        ),
                        if (_camaras.length > 1) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 24),
                            onPressed: _alternarCamara,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

            // 3. Barra Inferior de Disparo (cuando está en modo visor)
            if (_fotoCapturada == null && _mensajeError == null)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: _construirBarraDisparo(),
              ),

            // 4. Barra Inferior de Confirmación (cuando la foto ya fue tomada)
            if (_fotoCapturada != null)
              Positioned(
                bottom: 28,
                left: 24,
                right: 24,
                child: _construirBarraConfirmacion(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _construirVisorCamara() {
    final camera = _controller!;
    return Center(
      child: AspectRatio(
        aspectRatio: 1 / camera.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(camera),
            // Marco guía para centrar el producto
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirPrevisualizacionFoto() {
    return Center(
      child: Image.file(
        File(_fotoCapturada!.path),
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _construirBarraDisparo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Acceso directo a galería
        IconButton(
          icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 30),
          onPressed: _elegirDeGaleria,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white12,
            padding: const EdgeInsets.all(12),
          ),
        ),

        // Botón principal de obturador
        GestureDetector(
          onTap: _estaCapturando ? null : _capturarFoto,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              color: _estaCapturando ? Colors.grey : Colors.white24,
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: _estaCapturando
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.black,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),

        // Marcador simétrico para balancear layout
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _construirBarraConfirmacion() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Botón Repetir
        ElevatedButton.icon(
          onPressed: _descartarFoto,
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text(
            'Repetir',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white24,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // Botón Confirmar
        ElevatedButton.icon(
          onPressed: _confirmarFoto,
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          label: const Text(
            'Usar Foto',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirPantallaError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_photography_outlined, size: 64, color: AppColors.coral),
            const SizedBox(height: 16),
            Text(
              _mensajeError ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  child: const Text('Volver'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _elegirDeGaleria,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Elegir de Galería'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
