# GotaWatt · Pruebas de funcionamiento e integración

Pruebas realizadas en las etapas 6 y 7. Para cada una se indica la funcionalidad evaluada, los pasos, el resultado esperado y el obtenido.

- **Base de datos y permisos:** se ejecutaron los scripts `05_consultas_prueba.sql` y `06_pruebas_permisos.sql` sobre la base creada con `01` a `04`.
- **Aplicación:** se probó en el navegador con los cuatro roles, usando los datos de prueba.

---

## 1. Pruebas de la base de datos (`05_consultas_prueba.sql`)

| N.º | Funcionalidad | Pasos | Resultado esperado | Resultado obtenido |
|---|---|---|---|---|
| B01 | Selección simple | Consultar lugares activos, reportes abiertos y goteos | Devuelve filas ordenadas | Correcto |
| B02 | JOIN de 4 tablas | Reportes con lugar, tipo, recurso y autor | Cada reporte con sus nombres | Correcto |
| B03 | JOIN historial–perfiles | Historial del primer reporte | Cambios con el nombre de quien los hizo | Correcto |
| B04 | JOIN + GROUP BY | Reportes por sector y recurso | Cantidades agrupadas | Correcto |
| B05 | Consumo semanal | Lecturas con la diferencia respecto de la anterior | Consumo de cada semana por medidor | Correcto |
| B06 | LEFT JOIN | Lugares sin reportes | Lista de lugares que nunca tuvieron reportes | Correcto |
| B07 | Vista `resumen_por_lugar` | Consultar la vista | Conteo por estado de cada lugar | Correcto |
| B08 | Tiempo de resolución | Promedio de horas hasta «resuelto» por tipo | Horas promedio por tipo | Correcto |
| B09 | Inserción | Alta de un lugar y un reporte | Se crean; el trigger agrega «Reporte creado» al historial | Correcto |
| B10 | Actualización | Cambiar el reporte a «en reparación» | El historial suma la fila pendiente → en reparación | Correcto |
| B11 | Baja lógica | Anular una lectura con motivo | Queda `anulada = true` con su motivo | Correcto |
| B12 | Eliminación | Borrar el reporte y el lugar de prueba | Se eliminan | Correcto |
| B13 | Restricción de rango | Goteo de 9000 ml | Rechazado | Rechazado («OK: goteo fuera de rango rechazado») |
| B14 | Motivo obligatorio | Anular un reporte sin motivo | Rechazado | Rechazado |
| B15 | Nombre único | Crear otro «Aula 1» | Rechazado | Rechazado |
| B16 | RN1 | Reporte abierto repetido (mismo lugar y tipo) | Rechazado | Rechazado |
| B17 | RN3 | Lectura menor que la anterior | Rechazada | Rechazada |
| B18 | Script repetible | Ejecutar `04_reglas_negocio.sql` dos veces | Sin errores | Correcto |

## 2. Pruebas de permisos y reglas (`06_pruebas_permisos.sql`)

El script crea usuarios temporales de cada rol, ejecuta cada operación con la identidad de ese usuario (igual que la app con la sesión iniciada), deshace el cambio y al final borra todo lo que creó.

**Resultado: 39 de 39 casos con el resultado esperado.**

