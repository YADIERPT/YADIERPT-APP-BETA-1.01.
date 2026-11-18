import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/Controladores/controlador_inventario.dart';
import 'package:mi_app/Modelos/producto.dart';
import 'package:mi_app/Vista/Widgets/ajuste_stock_sheet.dart';

void main() {
  testWidgets('AjusteStockSheet: Renderiza alerta de Umbral de Stock Crítico en Modo Claro y Oscuro', (tester) async {
    final prod = Producto(
      id: 'P-01',
      uuid: 'uuid-01',
      nombre: 'Monstera Deliciosa',
      precioVenta: 200,
      costo: 100,
      cantidadEnInventario: 5,
      umbralStockCritico: 3,
    );
    final cInv = ControladorInventario();

    // 1. Modo Claro
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: AjusteStockSheet(
            producto: prod,
            controladorInventario: cInv,
            onActualizado: () {},
          ),
        ),
      ),
    );

    expect(find.text('Umbral de Stock Crítico'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // 2. Modo Oscuro
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: AjusteStockSheet(
            producto: prod,
            controladorInventario: cInv,
            onActualizado: () {},
          ),
        ),
      ),
    );

    expect(find.text('Umbral de Stock Crítico'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}

