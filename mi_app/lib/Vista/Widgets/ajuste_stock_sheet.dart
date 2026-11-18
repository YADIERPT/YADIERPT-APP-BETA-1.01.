import 'package:flutter/material.dart';

import '../../Controladores/controlador_inventario.dart';
import '../../Modelos/producto.dart';
import '../../Tema/app_theme.dart';
import '../../Constantes/limites.dart';

class AjusteStockSheet extends StatefulWidget {
  final Producto producto;
  final ControladorInventario controladorInventario;
  final VoidCallback onActualizado;

  const AjusteStockSheet({
    super.key,
    required this.producto,
    required this.controladorInventario,
    required this.onActualizado,
  });

  @override
  State<AjusteStockSheet> createState() => _AjusteStockSheetState();
}

class _AjusteStockSheetState extends State<AjusteStockSheet> {
  late int _cantidad;
  late int _umbral;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cantidad = widget.producto.cantidadEnInventario;
    _umbral = widget.producto.umbralStockCritico;
  }

  Future<void> _confirmar() async {
    setState(() => _guardando = true);
    try {
      widget.producto.cantidadEnInventario = _cantidad;
      widget.producto.umbralStockCritico = _umbral;

      await widget.controladorInventario.actualizarExistenciasYUmbral(
        widget.producto.id,
        _cantidad,
        _umbral,
      );

      widget.onActualizado();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AJUSTE MANUAL',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.producto.nombre,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.secondarySurface,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () {
                    if (_cantidad > 0) setState(() => _cantidad--);
                  },
                  icon: const Icon(Icons.remove, size: 26),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.card,
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(48, 48),
                    shape: const CircleBorder(),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '$_cantidad',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'unidades en inventario',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    if (_cantidad < LimitesApp.maxUnidades) {
                      setState(() => _cantidad++);
                    }
                  },
                  icon: const Icon(Icons.add, size: 26),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.card,
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(48, 48),
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // SECCIÓN DECORATIVA DE ALERTA: Umbral de Stock Crítico
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.orange.withOpacity(0.05)
                  : Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.orange,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.orange.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Umbral de Stock Crítico',
                        style: TextStyle(
                          color: isDarkMode
                              ? const Color(0xFFFFB74D) // Naranja claro/ámbar legible en fondo oscuro
                              : const Color(0xFFBF360C), // Naranja oscuro/terracota legible en fondo claro
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Alertar cuando queden existencias',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : const Color(0xFF5D4037),
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppColors.card : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.orange.withOpacity(0.35)
                          : Colors.orange.shade300,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          if (_umbral > 0) {
                            setState(() => _umbral--);
                          }
                        },
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Icon(
                            Icons.remove,
                            size: 16,
                            color: isDarkMode ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 26),
                        alignment: Alignment.center,
                        child: Text(
                          '$_umbral',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          if (_umbral < LimitesApp.maxStockUmbral) {
                            setState(() => _umbral++);
                          }
                        },
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: isDarkMode ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _guardando ? null : _confirmar,
            icon: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 20),
            label: const Text(
              'Confirmar Existencias',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
