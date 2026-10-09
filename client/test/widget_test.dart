import 'package:client/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Muestra la pantalla principal de CDD Connect', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const ChatApp());

    await tester.pumpAndSettle();

    expect(find.text('CDD Connect'), findsOneWidget);

    expect(find.text('Chat local corporativo'), findsOneWidget);

    expect(find.text('Sistemas Embebidos Linux'), findsWidgets);

    expect(find.text('Dirección IP del servidor'), findsOneWidget);

    expect(find.text('Puerto'), findsOneWidget);

    expect(find.text('Tu nombre'), findsOneWidget);

    expect(find.text('Entrar al chat'), findsOneWidget);

    expect(find.text('Equipo CDD'), findsOneWidget);

    expect(find.text('Camilo  •  Daniela  •  David'), findsOneWidget);

    expect(
      find.text('Proyecto académico · Universidad Nacional de Colombia'),
      findsOneWidget,
    );
  });
}
