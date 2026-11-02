-- =====================================================================
-- GotaWatt - Cooperativa Escolar
-- 01_estructura.sql : tablas, claves, relaciones y reglas de negocio
-- Ejecutar en Supabase > SQL Editor (en orden: 01, 02, 03).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tablas de catálogo
-- ---------------------------------------------------------------------
create table if not exists public.lugares (
  id        bigint generated always as identity primary key,
  nombre    text not null unique check (char_length(nombre) between 2 and 60),
  sector    text not null check (sector in ('aula','baño','laboratorio','cocina','patio','oficina','otro')),
  activo    boolean not null default true
);

create table if not exists public.tipos_desperdicio (
  id        bigint generated always as identity primary key,
  nombre    text not null unique check (char_length(nombre) between 3 and 60),
  recurso   text not null check (recurso in ('agua','luz')),
  activo    boolean not null default true
);

create table if not exists public.medidores (
  id        bigint generated always as identity primary key,
  nombre    text not null unique check (char_length(nombre) between 3 and 60),
  recurso   text not null check (recurso in ('agua','luz')),
  unidad    text not null check (unidad in ('kWh','m3')),
  activo    boolean not null default true,
  check ((recurso = 'luz' and unidad = 'kWh') or (recurso = 'agua' and unidad = 'm3'))
);

-- ---------------------------------------------------------------------
-- Perfiles: un perfil por cada cuenta de Supabase Auth (auth.users)
-- ---------------------------------------------------------------------
create table if not exists public.perfiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  nombre      text not null check (char_length(nombre) between 2 and 80),
  curso_cargo text check (char_length(curso_cargo) <= 40),
  rol         text not null default 'socio'
              check (rol in ('administrador','socio','docente','mantenimiento')),
  activo      boolean not null default false,   -- el administrador lo habilita
  creado_en   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Reportes de desperdicio
-- ---------------------------------------------------------------------
create table if not exists public.reportes (
  id                bigint generated always as identity primary key,
  lugar_id          bigint not null references public.lugares(id),
  tipo_id           bigint not null references public.tipos_desperdicio(id),
  descripcion       text check (char_length(descripcion) <= 300),
  foto_path         text,                                  -- ruta en Storage (bucket "fotos")
  estado            text not null default 'pendiente'
                    check (estado in ('pendiente','en_reparacion','resuelto','anulado')),
  motivo_anulacion  text check (char_length(motivo_anulacion) <= 200),
  autor_id          uuid not null default auth.uid() references public.perfiles(id),
  creado_en         timestamptz not null default now(),
  actualizado_en    timestamptz not null default now(),
  es_prueba         boolean not null default false,        -- datos simulados para pruebas
  check (estado <> 'anulado' or motivo_anulacion is not null)
);

create index if not exists reportes_estado_idx on public.reportes (estado);
create index if not exists reportes_lugar_idx  on public.reportes (lugar_id);
create index if not exists reportes_fecha_idx  on public.reportes (creado_en desc);

-- Historial de cambios de estado (no se borra nunca)
create table if not exists public.reporte_historial (
  id               bigint generated always as identity primary key,
  reporte_id       bigint not null references public.reportes(id) on delete cascade,
  estado_anterior  text,
  estado_nuevo     text not null,
  comentario       text,
  usuario_id       uuid references public.perfiles(id),
  fecha            timestamptz not null default now()
);

create index if not exists historial_reporte_idx on public.reporte_historial (reporte_id, fecha);

-- ---------------------------------------------------------------------
-- Mediciones
-- ---------------------------------------------------------------------
create table if not exists public.lecturas (
  id                bigint generated always as identity primary key,
  medidor_id        bigint not null references public.medidores(id),
  valor             numeric(12,2) not null check (valor >= 0 and valor < 10000000),
  fecha_lectura     timestamptz not null default now(),
  cargado_por       uuid not null default auth.uid() references public.perfiles(id),
  anulada           boolean not null default false,
  motivo_anulacion  text check (char_length(motivo_anulacion) <= 200),
  es_prueba         boolean not null default false,
  check (not anulada or motivo_anulacion is not null)
);

create index if not exists lecturas_medidor_fecha_idx on public.lecturas (medidor_id, fecha_lectura desc);

create table if not exists public.goteos (
  id                bigint generated always as identity primary key,
  lugar_id          bigint not null references public.lugares(id),
  canilla           text not null check (char_length(canilla) between 1 and 40),
  ml_10min          numeric(8,1) not null check (ml_10min > 0 and ml_10min <= 5000),
  litros_dia        numeric(10,2) generated always as (round(ml_10min * 144 / 1000, 2)) stored,
  fecha             timestamptz not null default now(),
  cargado_por       uuid not null default auth.uid() references public.perfiles(id),
  anulada           boolean not null default false,
  motivo_anulacion  text check (char_length(motivo_anulacion) <= 200),
  es_prueba         boolean not null default false,
  check (not anulada or motivo_anulacion is not null)
);

-- ---------------------------------------------------------------------
-- Funciones auxiliares de permisos
-- (security definer: leen perfiles sin quedar bloqueadas por RLS)
-- ---------------------------------------------------------------------
create or replace function public.rol_actual()
returns text
language sql stable security definer set search_path = public
as $$
  select rol from public.perfiles where id = auth.uid() and activo
$$;

create or replace function public.usuario_activo()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.perfiles where id = auth.uid() and activo)
$$;

