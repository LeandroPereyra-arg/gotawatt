# GotaWatt · Etapa 7: funcionalidades completas e integración de módulos

En esta etapa se revisó qué requerimientos estaban terminados, se completaron los que faltaban para que el sistema cumpla su objetivo principal (**detectar un desperdicio, que alguien lo repare y medir si el consumo baja**) y se integraron los módulos entre sí.

---

## 1. Estado de los requerimientos funcionales

| Código | Requerimiento | Estado |
|---|---|---|
| RF01 | Registrarse como usuario nuevo | Implementado |
| RF02 | Iniciar y cerrar sesión | Implementado |
| RF03 | Habilitar cuentas y asignar roles | Implementado |
| RF04 | Registrar un desperdicio con lugar, tipo, descripción y foto | Implementado |
| RF05 | Editar o anular un reporte propio mientras está pendiente | Implementado |
| RF06 | Cambiar el estado de un reporte y guardar el historial | Implementado |
| RF07 | Consultar reportes con búsqueda, filtros y orden | Implementado |
| RF08 | Cargar lecturas de los medidores de agua y luz | Implementado |
| RF09 | Medir el goteo de canillas y calcular los litros perdidos | Implementado |
| RF10 | Corregir mediciones con error | Parcial |
| RF11 | Ver el panel y las estadísticas de consumo | Implementado |
| RF12 | Administrar lugares, tipos de desperdicio y medidores | Implementado (nuevo en esta etapa) |
| RF13 | Eliminar los datos de prueba | Implementado |
| RF14 | Reporte anónimo de la comunidad con código QR | Pendiente |
| RF15 | Encuestas a la comunidad educativa | Pendiente |
| RF16 | Inventario y préstamo de equipos | Pendiente |
| RF17 | Informe en PDF | Pendiente |
| RF18 | Aprobación de informes por el docente asesor | Pendiente |

**RF10 parcial:** las mediciones con error se **anulan** con motivo y se vuelven a cargar; no se puede editar el valor directamente. Se decidió así para que quede registro de la corrección.

## 2. Funcionalidades indispensables y orden de implementación

Se ordenaron según su importancia para el objetivo principal y según qué necesita cada una para funcionar:

| Orden | Funcionalidad | Depende de | Por qué en este lugar |
|---|---|---|---|
| 1 | Ingreso, registro y roles (RF01–RF03) | — | Sin usuarios no se puede aplicar ningún permiso |
| 2 | Catálogos de lugares, tipos y medidores (RF12) | 1 | Los reportes y las mediciones eligen valores de estos catálogos |
| 3 | Registrar reportes (RF04, RF05) | 1, 2 | Es la función central: detectar el desperdicio |
| 4 | Cambiar estados con historial (RF06) | 3 | Permite que mantenimiento resuelva lo reportado |
| 5 | Consultar reportes (RF07) | 3 | Mantenimiento y docentes necesitan encontrar los casos |
| 6 | Lecturas y goteo (RF08–RF10) | 1, 2 | Miden si el consumo baja |
| 7 | Panel y estadísticas (RF11) | 3, 4, 6 | Muestran el resultado de todo lo anterior |
| 8 | Eliminar datos de prueba (RF13) | 3, 6 | Necesario para pasar de pruebas a uso real |

Las funciones RF14 a RF18 no son indispensables para la primera versión y quedan para la siguiente.

## 3. Operaciones CRUD de las entidades principales

| Entidad | Crear | Consultar | Modificar | Eliminar / baja lógica | Dónde |
|---|---|---|---|---|---|
| Reporte | ✔ | ✔ (lista y detalle) | ✔ (datos y estado) | Anular con motivo; eliminar solo si es de prueba | Reportes |
| Lugar | ✔ | ✔ | ✔ | Dar de baja / reactivar | Catálogos |
| Tipo de desperdicio | ✔ | ✔ | ✔ | Dar de baja / reactivar | Catálogos |
| Medidor | ✔ | ✔ | ✔ (nombre) | Dar de baja / reactivar | Catálogos |
| Lectura | ✔ | ✔ | Anular | Anular con motivo (baja lógica) | Mediciones |
| Goteo | ✔ | ✔ | Anular | Anular con motivo (baja lógica) | Mediciones |
| Usuario | ✔ (registro) | ✔ | ✔ (rol y habilitación) | Deshabilitar | Usuarios |

**Nuevo en esta etapa:** la pantalla **Catálogos** (solo administrador). Antes los lugares, tipos y medidores se cargaban únicamente por SQL. Ahora se crean, editan, dan de baja y reactivan desde la interfaz. El recurso de un medidor no se puede cambiar después de creado porque sus lecturas dependen de la unidad.

## 4. Procesos completos del sistema

### Proceso 1: Del desperdicio a la reparación

