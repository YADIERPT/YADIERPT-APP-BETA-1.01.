import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/Servicios/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NotificationService: Se instancia como singleton y define constantes de canal prioritario', () {
    final service = NotificationService.instancia;
    expect(service, isNotNull);
    expect(NotificationService.canalAlertasId, equals('canal_alertas_stock'));
    expect(NotificationService.canalAlertasStock.importance.value, greaterThanOrEqualTo(4));
  });

  test('NotificationService: Inicialización defensiva no arroja excepciones en entorno de pruebas', () async {
    final service = NotificationService.instancia;
    await service.inicializar(solicitarPermisosAutomatico: false);
    expect(service.estaInicializado, isTrue);
  });
}

