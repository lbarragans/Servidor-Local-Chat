# Documentación

Esta carpeta reúne la documentación funcional y de ingeniería del proyecto
**Servidor Local de Chat** (materia Sistemas Embebidos Linux), complementando
la documentación técnica ya existente en:

- [`README.md`](../README.md) (raíz del proyecto)
- [`docs/server-callgraph.md`](../docs/server-callgraph.md)
- [`docs/client-callgraph.md`](../docs/client-callgraph.md)
- [`client/README.md`](../client/README.md)

## Índice de documentos

1. [Descripción Funcional](01-Descripcion-Funcional.md): propósito del
   proyecto, alcance actual, protocolo de comunicación y actores.
2. [Casos de Uso y Requerimientos](02-Casos-de-Uso-y-Requerimientos.md):
   historias de usuario, requerimientos funcionales y no funcionales.
3. [Arquitectura Propuesta](03-Arquitectura.md): componentes, modelo de
   datos, concurrencia, topología de despliegue y decisiones de diseño.
4. [Matriz de Verificación](04-Matriz-de-Verificacion.md): trazabilidad
   entre requerimientos y pruebas unitarias/de integración existentes,
   procedimiento de verificación manual y backlog de pruebas pendientes.

## Estado y alcance de este contenido

Estos documentos se generaron a partir del código fuente real del repositorio
(servidor en Go y cliente en Flutter) para reflejar con precisión lo que el
sistema hace hoy. Cada documento incluye, al final, una sección
**"Información pendiente por parte del equipo"** señalando los puntos donde
se requiere contexto adicional (integrantes, docente, alcance académico
específico, formato de entrega exigido, etc.) que no pueden inferirse del
código.

Esta rama (`documentacion`) se creó específicamente para trabajar en este
nuevo punto del proyecto sin afectar la rama `feature/server`.
