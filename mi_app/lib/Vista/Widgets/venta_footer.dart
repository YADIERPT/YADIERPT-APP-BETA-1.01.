import 'package:flutter/material.dart';

import '../../Modelos/venta.dart';
import '../../Tema/app_theme.dart';
import '../../Constantes/limites.dart';
import '../../Utilidades/formateador.dart';

class VentaFooter extends StatelessWidget {
  final Venta venta;
  final TextEditingController montoRecibidoController;
  final VoidCallback onMontoCambiado;
  final VoidCallback onProcesarCobro;
  final VoidCallback? onApartarVenta;
  final bool isLandscape;
  final bool cobrando;

  const VentaFooter({
    super.key,
    required this.venta,
    required this.montoRecibidoController,
    required this.onMontoCambiado,
    required this.onProcesarCobro,
    this.onApartarVenta,
    this.isLandscape = false,
    this.cobrando = false,
  });

  @override
  Widget build(BuildContext context) {
    // Sanitización rigurosa de comas antes de convertir a double
    final String textoLimpio =
        montoRecibidoController.text.replaceAll(',', '').trim();
    final double recibido = double.tryParse(textoLimpio) ?? 0.0;
    final double cambio = recibido - venta.total;
    final bool montoSuficiente =
        textoLimpio.isNotEmpty && recibido >= venta.total;

    final double verticalSpacing = isLandscape ? 8.0 : 12.0;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLandscape) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.point_of_sale,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Cobro en Caja',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Fila Subtotal
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              venta.aplicarIva ? 'Subtotal' : 'Total a Cobrar',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: venta.aplicarIva ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            Text(
              Formateador.moneda(venta.aplicarIva ? venta.subtotalVenta : venta.total),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),

        // Fila IVA: Solo se muestra si aplicarIva está activado
        if (venta.aplicarIva) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'IVA (${(venta.porcentajeIva * 100).toInt()}%)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                Formateador.moneda(venta.totalIva),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total neto',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                Formateador.moneda(venta.total),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: verticalSpacing),

        // Campo "$ Monto recibido"
        RepaintBoundary(
          child: Container(
            height: isLandscape ? 42 : 48,
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: montoRecibidoController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FormateadorMilesMonetario(max: LimitesApp.maxMontoMonetario),
              ],
              onChanged: (_) => onMontoCambiado(),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '\$',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                hintText: 'Monto recibido',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isLandscape ? 10 : 14,
                ),
              ),
            ),
          ),
        ),

        // Franja "Cambio a entregar" cuando se cubre el total
        if (montoSuficiente) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.onSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.attach_money,
                        size: 13,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cambio:',
                      style: TextStyle(
                        color: AppColors.onSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Formateador.moneda(cambio),
                        style: TextStyle(
                          color: AppColors.onSecondary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: verticalSpacing),

        // Botón "Procesar Cobro"
        SizedBox(
          width: double.infinity,
          height: isLandscape ? 42 : 48,
          child: ElevatedButton(
            onPressed: (venta.articulos.isEmpty || !montoSuficiente || cobrando)
                ? null
                : onProcesarCobro,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.secondarySurface,
              disabledForegroundColor: AppColors.textSecondary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: cobrando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Cobrar ${Formateador.moneda(venta.total)}',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
        if (onApartarVenta != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: isLandscape ? 36 : 40,
            child: OutlinedButton.icon(
              onPressed: (venta.articulos.isEmpty || cobrando)
                  ? null
                  : onApartarVenta,
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Apartar / Cuenta por Cobrar',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.amber,
                side: BorderSide(
                  color: AppColors.amber.withValues(alpha: 0.5),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: isLandscape
            ? Border(left: BorderSide(color: AppColors.border, width: 1))
            : Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        left: false,
        child: isLandscape
            ? SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: content,
              )
            : SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: content,
              ),
      ),
    );
  }
}
