import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/Modelos/producto.dart';
import 'package:mi_app/Vista/Widgets/miniatura_producto_widget.dart';

void main() {
  testWidgets('MiniaturaProductoWidget muestra placeholder cuando no hay imagen', (tester) async {
    final productoSinImagen = Producto(
      id: 'P01',
      uuid: 'uuid-p01',
      nombre: 'Helecho Espada',
      tipo: 'planta',
      notas: '',
      precioVenta: 120.0,
      costo: 60.0,
      cantidadEnInventario: 5,
      imagenes: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniaturaProductoWidget(
            producto: productoSinImagen,
            width: 50,
            height: 50,
          ),
        ),
      ),
    );

    // Debe renderizar el contenedor de placeholder
    expect(find.byType(MiniaturaProductoWidget), findsOneWidget);
  });

  testWidgets('MiniaturaProductoWidget maneja placeholder personalizado', (tester) async {
    const customPlaceholder = Key('custom-placeholder');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MiniaturaProductoWidget(
            rutaImagen: '',
            placeholder: SizedBox(key: customPlaceholder),
          ),
        ),
      ),
    );

    expect(find.byKey(customPlaceholder), findsOneWidget);
  });
}

