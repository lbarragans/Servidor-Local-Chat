import 'package:client/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Muestra la pantalla principal de CDD Connect', (
    WidgetTester tester,
  ) async {
    // Simula una ventana de escritorio.
    await tester.binding.setSurfaceSize(const Size(1200, 800));

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    // Construye la aplicación.
    await tester.pumpWidget(const ChatApp());

    // Permite que LayoutBuilder, assets y demás widgets
    // terminen de construir la pantalla.
    await tester.pumpAndSettle();

    expect(find.text('CDD Connect'), findsOneWidget);

    expect(find.text('Chat local · Sistemas Embebidos Linux'), findsOneWidget);

    expect(find.text('Dirección IP del servidor'), findsOneWidget);

    expect(find.text('Puerto'), findsOneWidget);

    expect(find.text('Tu nombre'), findsOneWidget);

    expect(find.text('Entrar al chat'), findsOneWidget);

    expect(find.text('Universidad Nacional de Colombia'), findsOneWidget);
  });
}