Involucra los módulos **Reportes**, **Detalle**, **Panel** y **Estadísticas**, y las tablas `perfiles`, `lugares`, `tipos_desperdicio`, `reportes`, `reporte_historial` y el bucket `fotos`.

1. El **socio** abre «Nuevo reporte», elige lugar y tipo, saca una foto y envía. Si ya hay un reporte abierto igual, la app avisa y muestra el enlace al existente.
2. El reporte queda **Pendiente** y el trigger agrega la primera fila del historial.
3. **Mantenimiento** lo ve en «Para reparar» del panel (aparece sin recargar la página), lo abre y pulsa «Marcar en reparación» → confirma.
4. Al terminar pulsa «Marcar resuelto» → confirma. Cada cambio suma una fila al historial con su nombre y la hora.
5. **Resultado verificable:** el reporte figura como Resuelto, el historial muestra los tres pasos con sus responsables y las estadísticas suben el porcentaje de resueltos y el conteo del lugar.

### Proceso 2: Medición y seguimiento del consumo

Involucra **Mediciones**, **Panel** y **Estadísticas**, y las tablas `medidores`, `lecturas`, `lugares`, `goteos` y `perfiles`.

1. Cada lunes el **socio** carga la lectura de los medidores. La app controla que no sea menor que la anterior y que no haya otra lectura del mismo medidor ese día.
2. La tabla calcula el **consumo** de la semana (diferencia con la lectura anterior).
3. El socio mide una canilla que gotea durante 10 minutos; la base calcula los **litros por día**.
4. Si una lectura se cargó mal, el **administrador** la anula con motivo y se vuelve a cargar.
5. **Resultado verificable:** el panel muestra el consumo de la última semana y la variación respecto de la anterior; Estadísticas muestra las barras semanales y los litros perdidos por goteo. Una lectura anulada deja de contar en esos cálculos.

### Proceso 3: Alta de un integrante nuevo

Involucra **Registro**, **Cuenta pendiente** y **Usuarios**, y las tablas `auth.users` y `perfiles`.

1. La persona se registra desde «Crear cuenta». El trigger crea su perfil inactivo.
2. Ve la pantalla «Cuenta pendiente».
3. El **administrador** la ve en **Usuarios** (aparece sola, sin recargar), revisa el rol y pulsa «Habilitar» → confirma.
4. **Resultado verificable:** la persona ingresa y ve solo las secciones de su rol.

## 5. Información relacionada entre tablas

No se duplica información: los nombres se obtienen con consultas que unen tablas.

| Pantalla | Consulta | Tablas relacionadas |
|---|---|---|
| Reportes y Panel | Vista `reportes_detalle` | reportes + lugares + tipos_desperdicio + perfiles |
| Detalle del reporte | Historial con nombre del usuario | reporte_historial + perfiles |
| Mediciones (lecturas) | Lecturas con quién las cargó | lecturas + perfiles (+ medidores) |
| Mediciones (goteo) | Goteos con lugar y quién los cargó | goteos + lugares + perfiles |
| Estadísticas | Vista `resumen_por_lugar` (JOIN + GROUP BY) | lugares + reportes |

## 6. Reglas de negocio

| Código | Regla | Dónde se aplica |
|---|---|---|
| RN1 | No puede haber dos reportes **abiertos** del mismo tipo en el mismo lugar | Base (índice único) e interfaz (aviso con enlace al reporte existente) |
| RN2 | Una sola lectura válida por medidor y por día | Base (índice único) e interfaz |
| RN3 | Un medidor no retrocede: la lectura no puede ser menor que la anterior | Base (trigger) e interfaz |
| RN4 | No se carga nada sobre un lugar, tipo o medidor dado de baja | Base (trigger) e interfaz (no aparecen en los formularios) |
| RN5 | No se da de baja un lugar o tipo con reportes abiertos | Base (trigger) |
| RN6 | Orden de estados: Pendiente → En reparación → Resuelto; desde Pendiente o En reparación se puede anular; solo el administrador reabre un resuelto | Base (trigger) e interfaz (solo muestra los botones válidos) |
| RN7 | Un reporte resuelto o anulado no se edita | Base e interfaz |
| RN8 | Para anular se exige un motivo (5 a 200 caracteres) | Base (check) e interfaz |
| RN9 | Los registros reales no se borran; solo se eliminan los marcados como prueba | Base (RLS) e interfaz |
| RN10 | Nadie puede cambiar su propio rol ni deshabilitarse | Base (trigger) e interfaz |
| RN11 | Las cuentas nuevas quedan inactivas hasta que el administrador las habilita | Base (valor por defecto y RLS) |

RN1, RN2, RN4 y RN5 son nuevas en esta etapa (`supabase/04_reglas_negocio.sql`).

## 7. Permisos por tipo de usuario

