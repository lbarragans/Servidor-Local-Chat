# Servidor Local de Chat

Servidor de chat para la materia **Sistemas Embebidos Linux**. El objetivo es
permitir que varios clientes dentro de una red local conversen en tiempo real y
reciban el historial existente al conectarse.

## Estado actual

Esta rama contiene la primera base del servidor:

- TCP sobre la red local.
- Protocolo JSON delimitado por saltos de línea.
- Historial persistente en `chat-history.jsonl`.
- Reenvío de mensajes a todos los clientes conectados.
- Reproducción del historial al conectar un cliente nuevo.

Un cliente envía:

```json
{"type":"message","user":"ana","text":"Hola"}
```

El servidor entrega eventos con este formato:

```json
{"type":"message","id":1,"user":"ana","text":"Hola","time":"2026-09-16T21:00:00Z"}
```

## Ejecutar

Requiere Go 1.22 o posterior:

```bash
go run ./cmd/server -addr :9000 -history chat-history.jsonl
```

Por defecto escucha en el puerto TCP `9000`. Para aceptar conexiones desde
otros equipos de la red, usa la IP del equipo servidor en el cliente, por
ejemplo `192.168.1.20:9000`.

## Probar

```bash
go test ./...
```

El cliente y la definición final del protocolo se integrarán en pasos
posteriores.

Hola
