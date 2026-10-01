# Descripción Funcional

| Dato | Valor |
|---|---|
| Materia | Programación de sistemas Linux embebidos |
| Docente | Juan Bernardo Gómez |
| Periodo académico | 2026-02 |

## 1. Propósito del proyecto

**Servidor Local de Chat** es un sistema cliente-servidor para la materia
**Programación de sistemas linux embebidos**. Permite que varios usuarios conectados a una
misma red local conversen en tiempo real y recuperen el historial de
mensajes, incluso si no estuvieron conectados cuando se escribieron.

El proyecto tiene dos componentes:

- **Servidor** (Go): proceso que escucha conexiones TCP, gestiona el
  historial y difunde mensajes a todos los clientes conectados.
  Código: [`cmd/server/main.go`](../cmd/server/main.go) y
  [`internal/chat/server.go`](../internal/chat/server.go).
- **Cliente** (Flutter): aplicación de escritorio que se conecta al
  servidor, envía mensajes y muestra la conversación.
  Código: [`client/lib/main.dart`](../client/lib/main.dart).

## 2. Alcance actual (lo que el sistema hace hoy)

- Permite que un cliente se identifique con un nombre de usuario (`join`).
- Permite enviar mensajes de texto (`message`).
- Difunde cada mensaje nuevo a todos los clientes conectados en ese momento.
- Envía automáticamente el historial completo a cualquier cliente que se
  conecte.
- Persiste cada mensaje en un archivo `chat-history.jsonl`, en disco, en el
  equipo donde corre el servidor.
- Notifica en el chat cuando un usuario se conecta o se desconecta
  (mensajes generados por el propio servidor, con el usuario `"Sistema"`).
- Valida que los mensajes no estén vacíos y no superen una longitud máxima
  (4096 caracteres).
- Responde con un evento de error ante solicitudes inválidas (JSON mal
  formado, usuario vacío, texto vacío, texto demasiado largo o tipo de
  solicitud desconocido).
- Cierra ordenadamente el servidor ante `Ctrl+C` (`SIGINT`) o `SIGTERM`.

## 3. Fuera de alcance actual (posible alcance futuro)

Estas funcionalidades **no** están implementadas todavía en el código, pero
son candidatas a desarrollarse en una siguiente entrega del proyecto:

- Autenticación o contraseñas de usuario.
- Cifrado de la comunicación (el protocolo viaja en texto plano sobre TCP).
- Edición o borrado de mensajes ya enviados.
- Límite de usuarios conectados simultáneamente.
- Persistencia en una base de datos (actualmente es un archivo de texto
  plano `.jsonl`).

> Ninguno de estos puntos está descartado; simplemente no forman parte del
> alcance entregado hasta ahora. A medida que se implemente alguno, debe
> moverse de esta lista a la sección 2 ("Alcance actual").

## 4. Protocolo de comunicación

El cliente y el servidor intercambian una línea de texto JSON por cada
solicitud o evento, separada por salto de línea (`\n`).

### Solicitudes del cliente al servidor

Identificarse en el chat:

```json
{"type":"join","user":"camilo"}
```

Enviar un mensaje:

```json
{"type":"message","user":"camilo","text":"Hola a todos"}
```

### Eventos del servidor al cliente

Mensaje de chat (incluye los del historial y los nuevos):

```json
{"type":"message","id":1,"user":"camilo","text":"Hola a todos","time":"2026-09-17T05:30:00Z"}
```

Error de protocolo:

```json
{"type":"error","text":"a message requires text"}
```

## 5. Actores del sistema

| Actor | Descripción |
|---|---|
| Usuario del chat | Persona que usa el cliente Flutter para enviar y leer mensajes. |
| Servidor | Proceso Go que coordina la comunicación y guarda el historial. |
| Administrador del servidor | Persona que inicia/detiene el proceso del servidor y gestiona el archivo de historial. |

## 6. Integrantes del equipo y roles

| Integrante | Rol / componente a cargo |
|---|---|
| David Henao Rojas | Servidor (Go) |
| Juan Camilo Giraldo | Cliente (Flutter) |
| Daniela Barragán | Cliente (Flutter) |

## 7. Información pendiente por parte del equipo

El contexto académico y de equipo (materia, docente, periodo, integrantes y
roles) ya quedó documentado en las secciones anteriores. Queda pendiente
únicamente:

1. Confirmar si alguno de los puntos de la sección 3 ("Fuera de alcance
   actual") pasa a desarrollarse en esta entrega, para moverlo a la sección
   2 ("Alcance actual").