| Función | Administrador | Socio relevador | Mantenimiento | Docente asesor |
|---|:---:|:---:|:---:|:---:|
| Ver panel, reportes, mediciones y estadísticas | ✔ | ✔ | ✔ | ✔ |
| Crear reportes | ✔ | ✔ | | |
| Editar o anular reportes pendientes | ✔ (todos) | ✔ (propios) | | |
| Marcar en reparación o resuelto | ✔ | | ✔ | |
| Reabrir un reporte resuelto | ✔ | | | |
| Cargar lecturas y goteos | ✔ | ✔ | | |
| Anular mediciones | ✔ | | | |
| Administrar catálogos | ✔ | | | |
| Habilitar cuentas y asignar roles | ✔ | | | |
| Eliminar datos de prueba | ✔ | | | |

Las restricciones se aplican en tres niveles:

1. **Navegación:** el menú solo muestra las secciones del rol y el router impide entrar por dirección a Catálogos, Usuarios o Nuevo reporte sin permiso.
2. **Interfaz:** los botones que el rol no puede usar no aparecen.
3. **Datos:** las políticas RLS y los triggers de Supabase rechazan la operación aunque alguien la intente desde fuera de la app. Se comprobó con `06_pruebas_permisos.sql`.

## 8. Búsquedas, filtros y ordenamientos

| Módulo | Búsqueda | Filtros | Orden |
|---|---|---|---|
| Reportes | Lugar, tipo, descripción o autor | Estado (incluye «abiertos»), lugar, recurso, solo mis reportes | Más recientes, más antiguos, últimos actualizados, lugar A–Z |
| Mediciones | — | Medidor (lecturas), lugar (goteo), ver anuladas | Por fecha, de la más nueva a la más vieja |
| Usuarios | Nombre o curso | Rol, estado (esperando habilitación / habilitados) | Primero los pendientes, luego por nombre |
| Catálogos | Nombre | Ver dados de baja | Por nombre |

Los filtros elegidos se recuerdan en el dispositivo. Desde Estadísticas, al tocar un lugar se abre la lista de reportes ya filtrada por ese lugar.

## 9. Validaciones

| Formulario | Validaciones |
|---|---|
| Ingreso y registro | Campos obligatorios, formato de correo, contraseña de 8 caracteres o más, contraseñas iguales, largo del nombre |
| Reporte | Lugar y tipo obligatorios, descripción hasta 300 caracteres, foto JPG/PNG/WEBP de hasta 8 MB, reporte abierto duplicado |
| Lectura | Medidor obligatorio, solo números, no negativa, máximo 2 decimales, no menor que la anterior, una por día |
| Goteo | Lugar y canilla obligatorios, entre 0,1 y 5000 ml |
| Catálogos | Nombre obligatorio (2 o 3 a 60 caracteres), nombre repetido, sector o recurso obligatorio |
| Anular | Motivo de 5 a 200 caracteres |

## 10. Mensajes de confirmación y error

Cada operación muestra un aviso: de éxito en verde («Reporte enviado», «Se agregó el lugar «Gimnasio»», «Registro anulado. Queda guardado en el historial») y de error en rojo con la causa («Ya hay un reporte abierto de ese tipo en ese lugar», «No se puede dar de baja: tiene 2 reportes abiertos», «Tu rol no tiene permiso para esta acción», «No hay conexión con el servidor»). Mientras se cargan datos se muestra «Cargando…» y, si falla, un botón **Reintentar**.

## 11. Confirmación de operaciones importantes

Piden confirmación antes de ejecutarse: cambiar el estado de un reporte, anular un reporte (con motivo), eliminar un reporte de prueba, anular una medición (con motivo), dar de baja o reactivar un lugar, tipo o medidor, **cambiar el rol de un usuario** y **habilitar o deshabilitar una cuenta** (estas dos últimas se agregaron en esta etapa). Si se cancela un cambio de rol, el selector vuelve al rol anterior.

## 12. Actualización automática de las pantallas

Después de cada operación la pantalla vuelve a pedir los datos, así que el cambio se ve sin recargar. Además, en esta etapa se agregó **Supabase Realtime**: si **otro usuario** modifica algo, las pantallas abiertas se actualizan solas (por ejemplo, mantenimiento ve aparecer un reporte nuevo en su panel, o el socio ve que su reporte pasó a «En reparación»). En el modo demostración ocurre lo mismo entre pestañas del mismo navegador. La actualización es silenciosa: no vuelve a mostrar «Cargando…» ni interrumpe lo que se está haciendo.

## 13. Organización del código

