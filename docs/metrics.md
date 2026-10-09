# Métricas de rendimiento de CDD Connect

CDD Connect incorpora un panel de monitorización que permite observar en tiempo real el comportamiento de la comunicación cliente-servidor y el consumo de recursos del servidor.

Las métricas implementadas son:

- Latencia.
- Jitter.
- Uso de CPU del servidor.
- Memoria utilizada por el servidor.
- Usuarios conectados.
- Mensajes recibidos por el cliente.

> Los rangos presentados en este documento son valores de referencia orientativos para un servidor de chat TCP ejecutado en una red local (LAN o hotspot). No representan límites normativos ni un SLA.

---

## 1. Latencia

La latencia representa el tiempo de ida y vuelta de una petición entre el cliente y el servidor.

CDD Connect utiliza mensajes de control `ping` y `pong`.

El cliente registra el instante en que envía el `ping` y calcula el tiempo transcurrido cuando recibe el `pong` correspondiente.

La métrica mostrada corresponde aproximadamente a:

\[
RTT = t_{recepcion} - t_{envio}
\]

y se expresa en milisegundos.

### Valores orientativos

| Latencia RTT | Interpretación |
|---:|---|
| < 10 ms | Excelente para una red local |
| 10 - 30 ms | Muy buena |
| 30 - 60 ms | Buena / aceptable |
| 60 - 100 ms | Retardo perceptible, pero utilizable |
| > 100 ms | Conviene revisar la red |
| > 200 ms | Experiencia degradada para chat interactivo |

En una ejecución sobre el mismo computador mediante `127.0.0.1`, es normal observar valores muy inferiores a los obtenidos entre dos computadores conectados mediante Wi-Fi o hotspot.

---

## 2. Jitter

El jitter representa la variación de la latencia entre mediciones consecutivas.

En CDD Connect se calcula como:

\[
J_i = |RTT_i - RTT_{i-1}|
\]

Por esta razón, un jitter pequeño indica que el tiempo de respuesta de la red es estable.

### Valores orientativos

| Jitter | Interpretación |
|---:|---|
| < 5 ms | Excelente estabilidad |
| 5 - 15 ms | Buena estabilidad |
| 15 - 30 ms | Aceptable |
| 30 - 50 ms | Variación considerable |
| > 50 ms | Red inestable o congestionada |

Para un chat basado en texto, el jitter es menos crítico que en aplicaciones de voz o video, pero continúa siendo útil para evaluar la estabilidad de la red local.

---

## 3. CPU del servidor

Esta métrica representa el porcentaje de tiempo de procesador utilizado por el proceso Go correspondiente al servidor.

CDD Connect obtiene el tiempo de CPU consumido por el proceso y lo compara con el tiempo real transcurrido entre muestras.

El resultado mostrado en la interfaz corresponde al consumo del **servidor Go**, no al consumo total del computador cliente.

### Valores orientativos

| CPU del servidor | Interpretación |
|---:|---|
| 0 - 5 % | Excelente en reposo o baja carga |
| 5 - 20 % | Normal |
| 20 - 40 % | Carga moderada |
| 40 - 70 % | Carga elevada |
| > 70 % sostenido | Conviene investigar saturación |
| Cercano a 100 % sostenido | Posible cuello de botella de CPU |

Un valor momentáneo alto no necesariamente representa un problema. Lo importante es observar si el consumo permanece elevado durante un periodo prolongado.

En un servidor local con pocos usuarios y mensajes de texto, se espera normalmente un consumo bajo.

---

## 4. Memoria del servidor

La memoria mostrada corresponde a la memoria residente del proceso del servidor (RSS, Resident Set Size).

En Linux, CDD Connect obtiene esta información a partir de:

```text
/proc/self/statm
```

y la convierte a megabytes para mostrarla en la interfaz.

### Valores orientativos

