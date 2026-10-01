# Casos de Uso, Historias de Usuario y Requerimientos del Sistema

## 1. Historias de usuario

### HU-01 — Conectarme al chat con mi nombre

> Como usuario, quiero conectarme al servidor indicando su IP, puerto y mi
> nombre, para poder identificarme ante los demás participantes del chat.

**Criterios de aceptación**
- El cliente solicita IP, puerto y nombre de usuario antes de conectar.
- Si falta IP o nombre de usuario, el cliente muestra un aviso y no
  intenta conectar.
- Al conectar exitosamente, el cliente envía automáticamente una solicitud
  `join` con el nombre ingresado.
- Si la conexión falla (tiempo de espera agotado, host inaccesible, etc.),
  el cliente muestra el error y permanece en la pantalla de conexión.

Código relacionado: `_ConnectScreenState._connect` en
[`client/lib/main.dart`](../client/lib/main.dart).

### HU-02 — Ver el historial de mensajes al conectarme

> Como usuario, quiero ver los mensajes que se escribieron mientras no
> estaba conectado, para no perder el contexto de la conversación.

**Criterios de aceptación**
- Al conectarse, el cliente recibe todos los mensajes guardados
  previamente, antes de recibir mensajes nuevos.
- Los mensajes del historial se muestran en el mismo orden en que fueron
  enviados originalmente.

Código relacionado: `Server.register` y `Server.loadHistory` en
[`internal/chat/server.go`](../internal/chat/server.go).

### HU-03 — Enviar mensajes en tiempo real

> Como usuario, quiero escribir un mensaje y que todos los demás
> conectados lo vean inmediatamente, para poder conversar en tiempo real.

**Criterios de aceptación**
- Al enviar un mensaje no vacío, todos los clientes conectados lo reciben
  sin necesidad de recargar o reconectar.
- Los mensajes vacíos no se envían ni se muestran.
- Un mensaje que supera el límite de caracteres es rechazado con un
  mensaje de error.

Código relacionado: `Server.publish` en
[`internal/chat/server.go`](../internal/chat/server.go) y `_sendMessage` en
[`client/lib/main.dart`](../client/lib/main.dart).

### HU-04 — Enterarme cuando alguien entra o sale del chat

> Como usuario, quiero ver avisos cuando alguien se conecta o se
> desconecta, para saber quién está participando en la conversación.

**Criterios de aceptación**
- Al identificarse por primera vez con `join`, se publica un mensaje del
  sistema anunciando el ingreso.
- Al cerrarse una conexión previamente identificada, se publica un mensaje
  del sistema anunciando la salida.

Código relacionado: caso `"join"` dentro de `Server.ServeConn` y
`Server.unregister` en [`internal/chat/server.go`](../internal/chat/server.go).

### HU-05 — Persistencia del historial en el servidor

> Como administrador del servidor, quiero que los mensajes queden guardados
> en disco, para que el historial sobreviva a un reinicio del servidor.

**Criterios de aceptación**
- Cada mensaje se escribe en el archivo de historial inmediatamente después
  de ser recibido.
- Al reiniciar el servidor, el historial anterior se recarga y continúa la
  numeración de identificadores sin reutilizarlos.

Código relacionado: `Server.loadHistory` y `Server.publish` en
[`internal/chat/server.go`](../internal/chat/server.go).

### HU-06 — Recibir un aviso claro ante un error

> Como usuario, quiero que el sistema me informe si mi solicitud fue
> inválida, para poder corregirla.

**Criterios de aceptación**
- El servidor responde con un evento `error` indicando el motivo
  (JSON inválido, usuario vacío, texto vacío, texto muy largo o tipo de
  solicitud desconocido).
- El cliente muestra ese error en pantalla sin desconectar al usuario.

## 2. Requerimientos funcionales (RF)

| ID | Requerimiento |
|---|---|
| RF-01 | El servidor debe aceptar múltiples conexiones TCP simultáneas. |
| RF-02 | El servidor debe registrar la identidad del usuario mediante una solicitud `join`. |
| RF-03 | El servidor debe aceptar mensajes de texto (`message`) asociados a un usuario. |
| RF-04 | El servidor debe difundir cada mensaje nuevo a todos los clientes conectados. |
| RF-05 | El servidor debe enviar el historial completo a un cliente apenas se conecta, antes de registrar la conexión. |
| RF-06 | El servidor debe persistir cada mensaje en un archivo de historial en disco. |
| RF-07 | El servidor debe recargar el historial existente al iniciar y continuar la numeración de IDs sin duplicarlos. |
| RF-08 | El servidor debe anunciar en el chat la entrada y la salida de un usuario identificado. |
| RF-09 | El servidor debe rechazar mensajes vacíos o que excedan el límite de longitud. |
| RF-10 | El servidor debe responder con un evento de error ante una solicitud inválida, sin cerrar la conexión. |
| RF-11 | El servidor debe cerrarse de forma ordenada (cerrando conexiones y el archivo) al recibir `SIGINT` o `SIGTERM`. |
| RF-12 | El cliente debe permitir ingresar IP, puerto y nombre de usuario antes de conectarse. |
| RF-13 | El cliente debe mostrar el historial y los mensajes nuevos en una misma vista de conversación. |
| RF-14 | El cliente debe distinguir visualmente los mensajes propios, los de otros usuarios y los del sistema. |
| RF-15 | El cliente debe notificar al usuario y regresar a la pantalla de conexión si el servidor cierra la conexión. |

## 3. Requerimientos no funcionales (RNF)

| ID | Requerimiento |
|---|---|
| RNF-01 | El servidor debe estar escrito en Go y ejecutarse en Linux (compatible con sistemas embebidos basados en Linux). |
| RNF-02 | El acceso concurrente al estado compartido del servidor (historial, lista de clientes, contador de IDs) debe protegerse con mecanismos de exclusión mutua. |
| RNF-03 | El protocolo de comunicación debe ser texto plano, legible y basado en JSON, para facilitar depuración e interoperabilidad. |
| RNF-04 | El límite de longitud de un mensaje debe calcularse en caracteres Unicode, no en bytes, para soportar tildes y otros caracteres multibyte. |
| RNF-05 | El cliente debe funcionar como aplicación de escritorio Flutter (Linux/Windows) usando sockets TCP directos. |

## 4. Información pendiente por parte del equipo

Para completar esta sección, el equipo debería definir y aportar:

1. **Requerimientos de desempeño**: por ejemplo, cantidad esperada de
   usuarios simultáneos. Actualmente el código no impone un
   límite de clientes conectados aunque el docente nos comentó de un límite de máximo 10 personas simultáneas.
2. **Requerimientos de seguridad**: si se van a agregar (por ejemplo,
   autenticación de usuarios, cifrado de la conexión). Hasta el momento, el sistema no
   implementa ninguno de los dos.
