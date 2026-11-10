-- =====================================================================
-- GotaWatt - 05_consultas_prueba.sql : consultas para comprobar que la
-- base de datos funciona (selección, inserción, actualización,
-- eliminación y consultas con JOIN).
-- Requisito: haber ejecutado 01, 02, 00, 03 y 04.
-- Conviene seleccionar cada consulta y ejecutarla por separado para ver
-- su resultado. Las operaciones que modifican datos están dentro de una
-- transacción que termina con ROLLBACK, así que no dejan cambios.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. SELECT simples
-- ---------------------------------------------------------------------
-- 1.1 Lugares activos ordenados por sector y nombre
select id, nombre, sector from public.lugares where activo order by sector, nombre;

-- 1.2 Reportes abiertos (pendientes o en reparación), del más nuevo al más viejo
select id, estado, creado_en from public.reportes
where estado in ('pendiente', 'en_reparacion')
order by creado_en desc;

-- 1.3 Goteos con mayor pérdida de agua por día
select canilla, ml_10min, litros_dia from public.goteos where not anulada order by litros_dia desc;

-- ---------------------------------------------------------------------
-- 2. Consultas con JOIN (dos o más tablas)
-- ---------------------------------------------------------------------
-- 2.1 Reportes con el nombre del lugar, el tipo, el recurso y el autor (4 tablas)
select r.id, l.nombre as lugar, t.nombre as tipo, t.recurso, p.nombre as autor, r.estado
from public.reportes r
join public.lugares l           on l.id = r.lugar_id
join public.tipos_desperdicio t on t.id = r.tipo_id
join public.perfiles p          on p.id = r.autor_id
order by r.creado_en desc;

-- 2.2 Historial de un reporte con el nombre de quien hizo cada cambio
select h.fecha, h.estado_anterior, h.estado_nuevo, p.nombre as usuario, h.comentario
from public.reporte_historial h
left join public.perfiles p on p.id = h.usuario_id
where h.reporte_id = (select min(id) from public.reportes)
order by h.fecha;

-- 2.3 Cantidad de reportes por sector y recurso (JOIN + GROUP BY)
select l.sector, t.recurso, count(*) as cantidad
from public.reportes r
join public.lugares l           on l.id = r.lugar_id
join public.tipos_desperdicio t on t.id = r.tipo_id
where r.estado <> 'anulado'
group by l.sector, t.recurso
order by cantidad desc;

-- 2.4 Consumo semanal de cada medidor: diferencia con la lectura anterior
select m.nombre as medidor, le.fecha_lectura, le.valor,
       le.valor - lag(le.valor) over (partition by le.medidor_id order by le.fecha_lectura) as consumo,
       m.unidad
from public.lecturas le
join public.medidores m on m.id = le.medidor_id
where not le.anulada
order by m.nombre, le.fecha_lectura;

-- 2.5 Lugares que nunca tuvieron reportes (LEFT JOIN)
select l.nombre
from public.lugares l
left join public.reportes r on r.lugar_id = l.id
where r.id is null;

-- 2.6 Resumen por lugar (vista creada en 04_reglas_negocio.sql)
select * from public.resumen_por_lugar where total > 0 order by total desc;

-- 2.7 Tiempo promedio de resolución en horas, por tipo de desperdicio
select t.nombre as tipo,
       round(avg(extract(epoch from (h.fecha - r.creado_en)) / 3600)::numeric, 1) as horas_promedio
from public.reportes r
join public.tipos_desperdicio t on t.id = r.tipo_id
join public.reporte_historial h on h.reporte_id = r.id and h.estado_nuevo = 'resuelto'
group by t.nombre
order by horas_promedio;

-- ---------------------------------------------------------------------
-- 3. INSERT, UPDATE y DELETE (se deshacen al final con ROLLBACK)
-- ---------------------------------------------------------------------
begin;

-- 3.1 INSERT de un lugar y de un reporte de prueba
insert into public.lugares (nombre, sector) values ('Aula de prueba', 'aula');

insert into public.reportes (lugar_id, tipo_id, descripcion, autor_id, es_prueba)
values (
  (select id from public.lugares where nombre = 'Aula de prueba'),
  (select id from public.tipos_desperdicio where nombre = 'Luces encendidas sin uso'),
  'Consulta de prueba',
  (select id from public.perfiles where rol = 'administrador' and activo limit 1),
  true
);

-- El trigger agrega automáticamente la primera fila del historial
select r.id, r.estado, h.estado_nuevo, h.comentario
from public.reportes r
join public.reporte_historial h on h.reporte_id = r.id
where r.descripcion = 'Consulta de prueba';

-- 3.2 UPDATE: cambiar el estado (el historial suma una fila más)
update public.reportes set estado = 'en_reparacion' where descripcion = 'Consulta de prueba';
select estado_anterior, estado_nuevo from public.reporte_historial
where reporte_id = (select id from public.reportes where descripcion = 'Consulta de prueba')
order by fecha;

-- 3.3 UPDATE: baja lógica de una lectura (no se borra, se anula con motivo)
update public.lecturas set anulada = true, motivo_anulacion = 'Prueba de anulación'
where id = (select max(id) from public.lecturas where not anulada);

-- 3.4 DELETE: solo se eliminan registros de prueba
delete from public.reportes where descripcion = 'Consulta de prueba' and es_prueba;
delete from public.lugares where nombre = 'Aula de prueba';

-- 3.5 Restricciones: cada una de estas operaciones tiene que FALLAR.
--     El bloque captura el error y muestra "OK" en la pestaña de mensajes.
do $$
declare admin uuid := (select id from public.perfiles where rol = 'administrador' limit 1);
begin
  begin
    insert into public.goteos (lugar_id, canilla, ml_10min, cargado_por) values (1, 'Prueba', 9000, admin);
    raise notice 'FALLA: se aceptó un goteo de más de 5000 ml';
  exception when check_violation then raise notice 'OK: goteo fuera de rango rechazado';
  end;
  begin
    update public.reportes set estado = 'anulado' where id = (select min(id) from public.reportes);
    raise notice 'FALLA: se anuló un reporte sin motivo';
  exception when check_violation then raise notice 'OK: anulación sin motivo rechazada';
  end;
  begin
    insert into public.lugares (nombre, sector) values ('Aula 1', 'aula');
    raise notice 'FALLA: se aceptó un lugar repetido';
  exception when unique_violation then raise notice 'OK: lugar repetido rechazado';
  end;
  begin
    insert into public.reportes (lugar_id, tipo_id, autor_id)
    select lugar_id, tipo_id, autor_id from public.reportes where estado = 'pendiente' limit 1;
    raise notice 'FALLA: se aceptó un reporte abierto duplicado';
  exception when unique_violation then raise notice 'OK: reporte abierto duplicado rechazado';
  end;
  begin
    insert into public.lecturas (medidor_id, valor, cargado_por)
    select medidor_id, valor - 10, admin from public.lecturas where not anulada order by fecha_lectura desc limit 1;
    raise notice 'FALLA: se aceptó una lectura menor a la anterior';
  exception when raise_exception then raise notice 'OK: lectura menor a la anterior rechazada';
  end;
end $$;

rollback;
