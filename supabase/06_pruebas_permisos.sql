-- =====================================================================
-- GotaWatt - 06_pruebas_permisos.sql : prueba automática de permisos
-- (RLS) y reglas de negocio, simulando cada rol.
--
-- Cómo usarlo: pegar todo en Supabase > SQL Editor y ejecutar.
-- Al final aparece una tabla con cada caso, el resultado esperado, el
-- obtenido y si coincide (columna "ok").
--
-- Qué hace:
--   1. Crea usuarios de prueba temporales (uno por rol y uno inactivo).
--   2. Ejecuta cada operación "como si" fuera ese usuario: cambia al rol
--      "authenticated" de Supabase y carga su identificador, igual que
--      cuando la app hace una consulta con la sesión iniciada.
--   3. Cada operación se deshace apenas termina, así que no cambia datos.
--   4. Al final borra los usuarios de prueba y lo que se creó para ellos.
-- Requisito: haber ejecutado 01, 02, 03 y 04.
-- =====================================================================

drop table if exists pg_temp.resultados;
create temp table resultados (
  n         serial,
  caso      text,
  usuario   text,
  esperado  text,
  obtenido  text,
  detalle   text
);

-- Ejecuta una sentencia como el usuario indicado y anota si se permitió o se bloqueó.
-- "Permitido" = no dio error y afectó o devolvió al menos una fila.
create or replace function pg_temp.probar(p_caso text, p_usuario text, p_sql text, p_debe_permitir boolean)
returns void
language plpgsql
as $$
declare
  uid   uuid;
  filas int := 0;
  res   text;
  det   text := '';
begin
  if p_usuario <> 'anonimo' then
    select id into uid from auth.users where email = p_usuario || '@prueba.gotawatt';
  end if;

  begin
    perform set_config('request.jwt.claims',
      case when uid is null then '{"role":"anon"}'
           else json_build_object('sub', uid, 'role', 'authenticated')::text end, true);
    execute case when uid is null then 'set local role anon' else 'set local role authenticated' end;
    execute p_sql;
    get diagnostics filas = row_count;
    -- Se lanza un error a propósito para deshacer lo que hizo la sentencia
    raise exception using errcode = 'ZZ001', message = 'deshacer';
  exception
    when sqlstate 'ZZ001' then
      res := case when filas > 0 then 'permitido' else 'bloqueado' end;
      if filas = 0 then det := 'ninguna fila (lo filtra RLS)'; end if;
    when others then
      res := 'bloqueado';
      det := sqlerrm;
  end;

  reset role;
  perform set_config('request.jwt.claims', '', true);

  insert into resultados (caso, usuario, esperado, obtenido, detalle)
  values (p_caso, p_usuario, case when p_debe_permitir then 'permitido' else 'bloqueado' end, res, det);
end;
$$;

-- ---------------------------------------------------------------------
-- Datos temporales para las pruebas
-- ---------------------------------------------------------------------
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_user_meta_data, created_at, updated_at)
select gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u || '@prueba.gotawatt', '', json_build_object('nombre', 'Prueba ' || u)::jsonb, now(), now()
from unnest(array['admin', 'socio', 'socio2', 'mantenimiento', 'docente', 'inactivo']) as u;

update public.perfiles p set activo = true,
       rol = case split_part(u.email, '@', 1)
               when 'admin' then 'administrador' when 'socio2' then 'socio' else split_part(u.email, '@', 1) end
from auth.users u
where u.id = p.id and u.email like '%@prueba.gotawatt' and u.email <> 'inactivo@prueba.gotawatt';

insert into public.lugares (nombre, sector, activo) values
  ('Lugar de prueba RLS', 'otro', true), ('Lugar de prueba dado de baja', 'otro', false);
insert into public.medidores (nombre, recurso, unidad) values ('Medidor de prueba RLS', 'luz', 'kWh');

insert into public.lecturas (medidor_id, valor, fecha_lectura, cargado_por, es_prueba)
select m.id, 100, now() - interval '2 days', u.id, true
from public.medidores m, auth.users u
where m.nombre = 'Medidor de prueba RLS' and u.email = 'admin@prueba.gotawatt';

-- Un reporte pendiente del socio y uno de prueba del socio2
insert into public.reportes (lugar_id, tipo_id, descripcion, autor_id, es_prueba)
select l.id, t.id, 'Reporte del socio', u.id, false
from public.lugares l, public.tipos_desperdicio t, auth.users u
where l.nombre = 'Lugar de prueba RLS' and t.nombre = 'Canilla que gotea' and u.email = 'socio@prueba.gotawatt';

insert into public.reportes (lugar_id, tipo_id, descripcion, autor_id, es_prueba)
select l.id, t.id, 'Reporte del socio2', u.id, true
from public.lugares l, public.tipos_desperdicio t, auth.users u
where l.nombre = 'Lugar de prueba RLS' and t.nombre = 'Luces encendidas sin uso' and u.email = 'socio2@prueba.gotawatt';

