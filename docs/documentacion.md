# GotaWatt · Documentación del sistema (versión 1)

## 1. Funciones indispensables de la primera versión

A partir de las pantallas y las historias de usuario se eligieron las funciones que resuelven el problema principal: **detectar un desperdicio, que alguien lo repare y medir si el consumo baja**.

| Historia de usuario | Función incluida |
|---|---|
| Como socio relevador, quiero registrar una canilla que gotea con foto y ubicación para que se pueda reparar. | Formulario de nuevo reporte con foto |
| Como socio relevador, quiero cargar la lectura del medidor de luz cada lunes para comparar el consumo. | Carga de lecturas y de goteo |
| Como mantenimiento, quiero ver los reportes pendientes para organizar las reparaciones. | Listado con filtros y cambio de estado |
| Como docente asesor, quiero revisar los datos para asegurarme de que sean correctos. | Acceso de solo lectura a reportes y estadísticas |
| Como administrador, quiero ver cuánto se redujo el consumo. | Panel y estadísticas |

**Para una versión siguiente:** reporte anónimo con código QR para la comunidad, encuestas, inventario y préstamo de equipos, informe en PDF y aprobación de informes por el docente.

## 2. Pantallas y recorrido

| Pantalla | Ruta | Quién la usa |
|---|---|---|
| Ingreso | `/ingresar` | Todos |
| Crear cuenta | `/registro` | Nuevos usuarios (solo con Supabase) |
| Cuenta pendiente | `/cuenta-pendiente` | Cuentas sin habilitar |
| Panel principal | `/` | Todos (cada rol ve sus botones) |
| Lista de reportes | `/reportes` | Todos |
| Nuevo / editar reporte | `/reportes/nuevo`, `/reportes/:id/editar` | Administrador y socios |
| Detalle e historial | `/reportes/:id` | Todos (acciones según el rol) |
| Mediciones | `/mediciones` | Todos (cargar: administrador y socios) |
| Estadísticas | `/estadisticas` | Todos |
| Usuarios | `/usuarios` | Solo administrador |

**Recorrido principal:** Ingreso → Panel → «Nuevo reporte» → completar lugar, tipo y foto → «Enviar reporte» (queda *Pendiente*) → Mantenimiento lo abre desde «Para reparar» → «Marcar en reparación» → «Marcar resuelto» → el caso aparece en Estadísticas.

## 3. Roles

| Rol | Puede |
|---|---|
| Administrador | Todo: reportes, mediciones, anular registros, habilitar cuentas y asignar roles, eliminar datos de prueba |
| Socio relevador | Crear reportes, editar o anular sus reportes pendientes, cargar lecturas y goteos |
| Mantenimiento | Ver reportes y cambiarlos a «En reparación» o «Resuelto» |
| Docente asesor | Consultar todo, sin modificar nada |

**Roles simulados:** en el **modo demostración** (sin archivo `.env`) los cuatro roles son simulados: se elige el rol en la pantalla de ingreso, sin contraseña, y una franja violeta lo recuerda en todas las pantallas. Con Supabase los roles son reales: cada usuario se registra y el administrador lo habilita y le asigna el rol.

## 4. Registros y operaciones

| Registro | Alta | Consulta | Modificación | Baja |
|---|---|---|---|---|
| Reporte | Formulario con validación | Listado, búsqueda, filtros y detalle | Editar mientras está pendiente; cambiar estado | **Anular** con motivo (no se borra) |
| Historial del reporte | Automático en cada cambio de estado | Detalle del reporte | No se modifica | No se borra |
| Lectura de medidor | Formulario (no puede ser menor a la anterior) | Tabla con consumo calculado | Solo el administrador | **Anular** con motivo |
| Goteo | Formulario con cálculo de litros por día | Tabla | Solo el administrador | **Anular** con motivo |
| Usuario | Registro desde la app | Pantalla Usuarios | Rol y habilitación (administrador) | **Deshabilitar** (no se borra) |
| Datos de prueba | Script SQL o datos de demostración | Etiqueta «Prueba» | Igual que los reales | **Eliminar** (solo el administrador) |

Se eligió **anular en vez de borrar** porque los datos sirven para comparar el consumo antes y después de las medidas: si se borraran se perdería el historial y no se podría saber quién hizo cada cambio.

**Estados de un reporte:** Pendiente → En reparación → Resuelto. Desde Pendiente o En reparación también puede pasar a Anulado. Solo el administrador puede reabrir un reporte resuelto.

**Búsquedas y filtros:** texto (lugar, tipo, descripción o autor), estado (incluye «abiertos»), lugar, recurso (agua o luz) y «solo mis reportes». En Mediciones se puede mostrar u ocultar lo anulado.

## 5. Qué información se conserva y dónde