| Carpeta | Responsabilidad |
|---|---|
| `src/views/` | Pantallas: muestran datos y responden a las acciones del usuario |
| `src/components/` | Piezas reutilizables (barra, diálogo de confirmación, campos, estados de carga) |
| `src/services/` | **Único lugar que habla con Supabase** (`apiSupabase.js`) o con los datos de demostración (`apiDemo.js`) |
| `src/composables/` | Lógica que comparten varias pantallas (nuevo) |
| `src/stores/` | Estado compartido: sesión, avisos y preferencias |
| `src/utils/` | Reglas por rol, validaciones, formatos y cálculos |

**Código repetido que se corrigió**

- Cada pantalla repetía el mismo manejo de «cargando / error / reintentar». Se reemplazó por el composable `useCarga`.
- La suscripción a cambios en tiempo real se escribió una sola vez en `useTiempoReal` y la usan siete pantallas.
- Los estilos de las pestañas estaban dentro de Mediciones; se pasaron a los estilos generales para usarlos también en Catálogos. Lo mismo con la clase para lectores de pantalla.

## 14. Navegación

Se recorrieron los procesos principales con cada rol, verificando que:

- todos los enlaces del menú, del panel y de las tarjetas llevan a la pantalla correcta;
- los botones «Volver» regresan al lugar anterior lógico;
- una dirección inexistente muestra «Página no encontrada» con enlace al inicio;
- entrar por dirección a una sección sin permiso redirige al panel con un aviso;
- en el celular el menú inferior muestra las seis secciones del administrador sin desbordarse.

## 15. Pruebas de integración

Ver [pruebas.md](pruebas.md), sección «Pruebas de integración entre módulos».

## 16. Cambios respecto de las etapas anteriores

**Nuevo**

- Pantalla **Catálogos** con alta, edición, baja y reactivación de lugares, tipos y medidores.
- Reglas RN1, RN2, RN4 y RN5 en la base de datos y en la interfaz.
- Aviso de reporte duplicado con enlace al reporte existente.
- Orden de la lista de reportes; filtros por medidor y por lugar en Mediciones; filtros por rol y estado en Usuarios.
- Confirmación al cambiar roles y al habilitar o deshabilitar cuentas.
- Actualización automática con Supabase Realtime.
- Tabla «Lugares con más reportes» en Estadísticas (vista `resumen_por_lugar`).
- Scripts `04_reglas_negocio.sql`, `05_consultas_prueba.sql` y `06_pruebas_permisos.sql`.

**Modificado**

- Las pantallas usan los composables `useCarga` y `useTiempoReal`.
- Los formularios solo muestran lugares, tipos y medidores activos.

**Pendiente:** RF14 a RF18 y la edición directa del valor de una medición (RF10).

## 17. Tabla de seguimiento de funcionalidades

| Código | Funcionalidad | Módulo | Estado | Observaciones o dificultades |
|---|---|---|---|---|
| RF01 | Registro de usuarios | Crear cuenta | Implementado | Solo con Supabase; en modo demostración se eligen roles simulados |
| RF02 | Ingreso y cierre de sesión | Ingreso, barra | Implementado | Si la sesión vence se vuelve al ingreso |
| RF03 | Habilitar cuentas y roles | Usuarios | Implementado | Se agregó confirmación. El administrador no puede cambiar su propio rol para no quedar sin administrador |
| RF04 | Registrar desperdicio con foto | Nuevo reporte | Implementado | La foto se achica antes de subirla para no superar 2 MB |
| RF05 | Editar o anular reporte propio | Detalle, Editar | Implementado | Solo mientras está pendiente |
| RF06 | Cambiar estado con historial | Detalle | Implementado | El historial lo escribe un trigger para que no se pueda falsear |
| RF07 | Consultar reportes | Reportes | Implementado | Se agregó el orden. El texto de búsqueda se limpia para no romper el filtro de Supabase |
| RF08 | Lecturas de medidores | Mediciones | Implementado | Se agregó la regla de una lectura por día |
| RF09 | Goteo de canillas | Mediciones | Implementado | Los litros por día los calcula la base |
| RF10 | Corregir mediciones | Mediciones | Parcial | Se anula y se vuelve a cargar; no se edita el valor |
| RF11 | Panel y estadísticas | Panel, Estadísticas | Implementado | Hacen falta dos lecturas para calcular un consumo |
| RF12 | Administrar catálogos | Catálogos | Implementado | No se da de baja un lugar o tipo con reportes abiertos |
| RF13 | Eliminar datos de prueba | Detalle | Implementado | La base solo permite borrar filas con `es_prueba` |
| RF14 | Reporte anónimo con QR | — | Pendiente | Requiere políticas para usuarios sin sesión y control de abuso |
| RF15 | Encuestas | — | Pendiente | |
| RF16 | Inventario y préstamo de equipos | — | Pendiente | |
| RF17 | Informe en PDF | — | Pendiente | |
| RF18 | Aprobación de informes por el docente | — | Pendiente | Depende de RF17 |
