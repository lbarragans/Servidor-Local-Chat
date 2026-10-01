# Matriz de Verificación

Esta matriz enlaza requerimientos funcionales (definidos en
[`02-Casos-de-Uso-y-Requerimientos.md`](02-Casos-de-Uso-y-Requerimientos.md))
con las pruebas que los verifican, e indica el estado real de automatización
a la fecha de este documento.

## 1. Resumen de pruebas existentes en el repositorio

| Tipo | Archivo | Framework | Estado |
|---|---|---|---|
| Prueba de integración (servidor) | [`internal/chat/server_test.go`](../internal/chat/server_test.go) | `testing` (Go) | ✅ Pasa (`go test ./...`) |
| Prueba de widget (cliente) | [`client/test/widget_test.dart`](../client/test/widget_test.dart) | `flutter_test` | ⚠️ Desactualizada: es la plantilla por defecto de `flutter create` y prueba una clase `MyApp` que ya no existe en [`client/lib/main.dart`](../client/lib/main.dart) (la app real se llama `ChatApp`). No valida la lógica de chat. |

> No existen todavía pruebas unitarias puras para el cliente Flutter (por
> ejemplo, para `Request.toJson` o `Event.fromJson`), ni pruebas de
> integración extremo a extremo que levanten el cliente real contra el
> servidor real.

## 2. Matriz de trazabilidad: requerimiento → prueba

| Requerimiento | Descripción corta | Prueba que lo cubre | Tipo | Estado |
|---|---|---|---|---|
| RF-01 | Múltiples conexiones TCP simultáneas | `TestServeConnReplaysHistoryAndBroadcasts` (dos conexiones concurrentes) | Integración | ✅ Automatizada |
| RF-02 | Registro de usuario vía `join` | `TestServeConnReplaysHistoryAndBroadcasts` (envía `join`, valida evento `"Sistema"`) | Integración | ✅ Automatizada |
| RF-03 | Envío de mensajes (`message`) | `TestServeConnReplaysHistoryAndBroadcasts` (envía `"hola"` y `"adios"`) | Integración | ✅ Automatizada |
| RF-04 | Difusión a todos los clientes conectados | `TestServeConnReplaysHistoryAndBroadcasts` (el segundo cliente recibe el mensaje del primero) | Integración | ✅ Automatizada |
| RF-05 | Envío del historial antes de registrar al cliente | `TestServeConnReplaysHistoryAndBroadcasts` (el segundo cliente recibe eventos previos al conectarse) | Integración | ✅ Automatizada |
| RF-06 | Persistencia en archivo `.jsonl` | Verificado manualmente (ver §4); no hay aserción automática sobre el contenido del archivo | Manual | ⚠️ Pendiente de automatizar |
| RF-07 | Recarga de historial y continuidad de IDs al reiniciar | No hay prueba automatizada que reinicie `New()` sobre el mismo archivo con datos previos | — | ❌ Sin prueba |
| RF-08 | Anuncio de entrada/salida de usuario | `TestServeConnReplaysHistoryAndBroadcasts` cubre el anuncio de entrada (`join`); no cubre el anuncio de salida (desconexión) | Integración | ⚠️ Cobertura parcial |
| RF-09 | Rechazo de mensajes vacíos o demasiado largos | No hay prueba automatizada para estos casos | — | ❌ Sin prueba |
| RF-10 | Evento de error ante solicitud inválida | No hay prueba automatizada para JSON inválido, usuario vacío o tipo desconocido | — | ❌ Sin prueba |
| RF-11 | Cierre ordenado ante `SIGINT`/`SIGTERM` | No hay prueba automatizada (requiere probar `cmd/server/main.go`, no solo el paquete `chat`) | — | ❌ Sin prueba |
| RF-12 | Formulario de conexión (IP, puerto, usuario) | No hay prueba de widget actualizada para `ConnectScreen` | — | ❌ Sin prueba |
| RF-13 | Visualización de historial y mensajes nuevos | No hay prueba de widget actualizada para `ChatScreen` | — | ❌ Sin prueba |
| RF-14 | Distinción visual de mensajes propio/ajeno/sistema | No hay prueba automatizada | — | ❌ Sin prueba |
| RF-15 | Regreso a pantalla de conexión al perder conexión | No hay prueba automatizada | — | ❌ Sin prueba |

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

1. Reemplazar [`client/test/widget_test.dart`](../client/test/widget_test.dart)
   por pruebas reales de `ConnectScreen` y `ChatScreen`.
2. Agregar pruebas unitarias puras en Go para `loadHistory` (archivo con
   datos previos, archivo vacío, archivo corrupto) sin pasar por la red.
3. Agregar pruebas para los casos de error de protocolo (RF-09, RF-10).
4. Agregar una prueba que reinicie el servidor sobre el mismo archivo de
   historial para validar RF-07 automáticamente.
5. Agregar una prueba que valide el anuncio de salida de usuario
   (RF-08, parte de desconexión).

## 7. Información pendiente por parte del equipo

Información que falta para completar el documento:

1. Evidencias de pruebas manuales ya realizadas (capturas de pantalla,
   registros de las pruebas de red descritas en conversaciones previas del
   proyecto) que se quieran anexar como evidencia formal.
