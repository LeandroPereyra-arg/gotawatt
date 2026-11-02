-- =====================================================================
-- GotaWatt - 03_datos_prueba.sql : catálogos y registros simulados
-- Requisito: haber creado tu cuenta en la app y haberte hecho
-- administrador con 00_primer_administrador.sql.
-- Todos los registros simulados quedan con es_prueba = true y la app
-- los muestra con la etiqueta "Prueba".
-- =====================================================================

-- Catálogos (datos reales de la escuela: editalos a gusto)
insert into public.lugares (nombre, sector) values
  ('Aula 1','aula'), ('Aula 2','aula'), ('Aula 3','aula'), ('Aula 4','aula'), ('Aula 5','aula'),
  ('Baño planta baja','baño'), ('Baño 1° piso','baño'), ('Baño 2° piso','baño'),
  ('Laboratorio','laboratorio'), ('Sala de informática','laboratorio'),
  ('Cocina','cocina'), ('Patio','patio'), ('Sala de profesores','oficina'), ('Dirección','oficina')
on conflict (nombre) do nothing;

insert into public.tipos_desperdicio (nombre, recurso) values
  ('Canilla que gotea','agua'), ('Canilla abierta','agua'), ('Mochila de inodoro que pierde','agua'),
  ('Pérdida en cañería','agua'),
  ('Luces encendidas sin uso','luz'), ('Ventilador encendido sin uso','luz'),
  ('Aire acondicionado encendido sin uso','luz'), ('Computadora o proyector encendido sin uso','luz')
on conflict (nombre) do nothing;

insert into public.medidores (nombre, recurso, unidad) values
  ('Medidor de luz principal','luz','kWh'),
  ('Medidor de agua principal','agua','m3')
on conflict (nombre) do nothing;

-- Registros simulados
do $$
declare
  admin uuid;
  r bigint;
  lugar text; tipo text; dias int; est text; descr text;
begin
  select id into admin from public.perfiles where rol = 'administrador' and activo order by creado_en limit 1;
  if admin is null then
    raise exception 'Primero creá tu cuenta en la app y ejecutá 00_primer_administrador.sql';
  end if;

  -- Borra los datos de prueba anteriores para poder volver a cargar el script
  delete from public.reportes where es_prueba;
  delete from public.lecturas where es_prueba;
  delete from public.goteos   where es_prueba;

  for lugar, tipo, dias, est, descr in
    select * from (values
      ('Baño 2° piso','Canilla que gotea', 0, 'pendiente','Gotea fuerte la canilla de la izquierda'),
      ('Laboratorio','Ventilador encendido sin uso', 1, 'en_reparacion','Quedó prendido después de la última hora'),
      ('Aula 5','Luces encendidas sin uso', 2, 'resuelto','Todas las luces prendidas en el recreo'),
      ('Cocina','Mochila de inodoro que pierde', 3, 'pendiente', null),
      ('Aula 2','Luces encendidas sin uso', 4, 'resuelto', null),
      ('Baño planta baja','Canilla abierta', 5, 'resuelto','La encontramos abierta al final del turno'),
      ('Sala de informática','Computadora o proyector encendido sin uso', 6, 'en_reparacion','Proyector encendido toda la tarde'),
      ('Patio','Pérdida en cañería', 8, 'pendiente','Charco permanente cerca del bebedero'),
      ('Aula 3','Aire acondicionado encendido sin uso', 9, 'anulado','Reporte duplicado'),
      ('Baño 1° piso','Canilla que gotea', 12, 'resuelto', null)
    ) as v(lugar, tipo, dias, est, descr)
  loop
    insert into public.reportes (lugar_id, tipo_id, descripcion, autor_id, creado_en, es_prueba)
    values ((select id from public.lugares where nombre = lugar),
            (select id from public.tipos_desperdicio where nombre = tipo),
            descr, admin, now() - make_interval(days => dias, hours => 2), true)
    returning id into r;

    if est = 'en_reparacion' or est = 'resuelto' then
      update public.reportes set estado = 'en_reparacion' where id = r;
    end if;
    if est = 'resuelto' then
      update public.reportes set estado = 'resuelto' where id = r;
    end if;
    if est = 'anulado' then
      update public.reportes set estado = 'anulado', motivo_anulacion = descr where id = r;
    end if;
  end loop;

  -- Lecturas semanales (los lunes a las 8:00)
  insert into public.lecturas (medidor_id, valor, fecha_lectura, cargado_por, es_prueba)
  select m.id, v.valor, date_trunc('week', now()) - make_interval(weeks => v.semanas) + interval '8 hours', admin, true
  from public.medidores m
  join (values
    ('luz', 4, 16667.0), ('luz', 3, 17137.0), ('luz', 2, 17592.0), ('luz', 1, 18040.0), ('luz', 0, 18452.0),
    ('agua', 4, 1203.4),  ('agua', 3, 1213.5),  ('agua', 2, 1223.4),  ('agua', 1, 1233.3),  ('agua', 0, 1242.9)
  ) as v(recurso, semanas, valor) on v.recurso = m.recurso;

  insert into public.goteos (lugar_id, canilla, ml_10min, fecha, cargado_por, es_prueba)
  values
    ((select id from public.lugares where nombre = 'Baño 2° piso'),     'Izquierda', 9.5, now() - interval '1 day', admin, true),
    ((select id from public.lugares where nombre = 'Baño 1° piso'),     'Central',   6.0, now() - interval '12 days', admin, true),
    ((select id from public.lugares where nombre = 'Cocina'),           'Pileta',    14.0, now() - interval '3 days', admin, true);
end $$;
