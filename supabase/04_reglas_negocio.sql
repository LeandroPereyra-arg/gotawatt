-- =====================================================================
-- GotaWatt - 04_reglas_negocio.sql : reglas de negocio agregadas en la
-- versión 2 y actualización automática de las pantallas (Realtime).
-- Se puede ejecutar en cualquier momento después de 02_politicas.sql
-- y se puede volver a ejecutar sin problemas.
-- =====================================================================

-- ---------------------------------------------------------------------
-- RN1. No puede haber dos reportes ABIERTOS (pendiente o en reparación)
--      del mismo tipo en el mismo lugar. Evita reportes duplicados.
-- ---------------------------------------------------------------------
create unique index if not exists reportes_abierto_unico
  on public.reportes (lugar_id, tipo_id)
  where estado in ('pendiente', 'en_reparacion');

-- ---------------------------------------------------------------------
-- RN2. Una sola lectura válida por medidor y por día (hora de Argentina).
--      Si se cargó mal, el administrador la anula y se vuelve a cargar.
-- ---------------------------------------------------------------------
create unique index if not exists lecturas_una_por_dia
  on public.lecturas (medidor_id, ((fecha_lectura at time zone 'America/Argentina/Buenos_Aires')::date))
  where not anulada;

-- ---------------------------------------------------------------------
-- RN3. No se pueden cargar registros nuevos sobre un lugar, tipo o
--      medidor dado de baja (inactivo).
-- ---------------------------------------------------------------------
create or replace function public.controlar_catalogo_activo()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_table_name = 'reportes' then
    if not exists (select 1 from public.lugares where id = new.lugar_id and activo) then
      raise exception 'El lugar elegido está dado de baja';
    end if;
    if not exists (select 1 from public.tipos_desperdicio where id = new.tipo_id and activo) then
      raise exception 'El tipo de desperdicio elegido está dado de baja';
    end if;
  elsif tg_table_name = 'lecturas' then
    if not exists (select 1 from public.medidores where id = new.medidor_id and activo) then
      raise exception 'El medidor elegido está dado de baja';
    end if;
  elsif tg_table_name = 'goteos' then
    if not exists (select 1 from public.lugares where id = new.lugar_id and activo) then
      raise exception 'El lugar elegido está dado de baja';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists catalogo_activo_reporte on public.reportes;
create trigger catalogo_activo_reporte
  before insert or update of lugar_id, tipo_id on public.reportes
  for each row execute function public.controlar_catalogo_activo();

drop trigger if exists catalogo_activo_lectura on public.lecturas;
create trigger catalogo_activo_lectura
  before insert on public.lecturas
  for each row execute function public.controlar_catalogo_activo();

drop trigger if exists catalogo_activo_goteo on public.goteos;
create trigger catalogo_activo_goteo
  before insert on public.goteos
  for each row execute function public.controlar_catalogo_activo();

-- ---------------------------------------------------------------------
-- RN4. No se puede dar de baja un lugar o un tipo que tenga reportes
--      abiertos: primero hay que resolverlos o anularlos.
-- ---------------------------------------------------------------------
create or replace function public.controlar_baja_catalogo()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  abiertos int;
begin
  if old.activo and not new.activo then
    if tg_table_name = 'lugares' then
      select count(*) into abiertos from public.reportes
      where lugar_id = old.id and estado in ('pendiente', 'en_reparacion');
    else
      select count(*) into abiertos from public.reportes
      where tipo_id = old.id and estado in ('pendiente', 'en_reparacion');
    end if;
    if abiertos > 0 then
      raise exception 'No se puede dar de baja: tiene % reporte(s) abierto(s)', abiertos;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists baja_lugar on public.lugares;
create trigger baja_lugar
  before update of activo on public.lugares
  for each row execute function public.controlar_baja_catalogo();

drop trigger if exists baja_tipo on public.tipos_desperdicio;
create trigger baja_tipo
  before update of activo on public.tipos_desperdicio
  for each row execute function public.controlar_baja_catalogo();

-- ---------------------------------------------------------------------
-- Vista de resumen: cantidad de reportes por lugar y estado (JOIN + GROUP BY).
-- Respeta los permisos de quien consulta.
-- ---------------------------------------------------------------------
create or replace view public.resumen_por_lugar
with (security_invoker = true) as
select l.id   as lugar_id,
       l.nombre as lugar,
       l.sector,
       count(r.id) filter (where r.estado = 'pendiente')     as pendientes,
       count(r.id) filter (where r.estado = 'en_reparacion') as en_reparacion,
       count(r.id) filter (where r.estado = 'resuelto')      as resueltos,
       count(r.id) filter (where r.estado <> 'anulado')      as total
from public.lugares l
left join public.reportes r on r.lugar_id = l.id
group by l.id, l.nombre, l.sector;

grant select on public.resumen_por_lugar to authenticated;

-- ---------------------------------------------------------------------
-- Realtime: avisa a la app cuando cambian estas tablas para que las
-- pantallas se actualicen solas. Supabase respeta las políticas RLS.
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['reportes', 'reporte_historial', 'lecturas', 'goteos', 'perfiles',
                             'lugares', 'tipos_desperdicio', 'medidores']
    loop
      if not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;
