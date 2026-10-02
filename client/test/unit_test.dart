import 'package:flutter_test/flutter_test.dart';
import 'package:client/main.dart';

void main() {
  group('Pruebas Unitarias de Modelos del Cliente (Request & Event)', () {
    test('Request.toJson() serializa correctamente una solicitud de tipo join', () {
      final req = Request(type: 'join', user: 'Camilo');
      final json = req.toJson();

      expect(json['type'], equals('join'));
      expect(json['user'], equals('Camilo'));
      expect(json.containsKey('text'), isFalse);
    });

    test('Request.toJson() serializa correctamente un mensaje de texto', () {
      final req = Request(type: 'message', user: 'Camilo', text: 'Hola a todos');
      final json = req.toJson();

      expect(json['type'], equals('message'));
      expect(json['user'], equals('Camilo'));
      expect(json['text'], equals('Hola a todos'));
    });

    test('Event.fromJson() deserializa correctamente un evento enviado por el servidor', () {
      final rawJson = {
        'type': 'message',
        'id': 1,
        'user': 'Sebastian',
        'text': 'Hola',
        'time': '2026-09-16T22:55:16.744Z'
      };

      final event = Event.fromJson(rawJson);

      expect(event.type, equals('message'));
      expect(event.id, equals(1));
      expect(event.user, equals('Sebastian'));
      expect(event.text, equals('Hola'));
      expect(event.time, isNotNull);
    });

    test('Event.fromJson() maneja correctamente valores nulos o por defecto', () {
      final rawJson = <String, dynamic>{};

      final event = Event.fromJson(rawJson);

      expect(event.type, equals(''));
      expect(event.id, isNull);
      expect(event.user, equals('Sistema'));
      expect(event.text, equals(''));
      expect(event.time, isNull);
    });
  });
}