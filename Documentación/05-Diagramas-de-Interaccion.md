# Diagramas de Interacción

Este documento complementa a [`03-Arquitectura.md`](03-Arquitectura.md) con
**diagramas de secuencia** (diagramas de interacción) que muestran, paso a
paso, cómo se comunican el **Cliente (Flutter)** y el **Servidor (Go)** para
cada operación principal del chat. Cada diagrama está acompañado de una
referencia al código fuente donde ocurre cada paso.

## 1. Conexión e identificación de un usuario (`join`)

```mermaid
sequenceDiagram
    actor U as Usuario
    participant C as Cliente (ConnectScreen)
    participant S as Servidor (ServeConn)
    participant H as chat-history.jsonl

    U->>C: Ingresa IP, puerto y nombre de usuario
    C->>S: Socket.connect(ip, puerto)
    S->>S: register(client)
    S->>H: Lee historial existente
    S-->>C: Reenvía cada evento del historial
    C->>S: {"type":"join","user":"..."}
    S->>S: Marca client.user y detecta primer join
    S->>S: publish("Sistema", "X se ha unido al chat")
    S-->>C: {"type":"message","user":"Sistema","text":"X se ha unido al chat"}
    C->>C: Navigator.pushReplacement a ChatScreen
```

Código relacionado: `_connect` en
[`client/lib/main.dart`](../client/lib/main.dart), y
`Server.register`/`Server.ServeConn` (caso `"join"`) en
[`internal/chat/server.go`](../internal/chat/server.go).

## 2. Envío de un mensaje y difusión (broadcast)

```mermaid
sequenceDiagram
    actor U1 as Usuario A
    participant CA as Cliente A
    participant S as Servidor (publish)
    participant H as chat-history.jsonl
    participant CB as Cliente B
    actor U2 as Usuario B

    U1->>CA: Escribe texto y presiona enviar
    CA->>S: {"type":"message","user":"A","text":"..."}
    S->>S: Valida texto no vacío y longitud máxima
    S->>S: nextID++, crea Event
    S->>H: Escribe el evento como línea JSON
    S->>CA: Reenvía el Event (confirmación)
    S->>CB: Reenvía el Event (difusión)
    CA->>U1: Muestra el mensaje en la lista
    CB->>U2: Muestra el mensaje en la lista
```

Código relacionado: `_sendMessage` en
[`client/lib/main.dart`](../client/lib/main.dart), y `Server.publish` en
[`internal/chat/server.go`](../internal/chat/server.go).

## 3. Reenvío de historial a un cliente que se conecta tarde

```mermaid
sequenceDiagram
    actor U as Usuario (llega tarde)
    participant C as Cliente
    participant S as Servidor (register)

    Note over S: El historial ya contiene mensajes<br/>enviados mientras U no estaba conectado
    C->>S: Socket.connect(ip, puerto)
    S->>S: register(client) toma el mutex
    loop por cada evento guardado en memoria
        S-->>C: Event histórico (type: "message")
    end
    S->>S: Agrega el cliente al mapa de clientes conectados
    C->>C: Pinta cada evento recibido en la lista de mensajes
    Note over C,S: Solo después de esto el cliente<br/>empieza a recibir mensajes nuevos en vivo
```

Código relacionado: `Server.register` en
[`internal/chat/server.go`](../internal/chat/server.go) (el historial se
envía **antes** de agregar el cliente al mapa `clients`, para evitar que se
pierda o se duplique algún mensaje concurrente).

## 4. Manejo de una solicitud inválida

```mermaid
sequenceDiagram
    actor U as Usuario
    participant C as Cliente
    participant S as Servidor (ServeConn)

    U->>C: Envía un mensaje vacío o demasiado largo
    C->>S: {"type":"message","user":"A","text":""}
    S->>S: strings.TrimSpace(text) == ""
    S-->>C: {"type":"error","text":"a message requires text"}
    C->>U: Muestra SnackBar "⚠️ Error: ..."
```

Este mismo patrón aplica para JSON mal formado, usuario vacío, texto que
excede `maxMessageLength` y tipos de solicitud desconocidos. En todos los
casos el servidor responde con un evento `"error"` y continúa esperando la
siguiente línea (no cierra la conexión).

Código relacionado: bloque `switch request.Type` dentro de
`Server.ServeConn` en [`internal/chat/server.go`](../internal/chat/server.go),
y el manejo de `event.type == 'error'` en `_listenSocket` de
[`client/lib/main.dart`](../client/lib/main.dart).

## 5. Desconexión de un usuario

```mermaid
sequenceDiagram
    actor U as Usuario
    participant C as Cliente
    participant S as Servidor
    participant O as Otros clientes conectados

    alt Cierre intencional (cierra la app / pierde la red)
        C->>S: Cierra el socket TCP
    else El servidor se detiene (Ctrl+C / SIGTERM)
        S->>C: Cierra la conexión
    end
    S->>S: scanner.Scan() retorna false, termina el bucle
    S->>S: unregister(client) (defer)
    S->>S: Elimina al cliente del mapa clients
    alt El cliente ya se había identificado (join)
        S->>S: publish("Sistema", "X se ha desconectado")
        S-->>O: {"type":"message","user":"Sistema","text":"X se ha desconectado"}
    end
    C->>U: onDone/onError -> _handleDisconnect()
    C->>C: Vuelve a ConnectScreen
```

Código relacionado: `defer s.unregister(client)` en `Server.ServeConn` y
`Server.unregister` en [`internal/chat/server.go`](../internal/chat/server.go),
y `onDone`/`onError`/`_handleDisconnect` en
[`client/lib/main.dart`](../client/lib/main.dart).

## 6. Relación con los demás diagramas del proyecto

- Los **callgraphs** ([`docs/server-callgraph.md`](../docs/server-callgraph.md)
  y [`docs/client-callgraph.md`](../docs/client-callgraph.md)) muestran qué
  función llama a qué función **dentro** de cada componente.
- Los diagramas de este documento muestran, en cambio, el **intercambio de
  mensajes entre el cliente y el servidor a través de la red**, es decir, la
  interacción observable desde afuera del proceso.
- El diagrama de topología de despliegue en
  [`03-Arquitectura.md`](03-Arquitectura.md) complementa esta vista
  mostrando dónde corre cada componente físicamente.

## 7. Información pendiente por parte del equipo

1. Confirmar si se requiere un diagrama de interacción adicional para algún
   caso de uso específico pedido por el docente que no esté cubierto aquí.