| N.º | Caso | Usuario | Esperado | Obtenido |
|---|---|---|---|---|
| P01 | Sin sesión no puede ver reportes | Sin sesión | Bloqueado | Bloqueado ✔ |
| P02 | Cuenta sin habilitar no ve reportes | Cuenta sin habilitar | Bloqueado | Bloqueado ✔ |
| P03 | Docente ve los reportes | Docente | Permitido | Permitido ✔ |
| P04 | Mantenimiento ve los reportes | Mantenimiento | Permitido | Permitido ✔ |
| P05 | Socio ve la vista reportes_detalle | Socio | Permitido | Permitido ✔ |
| P06 | Socio crea un reporte | Socio | Permitido | Permitido ✔ |
| P07 | Docente no puede crear reportes | Docente | Bloqueado | Bloqueado ✔ |
| P08 | Mantenimiento no puede crear reportes | Mantenimiento | Bloqueado | Bloqueado ✔ |
| P09 | Socio no puede crear un reporte a nombre de otro | Socio | Bloqueado | Bloqueado ✔ |
| P10 | Socio edita su reporte pendiente | Socio | Permitido | Permitido ✔ |
| P11 | Socio no puede editar el reporte de otro | Socio | Bloqueado | Bloqueado ✔ |
| P12 | Socio anula su reporte con motivo | Socio | Permitido | Permitido ✔ |
| P13 | Socio no puede marcar su reporte como resuelto | Socio | Bloqueado | Bloqueado ✔ |
| P14 | Mantenimiento marca un reporte en reparación | Mantenimiento | Permitido | Permitido ✔ |
| P15 | Mantenimiento no puede cambiar la descripción | Mantenimiento | Bloqueado | Bloqueado ✔ |
| P16 | Mantenimiento no puede anular reportes | Mantenimiento | Bloqueado | Bloqueado ✔ |
| P17 | Docente no puede cambiar estados | Docente | Bloqueado | Bloqueado ✔ |
| P18 | Administrador cambia el estado de cualquier reporte | Administrador | Permitido | Permitido ✔ |
| P19 | Administrador elimina un reporte de prueba | Administrador | Permitido | Permitido ✔ |
| P20 | Administrador no puede eliminar un reporte real | Administrador | Bloqueado | Bloqueado ✔ |
| P21 | Socio no puede eliminar reportes | Socio | Bloqueado | Bloqueado ✔ |
| P22 | Nadie puede escribir el historial a mano | Administrador | Bloqueado | Bloqueado ✔ |
| P23 | Socio carga una lectura | Socio | Permitido | Permitido ✔ |
| P24 | Docente no puede cargar lecturas | Docente | Bloqueado | Bloqueado ✔ |
| P25 | Socio no puede cargar una lectura a nombre de otro | Socio | Bloqueado | Bloqueado ✔ |
| P26 | Socio no puede anular lecturas | Socio | Bloqueado | Bloqueado ✔ |
| P27 | Administrador anula una lectura con motivo | Administrador | Permitido | Permitido ✔ |
| P28 | Socio carga una medición de goteo | Socio | Permitido | Permitido ✔ |
| P29 | Mantenimiento no puede cargar goteos | Mantenimiento | Bloqueado | Bloqueado ✔ |
| P30 | Socio no puede cambiarse el rol | Socio | Bloqueado | Bloqueado ✔ |
| P31 | Socio no puede crear perfiles | Socio | Bloqueado | Bloqueado ✔ |
| P32 | Administrador habilita una cuenta | Administrador | Permitido | Permitido ✔ |
| P33 | Administrador no puede quitarse su propio rol | Administrador | Bloqueado | Bloqueado ✔ |
| P34 | Socio no puede crear lugares | Socio | Bloqueado | Bloqueado ✔ |
| P35 | Administrador crea un lugar | Administrador | Permitido | Permitido ✔ |
| P36 | No se da de baja un lugar con reportes abiertos | Administrador | Bloqueado | Bloqueado ✔ |
| P37 | No se permite un reporte abierto duplicado | Socio | Bloqueado | Bloqueado ✔ |
| P38 | Un medidor no retrocede | Socio | Bloqueado | Bloqueado ✔ |
| P39 | No se reporta sobre un lugar dado de baja | Socio | Bloqueado | Bloqueado ✔ |

## 3. Pruebas de funcionamiento en la aplicación

| N.º | Funcionalidad | Pasos | Resultado esperado | Resultado obtenido |
|---|---|---|---|---|
| A01 | Crear reporte | Socio → Nuevo reporte → Baño 2° piso, «Canilla abierta» → Enviar | Mensaje «¡Reporte enviado!», se abre el detalle como Pendiente | Correcto (reporte n.º 11) |
| A02 | Reporte duplicado | Socio → Nuevo reporte → Baño 2° piso, «Canilla que gotea» (ya hay uno pendiente) | Aviso «Ya hay un reporte pendiente…» con enlace y botón Enviar deshabilitado | Correcto |
| A03 | Cambio de estado | Mantenimiento → reporte 11 → Marcar en reparación → Confirmar | Pide confirmación; pasa a «En reparación» y el historial suma la fila | Correcto |
| A04 | Botones por rol | Mantenimiento abre un reporte pendiente | Solo «Marcar en reparación» y «Marcar resuelto» | Correcto |
| A05 | Solo lectura | Docente abre un reporte | «Tu rol no tiene acciones disponibles» | Correcto |
| A06 | Validación de formulario | Administrador → Catálogos → Agregar sin datos | «Ingresá el nombre.» y «Elegí el sector.» | Correcto |
| A07 | Nombre repetido | Catálogos → nombre «aula 1» | «Ya existe uno con ese nombre.» | Correcto |
| A08 | Alta en catálogo | Catálogos → «Gimnasio», sector Otro → Agregar | Aviso de éxito y aparece en la lista | Correcto |
| A09 | Baja bloqueada | Dar de baja «Baño 2° piso» → Confirmar | Error «No se puede dar de baja: tiene 2 reporte(s) abierto(s)» | Correcto |
| A10 | Baja lógica | Dar de baja «Gimnasio» → Confirmar | Desaparece de la lista y del formulario de reportes; «Ver dados de baja (1)» | Correcto |
| A11 | Lectura repetida en el día | Socio → Mediciones → lectura de luz el mismo día de otra | «Ya se cargó una lectura de este medidor hoy…» | Correcto |
| A12 | Anular medición | Administrador → Anular la lectura del día con motivo | Pide motivo; queda anulada y deja de contar | Correcto |
| A13 | Medidor no retrocede | Cargar 18000 kWh (anterior 18040) | «Un medidor no retrocede: la lectura anterior fue 18040.» | Correcto |
| A14 | Lectura válida | Cargar 18460 kWh | «Lectura guardada»; la tabla muestra consumo de 420 kWh | Correcto |
| A15 | Filtro de mediciones | Filtrar por «Medidor de luz principal» | Solo lecturas de ese medidor (5 de 10) | Correcto |
| A16 | Orden de reportes | Reportes → Ordenar por «Lugar (A a Z)» | Lista ordenada alfabéticamente por lugar | Correcto |
| A17 | Confirmar cambio de rol | Usuarios → cambiar «Socio de prueba» a Docente → Cancelar | Pide confirmación; al cancelar el selector vuelve a «Socio relevador» | Correcto |
| A18 | Habilitar cuenta | Usuarios → «Estudiante nuevo» → Habilitar → Confirmar | Aviso de éxito; el botón pasa a «Deshabilitar» | Correcto |
| A19 | Filtro de usuarios | Filtrar por «Esperando habilitación» luego de habilitar | «No hay usuarios con esos filtros.» | Correcto |
| A20 | Acceso por dirección | Docente escribe `#/catalogos` y `#/reportes/nuevo` | Vuelve al panel con «Tu rol no tiene acceso a esa sección.» | Correcto |
| A21 | Menú por rol | Ingresar como docente | Menú: Inicio, Reportes, Mediciones, Estadísticas; sin formularios de carga | Correcto |
| A22 | Página inexistente | Ir a `#/no-existe` | «Página no encontrada» con botón al inicio | Correcto |
| A23 | Diseño en celular | Administrador en pantalla de 375 px | Las 6 secciones entran en el menú inferior, sin desplazamiento horizontal | Correcto |