| Información | Dónde se guarda | ¿Se comparte? |
|---|---|---|
| Reportes, historial, lecturas, goteos, fotos y usuarios | Base de datos Supabase (y Storage para fotos) | Sí, entre todos los usuarios y dispositivos |
| Sesión iniciada | Navegador (la maneja Supabase) | No, es de cada dispositivo |
| Filtros elegidos y pestaña de Mediciones | Navegador (`localStorage`) | No, es una preferencia de cada dispositivo |
| Datos del modo demostración | Navegador (`localStorage`) | No |

Al cerrar la aplicación se conserva todo lo de la base de datos; en el dispositivo solo quedan la sesión y las preferencias.

## 6. ¿Hace falta backend?

**Sí.** Un reporte cargado desde el celular de un socio tiene que verlo mantenimiento en otro dispositivo, y los permisos por rol tienen que cumplirse aunque alguien modifique la página. Eso no se puede hacer guardando datos solo en el navegador.

No se programó un servidor propio: se usa **Supabase** como backend, que ofrece base de datos PostgreSQL, autenticación, almacenamiento de fotos y reglas de seguridad por fila (RLS).

**Si no se usara backend** (como en el modo demostración), los datos quedarían en el `localStorage` de cada navegador, con estas limitaciones:

- cada dispositivo tendría datos distintos y no se compartirían;
- se perderían al borrar los datos del navegador;
- los roles no serían seguros, porque cualquiera podría elegir el rol;
- hay poco espacio (unos 5 MB), insuficiente para muchas fotos.

## 7. Base de datos

Script: `supabase/01_estructura.sql`. Diagrama de relaciones (PK = clave primaria, FK = clave foránea):

```
auth.users (Supabase)
    │ 1:1
perfiles ──────────────┬───────────────────────┬────────────────────┐
 PK id (uuid)          │ autor_id (FK)         │ cargado_por (FK)   │ cargado_por (FK)
 nombre, curso_cargo   ▼                       ▼                    ▼
 rol, activo        reportes ──1:N──► reporte_historial      lecturas            goteos
                     PK id                PK id              PK id               PK id
lugares ──1:N──────► lugar_id (FK)        reporte_id (FK)    medidor_id (FK) ◄── medidores
 PK id               tipo_id (FK) ◄──     estado_anterior    valor, fecha        lugar_id (FK) ◄── lugares
tipos_desperdicio ───┘ estado, foto_path  estado_nuevo       anulada, motivo     ml_10min, litros_dia
 PK id, recurso        motivo_anulacion   usuario_id (FK)                        anulada, motivo
                       es_prueba
```

| Tabla | Para qué sirve | Reglas principales |
|---|---|---|
| `perfiles` | Datos y rol de cada cuenta | Rol: administrador, socio, docente o mantenimiento. Nace inactivo |
| `lugares` | Espacios de la escuela | Nombre único; sector: aula, baño, laboratorio, etc. |
| `tipos_desperdicio` | Qué tipo de problema es | Recurso: agua o luz |
| `medidores` | Medidores de agua y luz | Luz en kWh, agua en m³ |
| `reportes` | Desperdicios detectados | Estado válido; si está anulado, tiene que tener motivo |
| `reporte_historial` | Cada cambio de estado | Lo escribe solo la base de datos (trigger) |
| `lecturas` | Lecturas de medidores | Valor ≥ 0; si está anulada, tiene que tener motivo |
| `goteos` | Medición de una canilla | 0,1 a 5000 ml; los litros por día se calculan solos (ml × 144 / 1000) |

Además hay una vista, `reportes_detalle`, que une cada reporte con su lugar, tipo y autor.

## 8. Seguridad y permisos

- Los permisos se aplican **en la base de datos** con Row Level Security (`supabase/02_politicas.sql`). La interfaz además oculta los botones que el rol no puede usar.
- Un trigger (`controlar_reporte`) verifica qué campos puede cambiar cada rol y que el orden de los estados sea válido.
- Otro trigger (`controlar_lectura`) impide cargar una lectura menor que la anterior del mismo medidor.
- Nadie puede borrar registros reales; el administrador solo puede eliminar los marcados como prueba.
- La app usa únicamente la clave pública `anon`, leída del archivo `.env`, que no se sube al repositorio. La clave `service_role` y las contraseñas nunca van en el código ni en esta documentación.
- Las fotos se guardan en un bucket privado. Cada usuario solo puede subir a su propia carpeta y no deben mostrarse personas.

Los permisos se probaron con 40 casos (por ejemplo: un socio no puede editar el reporte de otro, mantenimiento no puede anular, un docente no puede cargar mediciones y nadie puede cambiarse el propio rol).

## 9. Mensajes al usuario

Cada operación muestra un mensaje de **carga** («Cargando reportes…», «Guardando…»), de **confirmación** («Reporte enviado», «Lectura guardada») o de **error** con una explicación clara y un botón para reintentar. Las acciones importantes (anular, eliminar, cambiar estado) piden confirmación antes de hacerse.
