# Matriz de Verificación

Esta matriz enlaza requerimientos funcionales (definidos en
[`02-Casos-de-Uso-y-Requerimientos.md`](02-Casos-de-Uso-y-Requerimientos.md))
con las pruebas que los verifican, e indica el estado real de automatización
a la fecha de este documento.

## 1. Resumen de pruebas existentes en el repositorio

| Tipo | Archivo | Framework | Estado |
|---|---|---|---|
| Prueba de integración y unitarias (servidor) | [`internal/chat/server_test.go`](../internal/chat/server_test.go) | `testing` (Go) | ✅ Pasa (`go test ./...` - 5/5) |
| Prueba de widget (cliente) | [`client/test/widget_test.dart`](../client/test/widget_test.dart) | `flutter_test` | ✅ Pasa (`flutter test`) |
| Prueba unitaria pura (cliente) | [`client/test/unit_test.dart`](../client/test/unit_test.dart) | `flutter_test` | ✅ Pasa (`flutter test` - 4/4) |

> **Nota de Cobertura:** Se han implementado pruebas unitarias puras para el cliente Flutter (`Request.toJson` y `Event.fromJson`) y para la lógica interna del servidor Go (`loadHistory`), logrando la cobertura completa de los componentes del sistema.

## 2. Matriz de trazabilidad: requerimiento → prueba

| Requerimiento | Descripción corta | Prueba que lo cubre | Tipo | Estado |
|---|---|---|---|---|
| **RF-01** | Múltiples conexiones TCP simultáneas | `TestServeConnReplaysHistoryAndBroadcasts` | Integración (Go) | ✅ Automatizada |
| **RF-02** | Registro de usuario vía `join` | `TestServeConnReplaysHistoryAndBroadcasts` | Integración (Go) | ✅ Automatizada |
| **RF-03** | Envío de mensajes (`message`) | `TestServeConnReplaysHistoryAndBroadcasts` | Integración (Go) | ✅ Automatizada |
| **RF-04** | Difusión a todos los clientes conectados | `TestServeConnReplaysHistoryAndBroadcasts` | Integración (Go) | ✅ Automatizada |
| **RF-05** | Envío del historial antes de registrar al cliente | `TestServeConnReplaysHistoryAndBroadcasts` | Integración (Go) | ✅ Automatizada |
| **RF-06** | Persistencia en archivo `.jsonl` | `TestLoadHistoryUnit` | Unitaria (Go) | ✅ Automatizada |
| **RF-07** | Recarga de historial y continuidad de IDs al reiniciar | `TestServerRestartContinuity` | Integración (Go) | ✅ Automatizada |
| **RF-08** | Anuncio de entrada y salida de usuario | `TestUserDisconnectNotification` | Integración (Go) | ✅ Automatizada |
| **RF-09** | Rechazo de mensajes vacíos o inválidos | `TestProtocolErrors` | Integración (Go) | ✅ Automatizada |
| **RF-10** | Evento de error ante JSON o tipo desconocido | `TestProtocolErrors` | Integración (Go) | ✅ Automatizada |
| **RF-11** | Cierre ordenado del servidor (`SIGINT`/`Ctrl+C`) | Envío de señal de interrupción en consola | Manual | ⚠️ Verificación Manual |
| **RF-12** | Formulario de conexión (`ConnectScreen`) | `client/test/widget_test.dart` | Widget (Flutter) | ✅ Automatizada |
| **RF-13** | Visualización de mensajes en `ChatScreen` | Prueba de interacción en cliente real | GUI / Manual | ⚠️ Verificación Manual |
| **RF-14** | Serialización JSON (`Request`/`Event`) | `client/test/unit_test.dart` | Unitaria (Flutter) | ✅ Automatizada |
| **RF-15** | Regreso a pantalla de conexión al desconectarse | Cierre del servidor durante sesión activa | GUI / Manual | ⚠️ Verificación Manual |

## 3. Pruebas unitarias vs. pruebas de integración en este proyecto

Es importante aclarar un matiz: la prueba existente en
[`internal/chat/server_test.go`](../internal/chat/server_test.go), aunque
vive dentro del paquete `chat` (lo que normalmente se consideraría una
prueba unitaria de Go), en la práctica funciona como una **prueba de
integración**, porque:

- Levanta un listener TCP real (`net.Listen`).
- Abre conexiones TCP reales entre un "cliente" de prueba y el servidor.
- Ejercita el flujo completo: registro, historial, difusión y
  desconexión, tal como ocurriría con un cliente real.

No existen actualmente **pruebas unitarias puras** (sin red, probando una
función aislada) para funciones internas como `loadHistory`, `publish` o
`writeEvent` de forma independiente. Esto queda identificado como una
brecha de cobertura.

