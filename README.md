# Servidor Local de Chat

Servidor de chat multihilo desarrollado en **Go** para la materia **Sistemas Embebidos Linux**. Permite la comunicación en tiempo real entre múltiples clientes conectados a una red local mediante sockets TCP y un protocolo de intercambio basado en JSON.

---

## 🚀 Características

* **Conexión TCP Concurrente:** Manejo de múltiples clientes en simultáneo utilizando *goroutines*.
* **Persistencia Histórica:** Guardado automático de mensajes en formato `.jsonl` (`chat-history.jsonl`).
* **Sincronización Automática:** Transmisión del historial acumulado a cada nuevo cliente al momento de conectarse.
* **Difusión en Tiempo Real (Broadcast):** Envío instantáneo de mensajes entrantes a todos los clientes activos.
* **Control de Concurrencia:** Uso de cerrojos (`sync.Mutex`) para garantizar la integridad de los datos en memoria y disco.
* **Cierre Limpio (Graceful Shutdown):** Captura de señales del sistema (`SIGINT`, `SIGTERM`) para cerrar sockets y archivos de forma segura.

---

## 📁 Estructura del Proyecto

```text
.
├── client
|      └── ...
├── cmd/
│   └── server/
│       └── main.go         # Punto de entrada del servidor
├── internal/
│   └── chat/
│       ├── server.go       # Lógica del servidor, broadcast y persistencia
│       └── server-test.go  # Pruebas unitarias de integración
├── go.mod                  # Configuración de módulos en Go
└── README.md               # Documentación del proyecto

```
---

## 🛠️ Requisitos Previos
* Sistema Operativo Linux (o entorno compatible con POSIX).
* Go (versión 1.22 o superior recomendada).

---

## ⚙️ Uso y Ejecución
1. Iniciar el Servidor

Para iniciar el servidor con los parámetros por defecto (puerto :9000 e historial chat-history.jsonl):

```bash

go run ./cmd/server/main.go

```

##Banderas de configuración opcionales:
  Puedes personalizar el puerto de escucha y la ruta del archivo de historial usando banderas:

  ```bash

  go run ./cmd/server/main.go -addr ":8080" -history "mi-historial.jsonl"

  ```

2. Ejecutar Pruebas Automatizadas

Para validar que la lógica de retransmisión e historial funciona correctamente:

```bash

go test ./...

```

## 📡 Protocolo de Comunicación (JSON sobre TCP)

La comunicación cliente-servidor se realiza enviando registros delimitados por salto de línea (\n).


###Envío desde el Cliente (Petición):

```json
{
  "type": "message",
  "user": "camilo",
  "text": "Hola a todos"
}
```

###Respuesta/Difusión del Servidor (Evento):

```json
{
  "type": "message",
  "id": 1,
  "user": "camilo",
  "text": "Hola a todos",
  "time": "2026-09-17T05:30:00Z"
}
```

En caso de un error en la solicitud, el servidor devolverá:

```json
{
  "type": "error",
  "text": "un mensaje requiere type, user y text"
}
```