-- ---------------------------------------------------------------------
-- Crear el perfil automáticamente al registrarse (queda inactivo)
-- ---------------------------------------------------------------------
create or replace function public.crear_perfil()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.perfiles (id, nombre, curso_cargo)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data->>'nombre'), ''), split_part(new.email, '@', 1)),
    nullif(trim(new.raw_user_meta_data->>'curso_cargo'), '')
  );
  return new;
end;
$$;

drop trigger if exists al_registrarse on auth.users;
create trigger al_registrarse
  after insert on auth.users
  for each row execute function public.crear_perfil();

-- ---------------------------------------------------------------------
-- Reglas de los reportes: qué puede cambiar cada rol y en qué orden
-- ---------------------------------------------------------------------
create or replace function public.controlar_reporte()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  r text := public.rol_actual();
begin
  -- Cuando lo ejecuta el propio SQL Editor (sin usuario), no se controla.
  if auth.uid() is null then
    new.actualizado_en := now();
    return new;
  end if;

  if new.autor_id <> old.autor_id or new.creado_en <> old.creado_en or new.es_prueba <> old.es_prueba then
    raise exception 'No se puede cambiar el autor, la fecha ni la marca de prueba';
  end if;

  if old.estado in ('resuelto','anulado') and new.estado = old.estado then
    raise exception 'Un reporte % no se puede editar', old.estado;
  end if;

  if r = 'mantenimiento' then
    if (new.lugar_id, new.tipo_id, coalesce(new.descripcion,''), coalesce(new.foto_path,''))
       is distinct from (old.lugar_id, old.tipo_id, coalesce(old.descripcion,''), coalesce(old.foto_path,'')) then
      raise exception 'Mantenimiento solo puede cambiar el estado';
    end if;
    if new.estado not in ('en_reparacion','resuelto') then
      raise exception 'Mantenimiento solo puede marcar En reparación o Resuelto';
    end if;
  elsif r = 'socio' then
    if old.autor_id <> auth.uid() or old.estado <> 'pendiente' then
      raise exception 'Solo podés modificar tus propios reportes pendientes';
    end if;
    if new.estado not in ('pendiente','anulado') then
      raise exception 'Un socio solo puede editar o anular su reporte';
    end if;
  elsif r is distinct from 'administrador' then
    raise exception 'Tu rol no permite modificar reportes';
  end if;

  -- Orden válido de estados
  if new.estado <> old.estado then
    if not (
      (old.estado = 'pendiente'     and new.estado in ('en_reparacion','resuelto','anulado')) or
      (old.estado = 'en_reparacion' and new.estado in ('pendiente','resuelto','anulado')) or
      (old.estado = 'resuelto'      and new.estado = 'en_reparacion' and r = 'administrador')
    ) then
      raise exception 'No se puede pasar de % a %', old.estado, new.estado;
    end if;
  end if;

  new.actualizado_en := now();
  return new;
end;
$$;

drop trigger if exists antes_de_actualizar_reporte on public.reportes;
create trigger antes_de_actualizar_reporte
  before update on public.reportes
  for each row execute function public.controlar_reporte();

-- Registrar automáticamente cada alta y cada cambio de estado
create or replace function public.registrar_historial()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.reporte_historial (reporte_id, estado_anterior, estado_nuevo, comentario, usuario_id)
    values (new.id, null, new.estado, 'Reporte creado', new.autor_id);
  elsif new.estado <> old.estado then
    insert into public.reporte_historial (reporte_id, estado_anterior, estado_nuevo, comentario, usuario_id)
    values (new.id, old.estado, new.estado,
            case when new.estado = 'anulado' then new.motivo_anulacion end,
            coalesce(auth.uid(), new.autor_id));
  end if;
  return new;
end;
$$;

drop trigger if exists despues_de_guardar_reporte on public.reportes;
create trigger despues_de_guardar_reporte
  after insert or update on public.reportes
  for each row execute function public.registrar_historial();

-- ---------------------------------------------------------------------
-- Vista con nombres listos para mostrar (respeta los permisos de quien consulta)
-- ---------------------------------------------------------------------
create or replace view public.reportes_detalle
with (security_invoker = true) as
select r.*,
       l.nombre  as lugar,
       t.nombre  as tipo,
       t.recurso as recurso,
       p.nombre  as autor
from public.reportes r
join public.lugares l           on l.id = r.lugar_id
join public.tipos_desperdicio t on t.id = r.tipo_id
left join public.perfiles p     on p.id = r.autor_id;

-- ---------------------------------------------------------------------
-- Un medidor no retrocede: la lectura nueva no puede ser menor que la
-- última lectura válida (no anulada) del mismo medidor.
-- ---------------------------------------------------------------------
create or replace function public.controlar_lectura()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  anterior numeric;
begin
  select valor into anterior
  from public.lecturas
  where medidor_id = new.medidor_id and not anulada and fecha_lectura < new.fecha_lectura
  order by fecha_lectura desc
  limit 1;
  if anterior is not null and new.valor < anterior then
    raise exception 'Un medidor no retrocede: la lectura anterior fue %', anterior;
  end if;
  return new;
end;
$$;

drop trigger if exists antes_de_cargar_lectura on public.lecturas;
create trigger antes_de_cargar_lectura
  before insert on public.lecturas
  for each row execute function public.controlar_lectura();
