import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/main.dart'; // Asegúrate de importar tu main.dart

void main() {
  testWidgets('Verifica que ConnectScreen muestra los campos de IP, Puerto y Usuario', (WidgetTester tester) async {
    // Carga la aplicación real
    await tester.pumpWidget(const ChatApp());

    // Verifica que existan los campos de texto
    expect(find.text('Dirección IP del servidor'), findsOneWidget);
    expect(find.text('Puerto'), findsOneWidget);
    expect(find.text('Nombre de Usuario'), findsOneWidget);

    // Verifica que existe el botón de conectar
    expect(find.widgetWithText(ElevatedButton, 'Conectar'), findsOneWidget);
  });
}