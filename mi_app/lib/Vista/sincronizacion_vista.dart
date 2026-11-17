import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_sincronizacion.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Modelos/colaborador.dart';
import 'Widgets/role_guard.dart';

/// Pantalla de configuración, monitoreo y diagnóstico de Sincronización y Respaldo en la Nube.
/// Exclusiva para el rol Dueño de Planteapp.
class SincronizacionVista extends StatefulWidget {
  final ControladorSincronizacion? controladorSincronizacion;

  const SincronizacionVista({
    super.key,
    this.controladorSincronizacion,
  });

  @override
  State<SincronizacionVista> createState() => _SincronizacionVistaState();
}

class _SincronizacionVistaState extends State<SincronizacionVista> {
  ControladorSincronizacion? _controladorLocal;

  ControladorSincronizacion _obtenerControlador(BuildContext context) {
    if (widget.controladorSincronizacion != null) {
      return widget.controladorSincronizacion!;
    }
    if (_controladorLocal != null) {
      return _controladorLocal!;
    }
    try {
      return Provider.of<ControladorSincronizacion>(context);
    } catch (_) {
      _controladorLocal = ControladorSincronizacion();
      return _controladorLocal!;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = _obtenerControlador(context);
      ctrl.cargarDetallesCompletos();
    });
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin registros de sincronización';
    final formato = DateFormat('dd/MM/yyyy HH:mm:ss');
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha.toLocal());

    String tiempoRelativo;
    if (diferencia.inSeconds < 60) {
      tiempoRelativo = 'hace unos momentos';
    } else if (diferencia.inMinutes < 60) {
      tiempoRelativo = 'hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      tiempoRelativo = 'hace ${diferencia.inHours} h';
    } else {
      tiempoRelativo = 'hace ${diferencia.inDays} d';
    }

    return '${formato.format(fecha.toLocal())} ($tiempoRelativo)';
  }

  void _copiarAlPortapapeles(String texto, String mensaje) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _obtenerControlador(context);
    RolUsuario? rolActual;
    try {
      rolActual = context.watch<ControladorAutenticacion>().usuarioActual?.rol;
    } catch (_) {}

    return RoleGuard.soloDueno(
      rolActual: rolActual,
      modo: RoleGuardMode.placeholder,
      child: AnimatedBuilder(
        animation: ThemeManager.instance,
        builder: (context, _) {
          return ListenableBuilder(
            listenable: ctrl,
            builder: (context, _) {
              return Scaffold(
                backgroundColor: AppColors.surface,
                appBar: AppBar(
                  backgroundColor: AppColors.surface,
                  elevation: 0,
                  iconTheme: IconThemeData(color: AppColors.textPrimary),
                  title: Text(
                    'Sincronización y Respaldo',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar estado',
                      onPressed: () async {
                        await ctrl.cargarDetallesCompletos();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Estado de sincronización actualizado'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                body: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      _construirTarjetaEstado(ctrl),
                      const SizedBox(height: 16),
                      _construirTarjetaAcciones(ctrl),
                      const SizedBox(height: 16),
                      _construirTarjetaDispositivoYCola(ctrl),
                      const SizedBox(height: 16),
                      _construirSeccionErrores(ctrl),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Tarjeta con el estado visual actual de la sincronización y la red
  Widget _construirTarjetaEstado(ControladorSincronizacion ctrl) {
    final estado = ctrl.estadoUI;
    IconData iconoPrincipal;
    Color colorIcono;
    Color fondoIcono;
    String tituloEstado;
    String descripcionEstado;

    if (estado == EstadoSincronizacionUI.modoLocalPuro) {
      iconoPrincipal = Icons.cloud_off_outlined;
      colorIcono = AppColors.turquoise;
      fondoIcono = AppColors.subtleTurquoise;
      tituloEstado = 'Modo Local Puro';
      descripcionEstado =
          'Operando 100% desconectado de la nube. Todos los datos están cifrados en este dispositivo con SQLCipher AES-256.';
    } else if (!ctrl.syncHabilitada) {
      iconoPrincipal = Icons.pause_circle_outline_rounded;
      colorIcono = AppColors.textSecondary;
      fondoIcono = AppColors.secondarySurface;
      tituloEstado = 'Sincronización en Pausa';
      descripcionEstado =
          'La sincronización automática está desactivada. Puedes sincronizar manualmente en cualquier momento.';
    } else {
      switch (estado) {
        case EstadoSincronizacionUI.sincronizando:
          iconoPrincipal = Icons.sync_rounded;
          colorIcono = AppColors.brightGreen;
          fondoIcono = AppColors.subtleGreen;
          tituloEstado = 'Sincronizando Cambios';
          descripcionEstado =
              'Transmitiendo datos entre la base de datos local y Supabase Postgres...';
          break;

        case EstadoSincronizacionUI.sinConexion:
          iconoPrincipal = Icons.cloud_off_rounded;
          colorIcono = AppColors.textSecondary;
          fondoIcono = AppColors.secondarySurface;
          tituloEstado = 'Sin Conexión a Internet';
          descripcionEstado =
              'Operación offline-first activa. Los tickets, abonos y stock se guardan localmente y subirán al reconectar.';
          break;

        case EstadoSincronizacionUI.error:
          iconoPrincipal = Icons.warning_amber_rounded;
          colorIcono = AppColors.amber;
          fondoIcono = AppColors.subtleAmber;
          tituloEstado = 'Aviso de Sincronización';
          descripcionEstado =
              ctrl.ultimoError ?? 'Ocurrió un inconveniente al contactar el servidor remoto.';
          break;

        case EstadoSincronizacionUI.pendiente:
          iconoPrincipal = Icons.cloud_upload_outlined;
          colorIcono = AppColors.primary;
          fondoIcono = AppColors.primaryContainer;
          tituloEstado = 'Cambios Locales Pendientes';
          descripcionEstado =
              '${ctrl.cambiosPendientes} operaciones en cola listas para respaldarse en la nube.';
          break;

        case EstadoSincronizacionUI.sincronizado:
        default:
          iconoPrincipal = Icons.cloud_done_rounded;
          colorIcono = AppColors.brightGreen;
          fondoIcono = AppColors.subtleGreen;
          tituloEstado = 'Sincronizado con Supabase';
          descripcionEstado =
              'Los datos locales y remotos están completamente al día y respaldados.';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: fondoIcono,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconoPrincipal, color: colorIcono, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tituloEstado,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: ctrl.enLinea ? AppColors.brightGreen : AppColors.textSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ctrl.enLinea ? 'En línea' : 'Desconectado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ctrl.enLinea ? AppColors.brightGreen : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            descripcionEstado,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Última sincronización exitosa:\n${_formatearFecha(ctrl.ultimaSyncExitosa)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tarjeta con switch de activación y botón de sincronización manual
  Widget _construirTarjetaAcciones(ControladorSincronizacion ctrl) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            key: const ValueKey('switch_sincronizacion_activa'),
            activeThumbColor: AppColors.primary,
            title: Text(
              'Sincronización Automática',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              'Sincroniza en segundo plano al detectar conexión y avisos de Realtime',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            value: ctrl.syncHabilitada,
            onChanged: (habilitar) async {
              await ctrl.alternarSyncHabilitada(habilitar);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      habilitar
                          ? 'Sincronización automática activada'
                          : 'Sincronización automática pausada',
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const ValueKey('boton_sincronizar_ahora'),
                onPressed: ctrl.sincronizando
                    ? null
                    : () async {
                        final res = await ctrl.sincronizarManual();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        if (res.exitoso) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Sincronización completada (${res.registrosSubidos} subidos, ${res.registrosDescargados} descargados)',
                              ),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res.error ?? 'Aviso: No se pudo completar la sincronización',
                              ),
                              backgroundColor: AppColors.coral,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                icon: ctrl.sincronizando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  ctrl.sincronizando ? 'Sincronizando...' : 'Sincronizar Ahora',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de detalles del identificador único de terminal y cola
  Widget _construirTarjetaDispositivoYCola(ControladorSincronizacion ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DETALLES DEL DISPOSITIVO Y COLA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Material(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  'ID del Dispositivo',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  ctrl.dispositivoId.isNotEmpty ? ctrl.dispositivoId : 'No asignado',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: 'Copiar ID único',
                  onPressed: ctrl.dispositivoId.isNotEmpty
                      ? () => _copiarAlPortapapeles(
                            ctrl.dispositivoId,
                            'ID del dispositivo copiado al portapapeles',
                          )
                      : null,
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              ListTile(
                title: Text(
                  'Cambios pendientes en cola (Outbox)',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${ctrl.cambiosPendientes} registros locales esperando subida',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ctrl.cambiosPendientes > 0
                        ? AppColors.subtleAmber
                        : AppColors.subtleGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${ctrl.cambiosPendientes}',
                    style: TextStyle(
                      color: ctrl.cambiosPendientes > 0
                          ? AppColors.amber
                          : AppColors.brightGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              ListTile(
                title: Text(
                  'Base de Datos Local',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'SQLite v15 Cifrado (SQLCipher AES-256)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.brightGreen,
                  size: 20,
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              ListTile(
                title: Text(
                  'Nube de Respaldo',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  ctrl.estadoUI == EstadoSincronizacionUI.modoLocalPuro
                      ? 'Desactivada (Modo Local Puro)'
                      : 'Supabase Postgres (7 tablas con RLS)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  Icons.cloud_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Sección con el registro de errores y reintentos en la cola outbox
  Widget _construirSeccionErrores(ControladorSincronizacion ctrl) {
    final errores = ctrl.registroErrores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'REGISTRO DE ERRORES Y REINTENTOS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (errores.isNotEmpty)
              TextButton.icon(
                key: const ValueKey('boton_reintentar_errores'),
                onPressed: ctrl.sincronizando
                    ? null
                    : () async {
                        final res = await ctrl.reintentarErrores();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              res.exitoso
                                  ? 'Reintento de sincronización exitoso'
                                  : 'Aviso al reintentar: ${res.error}',
                            ),
                            backgroundColor:
                                res.exitoso ? AppColors.primary : AppColors.coral,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Reintentar todo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (errores.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.brightGreen,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sin errores en cola',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Todas las operaciones outbox se han procesado limpiamente.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: errores.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final err = errores[index];
              final tabla = err['tabla']?.toString() ?? 'desconocida';
              final op = err['operacion']?.toString() ?? 'upsert';
              final intentos = err['intentos']?.toString() ?? '0';
              final mensajeError =
                  err['ultimo_error']?.toString() ?? 'Error desconocido';
              final uuid = err['registro_uuid']?.toString() ?? '';
              final fecha = err['created_at']?.toString() ?? '';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.coral,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$tabla ($op)',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.subtleAmber,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Intentos: $intentos',
                            style: TextStyle(
                              color: AppColors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mensajeError,
                      style: TextStyle(
                        color: AppColors.coral,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'UUID: $uuid | $fecha',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