| Memoria del servidor | Interpretación |
|---:|---|
| < 25 MB | Muy bajo consumo |
| 25 - 50 MB | Excelente |
| 50 - 100 MB | Normal para una aplicación pequeña |
| 100 - 250 MB | Debe observarse según la carga |
| > 250 MB | Conviene revisar crecimiento de memoria |
| Crecimiento continuo | Posible problema de gestión de memoria |

No existe un valor universal de memoria "correcto", ya que depende del número de usuarios, historial cargado y actividad del servidor.

Más importante que un valor instantáneo es verificar que la memoria no crezca indefinidamente durante una prueba prolongada.

---

## 5. Usuarios conectados

Indica el número de clientes que se encuentran actualmente registrados en el servidor.

El servidor cuenta únicamente las conexiones que ya tienen un usuario identificado.

Esta métrica permite comprobar el comportamiento multiusuario del sistema.

Ejemplo:

```text
Laura se conecta    -> Usuarios conectados: 1
David se conecta    -> Usuarios conectados: 2
Camilo se conecta   -> Usuarios conectados: 3
David se desconecta -> Usuarios conectados: 2
```

No existe un valor "bueno" o "malo" para esta métrica. Se utiliza principalmente como indicador de carga y para verificar que el servidor administra correctamente las conexiones simultáneas.

---

## 6. Mensajes recibidos

El cliente mantiene un contador de eventos de tipo `message` recibidos durante la sesión.

Este contador permite verificar que el cliente continúa recibiendo correctamente los mensajes y eventos difundidos por el servidor.

---

## 7. Frecuencia de actualización

CDD Connect realiza una medición mediante `ping` aproximadamente cada:

```text
2 segundos
```

Cada respuesta `pong` contiene información asociada a:

- Latencia.
- Jitter.
- CPU del servidor.
- Memoria del servidor.
- Usuarios conectados.

Los mensajes `ping` y `pong` son mensajes de control y no se almacenan en el historial del chat.

---

## 8. Interpretación conjunta

Un escenario adecuado para este proyecto podría presentar, por ejemplo:

```text
Latencia:             4.2 ms
Jitter:               0.8 ms
CPU servidor:         1.3 %
Memoria servidor:     12.5 MB
Usuarios conectados:  3
```

Este comportamiento indicaría una comunicación estable y un bajo consumo de recursos para una red local.

En cambio, valores como:

```text
Latencia:             180 ms
Jitter:               65 ms
CPU servidor:         85 %
Memoria servidor:     crecimiento continuo
```

indicarían que es necesario investigar la red, la carga del servidor o el uso de recursos.

---

## 9. Pruebas recomendadas

### Prueba 1 - Cliente y servidor en el mismo computador

Servidor:

```bash
./chat-server -history ./chat-history.jsonl
```

Cliente:

```text
127.0.0.1:9000
```

Esta prueba proporciona una referencia del rendimiento local sin influencia significativa de una red inalámbrica.

### Prueba 2 - Dos computadores en una red local o hotspot

Se conecta un segundo computador utilizando la dirección IP del computador que ejecuta el servidor.

Este escenario permite observar el efecto real de la red sobre latencia y jitter.

### Prueba 3 - Varios clientes simultáneos

Conectar varios usuarios y verificar:

- incremento correcto de `Usuarios conectados`;
- difusión de mensajes a todos los clientes;
- estabilidad de latencia y jitter;
- comportamiento de CPU;
- comportamiento de memoria;
- disminución del contador de usuarios cuando un cliente se desconecta.

---

## 10. Resumen de referencia

| Métrica | Objetivo recomendado para una LAN de chat |
|---|---|
| Latencia | < 30 ms |
| Jitter | < 15 ms |
| CPU servidor | Preferiblemente < 20 % en operación normal |
| Memoria servidor | Estable y, para este proyecto, preferiblemente < 100 MB |
| Usuarios conectados | Debe coincidir con los clientes activos |
| Mensajes recibidos | Debe aumentar conforme llegan eventos |

Estos valores permiten utilizar el panel de CDD Connect como herramienta de observación y diagnóstico durante las pruebas del servidor local.