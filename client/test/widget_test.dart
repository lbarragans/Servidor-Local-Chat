import 'package:flutter_test/flutter_test.dart';
import 'package:client/main.dart';

void main() {
  testWidgets('Muestra pantalla de conexión del chat',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ChatApp());

    expect(find.text('Ingreso al Chat'), findsOneWidget);
    expect(find.text('Dirección IP del servidor'), findsOneWidget);
    expect(find.text('Puerto'), findsOneWidget);
    expect(find.text('Nombre de Usuario'), findsOneWidget);
    expect(find.text('Conectar'), findsOneWidget);
  });
}