-- Atajos para escribir las sentencias de prueba
create or replace function pg_temp.rep(p_desc text) returns bigint language sql as
  $$ select id from public.reportes where descripcion = p_desc $$;
create or replace function pg_temp.uid(p_usuario text) returns uuid language sql as
  $$ select id from auth.users where email = p_usuario || '@prueba.gotawatt' $$;

-- ---------------------------------------------------------------------
-- Casos de prueba
-- ---------------------------------------------------------------------
do $$
declare
  lugar   bigint := (select id from public.lugares where nombre = 'Lugar de prueba RLS');
  baja    bigint := (select id from public.lugares where nombre = 'Lugar de prueba dado de baja');
  tipo_ag bigint := (select id from public.tipos_desperdicio where nombre = 'Canilla que gotea');
  tipo_lz bigint := (select id from public.tipos_desperdicio where nombre = 'Ventilador encendido sin uso');
  med     bigint := (select id from public.medidores where nombre = 'Medidor de prueba RLS');
  r_socio bigint := pg_temp.rep('Reporte del socio');
  r_soc2  bigint := pg_temp.rep('Reporte del socio2');
  lect    bigint := (select id from public.lecturas where medidor_id = (select id from public.medidores where nombre = 'Medidor de prueba RLS'));
begin
  -- Acceso a la información
  perform pg_temp.probar('Sin sesión no puede ver reportes', 'anonimo', 'select * from public.reportes', false);
  perform pg_temp.probar('Cuenta sin habilitar no ve reportes', 'inactivo', 'select * from public.reportes', false);
  perform pg_temp.probar('Docente ve los reportes', 'docente', 'select * from public.reportes', true);
  perform pg_temp.probar('Mantenimiento ve los reportes', 'mantenimiento', 'select * from public.reportes', true);
  perform pg_temp.probar('Socio ve la vista reportes_detalle', 'socio', 'select * from public.reportes_detalle', true);

  -- Reportes: alta
  perform pg_temp.probar('Socio crea un reporte', 'socio',
    format('insert into public.reportes (lugar_id, tipo_id) values (%s, %s)', lugar, tipo_lz), true);
  perform pg_temp.probar('Docente no puede crear reportes', 'docente',
    format('insert into public.reportes (lugar_id, tipo_id) values (%s, %s)', lugar, tipo_lz), false);
  perform pg_temp.probar('Mantenimiento no puede crear reportes', 'mantenimiento',
    format('insert into public.reportes (lugar_id, tipo_id) values (%s, %s)', lugar, tipo_lz), false);
  perform pg_temp.probar('Socio no puede crear un reporte a nombre de otro', 'socio',
    format('insert into public.reportes (lugar_id, tipo_id, autor_id) values (%s, %s, %L)', lugar, tipo_lz, pg_temp.uid('socio2')), false);

  -- Reportes: modificación y estados
  perform pg_temp.probar('Socio edita su reporte pendiente', 'socio',
    format('update public.reportes set descripcion = %L where id = %s', 'Editado', r_socio), true);
  perform pg_temp.probar('Socio no puede editar el reporte de otro', 'socio',
    format('update public.reportes set descripcion = %L where id = %s', 'Editado', r_soc2), false);
  perform pg_temp.probar('Socio anula su reporte con motivo', 'socio',
    format('update public.reportes set estado = %L, motivo_anulacion = %L where id = %s', 'anulado', 'Estaba repetido', r_socio), true);
  perform pg_temp.probar('Socio no puede marcar su reporte como resuelto', 'socio',
    format('update public.reportes set estado = %L where id = %s', 'resuelto', r_socio), false);
  perform pg_temp.probar('Mantenimiento marca un reporte en reparación', 'mantenimiento',
    format('update public.reportes set estado = %L where id = %s', 'en_reparacion', r_socio), true);
  perform pg_temp.probar('Mantenimiento no puede cambiar la descripción', 'mantenimiento',
    format('update public.reportes set descripcion = %L where id = %s', 'Otra', r_socio), false);
  perform pg_temp.probar('Mantenimiento no puede anular reportes', 'mantenimiento',
    format('update public.reportes set estado = %L, motivo_anulacion = %L where id = %s', 'anulado', 'No corresponde', r_socio), false);
  perform pg_temp.probar('Docente no puede cambiar estados', 'docente',
    format('update public.reportes set estado = %L where id = %s', 'en_reparacion', r_socio), false);
  perform pg_temp.probar('Administrador cambia el estado de cualquier reporte', 'admin',
    format('update public.reportes set estado = %L where id = %s', 'resuelto', r_soc2), true);

  -- Reportes: eliminación (solo datos de prueba)
  perform pg_temp.probar('Administrador elimina un reporte de prueba', 'admin',
    format('delete from public.reportes where id = %s', r_soc2), true);
  perform pg_temp.probar('Administrador no puede eliminar un reporte real', 'admin',
    format('delete from public.reportes where id = %s', r_socio), false);
  perform pg_temp.probar('Socio no puede eliminar reportes', 'socio',
    format('delete from public.reportes where id = %s', r_soc2), false);
  perform pg_temp.probar('Nadie puede escribir el historial a mano', 'admin',
    format('insert into public.reporte_historial (reporte_id, estado_nuevo) values (%s, %L)', r_socio, 'resuelto'), false);

  -- Mediciones
  perform pg_temp.probar('Socio carga una lectura', 'socio',
    format('insert into public.lecturas (medidor_id, valor) values (%s, 150)', med), true);
  perform pg_temp.probar('Docente no puede cargar lecturas', 'docente',
    format('insert into public.lecturas (medidor_id, valor) values (%s, 150)', med), false);
  perform pg_temp.probar('Socio no puede cargar una lectura a nombre de otro', 'socio',
    format('insert into public.lecturas (medidor_id, valor, cargado_por) values (%s, 150, %L)', med, pg_temp.uid('admin')), false);
  perform pg_temp.probar('Socio no puede anular lecturas', 'socio',
    format('update public.lecturas set anulada = true, motivo_anulacion = %L where id = %s', 'Error de carga', lect), false);
  perform pg_temp.probar('Administrador anula una lectura con motivo', 'admin',
    format('update public.lecturas set anulada = true, motivo_anulacion = %L where id = %s', 'Error de carga', lect), true);
  perform pg_temp.probar('Socio carga una medición de goteo', 'socio',
    format('insert into public.goteos (lugar_id, canilla, ml_10min) values (%s, %L, 9.5)', lugar, 'Izquierda'), true);
  perform pg_temp.probar('Mantenimiento no puede cargar goteos', 'mantenimiento',
    format('insert into public.goteos (lugar_id, canilla, ml_10min) values (%s, %L, 9.5)', lugar, 'Izquierda'), false);

  -- Usuarios y perfiles
  perform pg_temp.probar('Socio no puede cambiarse el rol', 'socio',
    format('update public.perfiles set rol = %L where id = %L', 'administrador', pg_temp.uid('socio')), false);
  perform pg_temp.probar('Socio no puede crear perfiles', 'socio',
    format('insert into public.perfiles (id, nombre) values (%L, %L)', gen_random_uuid(), 'Intruso'), false);
  perform pg_temp.probar('Administrador habilita una cuenta', 'admin',
    format('update public.perfiles set activo = true where id = %L', pg_temp.uid('inactivo')), true);
  perform pg_temp.probar('Administrador no puede quitarse su propio rol', 'admin',
    format('update public.perfiles set rol = %L where id = %L', 'socio', pg_temp.uid('admin')), false);

  -- Catálogos
  perform pg_temp.probar('Socio no puede crear lugares', 'socio',
    'insert into public.lugares (nombre, sector) values (''Lugar intruso'', ''aula'')', false);
  perform pg_temp.probar('Administrador crea un lugar', 'admin',
    'insert into public.lugares (nombre, sector) values (''Lugar nuevo de prueba'', ''aula'')', true);
  perform pg_temp.probar('No se da de baja un lugar con reportes abiertos', 'admin',
    format('update public.lugares set activo = false where id = %s', lugar), false);

  -- Reglas de negocio
  perform pg_temp.probar('No se permite un reporte abierto duplicado', 'socio',
    format('insert into public.reportes (lugar_id, tipo_id) values (%s, %s)', lugar, tipo_ag), false);
  perform pg_temp.probar('Un medidor no retrocede', 'socio',
    format('insert into public.lecturas (medidor_id, valor) values (%s, 50)', med), false);
  perform pg_temp.probar('No se reporta sobre un lugar dado de baja', 'socio',
    format('insert into public.reportes (lugar_id, tipo_id) values (%s, %s)', baja, tipo_lz), false);
end $$;

-- ---------------------------------------------------------------------
-- Limpieza: se borra todo lo que se creó para las pruebas
-- ---------------------------------------------------------------------
delete from public.reportes  where autor_id in (select id from auth.users where email like '%@prueba.gotawatt');
delete from public.lecturas  where cargado_por in (select id from auth.users where email like '%@prueba.gotawatt');
delete from public.goteos    where cargado_por in (select id from auth.users where email like '%@prueba.gotawatt');
delete from public.medidores where nombre = 'Medidor de prueba RLS';
delete from public.lugares   where nombre in ('Lugar de prueba RLS', 'Lugar de prueba dado de baja');
delete from auth.users       where email like '%@prueba.gotawatt';

-- ---------------------------------------------------------------------
-- Resultado
-- ---------------------------------------------------------------------
select n, caso, usuario, esperado, obtenido, esperado = obtenido as ok, detalle
from resultados
order by n;