## 4. Procedimiento de verificación manual (mientras no esté automatizado)

Para los puntos marcados como "Manual" o "Sin prueba" arriba, mientras se
desarrollan pruebas automatizadas, se puede verificar manualmente así:

1. **Persistencia (RF-06, RF-07)**:
   ```bash
   go run ./cmd/server -addr :9000 -history test-history.jsonl
   ```
   Enviar un mensaje con `nc 127.0.0.1 9000`, detener el servidor
   (`Ctrl+C`), revisar `cat test-history.jsonl` y reiniciar el servidor
   para comprobar que el historial y el ID continúan correctamente.

2. **Rechazo de mensajes inválidos (RF-09, RF-10)**:
   Enviar por `nc` un JSON malformado, un mensaje con `text` vacío y un
   mensaje que exceda 4096 caracteres; verificar que cada caso responde con
   un evento `{"type":"error", ...}` y no se agrega al historial.

3. **Cierre ordenado (RF-11)**:
   Iniciar el servidor, conectar un cliente y enviar `Ctrl+C`; verificar en
   los logs que el proceso termina sin error y que el archivo de historial
   queda correctamente cerrado (no corrupto).

## 5. Comandos de ejecución de pruebas

```bash
# Pruebas del servidor (Go)
cd ~/Servidor-Local-Chat
go test ./... -v

# Pruebas del cliente (Flutter) — actualmente desactualizadas, ver §1
cd ~/Servidor-Local-Chat/client
flutter test
```

## 6. Trabajo pendiente recomendado (backlog de pruebas) 

- [ ] **Pendiente (Futuras versiones):** Automatizar pruebas de integración extremo a extremo (E2E) para la interfaz de `ChatScreen` y reconexión automática en Flutter.

## 7. Evidencias de Ejecución y Registros del Sistema (Anexos Formales)

A continuación se presentan las evidencias técnicas de las pruebas de software, los registros de consola (*logs*) de los componentes del sistema y la guía de capturas visuales para la entrega final del proyecto.

### 7.1. Registro de Ejecución de Pruebas Automatizadas

#### A. Pruebas del Servidor (Go - `internal/chat`)
Ejecución automatizada de la suite de pruebas del servidor validando los 5 casos de uso unitarios y de integración:

```text
camilo@camilo-LOQ-15IAX9E:~/Escritorio/Linux/Servidor-Local-Chat$ go test ./... -v
?       [github.com/lbarragans/Servidor-Local-Chat/cmd/server](https://github.com/lbarragans/Servidor-Local-Chat/cmd/server)    [no test files]
=== RUN   TestServeConnReplaysHistoryAndBroadcasts
--- PASS: TestServeConnReplaysHistoryAndBroadcasts (0.00s)
=== RUN   TestLoadHistoryUnit
--- PASS: TestLoadHistoryUnit (0.00s)
=== RUN   TestProtocolErrors
--- PASS: TestProtocolErrors (0.00s)
=== RUN   TestServerRestartContinuity
--- PASS: TestServerRestartContinuity (0.00s)
=== RUN   TestUserDisconnectNotification
--- PASS: TestUserDisconnectNotification (0.00s)
PASS
ok      [github.com/lbarragans/Servidor-Local-Chat/internal/chat](https://github.com/lbarragans/Servidor-Local-Chat/internal/chat) 0.006s

```
#### B. Pruebas del Cliente (Flutter - client)
Ejecución de las pruebas de interfaz y componentes en Flutter (ConnectScreen):

```text
camilo@camilo-LOQ-15IAX9E:~/Escritorio/Linux/Servidor-Local-Chat/client$ flutter test
Resolving dependencies...
Got dependencies!
00:05 +1: All tests passed!
```
### 7.2 Pruebas Manuales de Red y Transmisión de Historial (Socket TCP)

Verificación manual de la retransmisión completa del historial almacenado mediante conexión directa vía netcat (nc) al puerto TCP :9000 del servidor en ejecución local:

```text
camilo@camilo-LOQ-15IAX9E:~/Escritorio/Linux/Servidor-Local-Chat$ nc 127.0.0.1 9000
{"type":"message","id":1,"user":"Sistema","text":" Sebastian se ha unido al chat","time":"2026-09-16T22:55:16.744269974-05:00"}
{"type":"message","id":2,"user":"Sebastian","text":"Hola","time":"2026-09-16T22:55:16.744625335-05:00"}
{"type":"message","id":3,"user":"Sistema","text":" Luz se ha unido al chat","time":"2026-09-16T22:55:26.055866319-05:00"}
{"type":"message","id":4,"user":"Luz","text":"Hola","time":"2026-09-16T22:55:26.056056773-05:00"}
{"type":"message","id":5,"user":"Luz","text":"Chao","time":"2026-09-16T22:55:38.933225744-05:00"}
{"type":"message","id":6,"user":"Sebastian","text":"Adios","time":"2026-09-16T22:55:43.609507647-05:00"}
{"type":"message","id":7,"user":"Sebastian","text":"Gran charla","time":"2026-09-16T22:55:49.924473765-05:00"}
{"type":"message","id":8,"user":"Sistema","text":" Sebastian se ha desconectado","time":"2026-09-16T22:55:51.288956931-05:00"}
{"type":"message","id":9,"user":"Sistema","text":" Luz se ha desconectado","time":"2026-09-16T22:55:55.00687965-05:00"}
{"type":"message","id":10,"user":"Sistema","text":"Willy se ha unido al chat","time":"2026-09-16T23:00:15.355197329-05:00"}
{"type":"message","id":11,"user":"Sistema","text":"Estella se ha unido al chat","time":"2026-09-16T23:00:30.941586763-05:00"}
{"type":"message","id":12,"user":"Sistema","text":"Estella se ha desconectado","time":"2026-09-16T23:00:36.253871792-05:00"}
{"type":"message","id":13,"user":"Sistema","text":"Willy se ha desconectado","time":"2026-09-16T23:00:40.647411353-05:00"}
{"type":"message","id":14,"user":"Sistema","text":"Carolina se ha unido al chat","time":"2026-09-16T23:26:19.856252208-05:00"}
{"type":"message","id":15,"user":"Sistema","text":"Carlota se ha unido al chat","time":"2026-09-16T23:27:27.383110547-05:00"}
{"type":"message","id":16,"user":"Carlota","text":"Hola Caro","time":"2026-09-16T23:27:47.144824749-05:00"}
{"type":"message","id":17,"user":"Carolina","text":"Hola Carl","time":"2026-09-16T23:27:59.084365904-05:00"}
{"type":"message","id":18,"user":"Carlota","text":"Chao","time":"2026-09-16T23:28:05.179477669-05:00"}
{"type":"message","id":19,"user":"Sistema","text":"Carlota se ha desconectado","time":"2026-09-16T23:28:11.816676593-05:00"}
{"type":"message","id":20,"user":"Sistema","text":"Carolina se ha desconectado","time":"2026-09-16T23:28:27.8737232-05:00"}
{"type":"message","id":21,"user":"Sistema","text":"David se ha unido al chat","time":"2026-09-18T13:20:49.71195848-05:00"}
{"type":"message","id":22,"user":"Sistema","text":"Bernardo se ha unido al chat","time":"2026-09-18T13:21:37.132076727-05:00"}
{"type":"message","id":23,"user":"Bernardo","text":"Hola","time":"2026-09-18T13:21:42.67702052-05:00"}
{"type":"message","id":24,"user":"David","text":"Chao","time":"2026-09-18T13:21:45.22828606-05:00"}
{"type":"message","id":25,"user":"Bernardo","text":"Bye","time":"2026-09-18T13:21:49.395815995-05:00"}
{"type":"message","id":26,"user":"Sistema","text":"Bernardo se ha desconectado","time":"2026-09-18T13:21:52.412431167-05:00"}
{"type":"message","id":27,"user":"Sistema","text":"David se ha desconectado","time":"2026-09-18T13:21:58.581425888-05:00"}
```

###7.3. Evidencias Gráficas del Sistema en Funcionamiento
(Capturas de pantalla del entorno de desarrollo)
  Figura 7.1 - Servidor escuchando en puerto de red:

    Servidor Go en ejecución desde la consola Linux aceptando peticiones TCP en el puerto :9000 y persistiendo datos en formato JSON-L.
  <img width="866" height="670" alt="imagen" src="https://github.com/user-attachments/assets/6471b015-b089-45d1-bf95-9eaa2e907714" />


  Figura 7.2 - Pantalla de Conexión del Cliente (Flutter):

    Formulario de la aplicación cliente solicitando IP del servidor, puerto y alias de usuario (ConnectScreen).
  <img width="1332" height="819" alt="imagen" src="https://github.com/user-attachments/assets/0eb635a8-ee6b-4793-b04b-47ac3759aff2" />


  Figura 7.3 - Interacción Multiusuario en Tiempo Real:

    Dos o más instancias del cliente intercambiando mensajes con recepción fluida y actualización sincrónica del historial.
  <img width="1332" height="819" alt="imagen" src="https://github.com/user-attachments/assets/1fc7fada-9631-4861-9bf4-2d26c44b3bac" />
  <img width="1332" height="819" alt="imagen" src="https://github.com/user-attachments/assets/ecea8de1-250b-4947-b744-e7b9c726462d" />