## 4. Pruebas de integración entre módulos

| N.º | Integración | Pasos | Resultado esperado | Resultado obtenido |
|---|---|---|---|---|
| I01 | Reportes → otra pantalla abierta | Con la lista de reportes abierta en otra pestaña, crear un reporte | La lista pasa de 10 a 11 reportes sin recargar | Correcto |
| I02 | Detalle → detalle de otro usuario | Con el reporte 11 abierto como socio, mantenimiento lo marca en reparación | En la pantalla del socio cambia el estado y aparece la fila del historial sin recargar | Correcto |
| I03 | Catálogos → Nuevo reporte | Dar de baja un lugar y abrir Nuevo reporte | El lugar ya no aparece para elegir | Correcto |
| I04 | Mediciones → Panel y Estadísticas | Anular una lectura y cargar otra | El consumo se recalcula con la lectura nueva | Correcto |
| I05 | Estadísticas → Reportes | Tocar «Baño 2° piso» en «Lugares con más reportes» | Se abre Reportes filtrado por ese lugar (2 reportes) | Correcto |
| I06 | Usuarios → Ingreso | Habilitar una cuenta pendiente | La cuenta deja de figurar como pendiente | Correcto |

## 5. Errores encontrados y correcciones

| Error | Corrección |
|---|---|
| Se podían cargar dos reportes abiertos iguales (mismo lugar y tipo) | Regla RN1: índice único en la base y aviso en el formulario con enlace al existente |
| Se podían cargar dos lecturas del mismo medidor el mismo día | Regla RN2: índice único en la base y validación en el formulario |
| Se podía seguir reportando sobre un lugar que ya no existe | Regla RN4 y campo `activo` usado en los formularios |
| Lugares, tipos y medidores solo se podían cargar con SQL | Pantalla Catálogos |
| El cambio de rol y la deshabilitación de cuentas se aplicaban con un solo toque, sin confirmar | Diálogo de confirmación; al cancelar, el selector vuelve al rol anterior |
| Si otro usuario modificaba algo, había que recargar la página para verlo | Supabase Realtime con el composable `useTiempoReal` |
| El mismo código de «cargando / error» estaba copiado en cada pantalla | Composable `useCarga` |
| La primera versión de `05_consultas_prueba.sql` probaba las restricciones con sentencias que fallaban, y el SQL Editor se detiene en el primer error | Se reemplazaron por un bloque que captura cada error y muestra «OK» o «FALLA» |

## 6. Cómo repetir las pruebas

1. En Supabase > SQL Editor ejecutar `05_consultas_prueba.sql` (cada consulta por separado para ver su resultado) y revisar los mensajes «OK» del bloque de restricciones.
2. Ejecutar `06_pruebas_permisos.sql` completo: la tabla final tiene que mostrar `ok = true` en las 39 filas.
3. En la app, repetir las pruebas A01 a A23 con una cuenta de cada rol.
