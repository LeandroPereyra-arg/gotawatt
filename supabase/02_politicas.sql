-- =====================================================================
-- GotaWatt - 02_politicas.sql : permisos sobre los datos (Row Level Security)
-- Los permisos se aplican en la base de datos, no solo en la interfaz.
--   administrador : todo
--   socio         : carga reportes y mediciones; edita/anula sus reportes pendientes
--   mantenimiento : ve reportes y cambia su estado
--   docente       : solo consulta
--   cuenta inactiva o sin sesión : no ve nada
-- Nadie puede borrar registros reales: se anulan para conservar el historial.
-- El administrador solo puede eliminar registros marcados como de prueba.
-- =====================================================================

alter table public.lugares            enable row level security;
alter table public.tipos_desperdicio  enable row level security;
alter table public.medidores          enable row level security;
alter table public.perfiles           enable row level security;
alter table public.reportes           enable row level security;
alter table public.reporte_historial  enable row level security;
alter table public.lecturas           enable row level security;
alter table public.goteos             enable row level security;

-- Por si se vuelve a ejecutar el script
do $$
declare p record;
begin
  for p in select policyname, tablename from pg_policies
           where schemaname = 'public'
             and tablename in ('lugares','tipos_desperdicio','medidores','perfiles','reportes',
                               'reporte_historial','lecturas','goteos')
  loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Catálogos: los ve cualquier usuario activo, los modifica el administrador
-- ---------------------------------------------------------------------
create policy "catalogo lugares: ver"       on public.lugares           for select to authenticated using (public.usuario_activo());
create policy "catalogo lugares: admin"     on public.lugares           for all    to authenticated using (public.rol_actual() = 'administrador') with check (public.rol_actual() = 'administrador');
create policy "catalogo tipos: ver"         on public.tipos_desperdicio for select to authenticated using (public.usuario_activo());
create policy "catalogo tipos: admin"       on public.tipos_desperdicio for all    to authenticated using (public.rol_actual() = 'administrador') with check (public.rol_actual() = 'administrador');
create policy "catalogo medidores: ver"     on public.medidores         for select to authenticated using (public.usuario_activo());
create policy "catalogo medidores: admin"   on public.medidores         for all    to authenticated using (public.rol_actual() = 'administrador') with check (public.rol_actual() = 'administrador');

-- ---------------------------------------------------------------------
-- Perfiles
-- ---------------------------------------------------------------------
create policy "perfiles: ver el propio"      on public.perfiles for select to authenticated using (id = auth.uid());
create policy "perfiles: activos ven nombres" on public.perfiles for select to authenticated using (public.usuario_activo());
create policy "perfiles: admin modifica"     on public.perfiles for update to authenticated
  using (public.rol_actual() = 'administrador')
  with check (public.rol_actual() = 'administrador');
-- El administrador no puede quitarse a sí mismo el rol ni desactivarse (evita quedar sin administrador)
create or replace function public.proteger_admin()
returns trigger language plpgsql as $$
begin
  if old.id = auth.uid() and (new.rol <> old.rol or not new.activo) then
    raise exception 'No podés cambiar tu propio rol ni desactivar tu cuenta';
  end if;
  return new;
end $$;
drop trigger if exists proteger_admin on public.perfiles;
create trigger proteger_admin before update on public.perfiles
  for each row execute function public.proteger_admin();

-- ---------------------------------------------------------------------
-- Reportes
-- ---------------------------------------------------------------------
create policy "reportes: ver" on public.reportes for select to authenticated
  using (public.usuario_activo());

create policy "reportes: crear" on public.reportes for insert to authenticated
  with check (
    public.rol_actual() in ('administrador','socio')
    and autor_id = auth.uid()
    and estado = 'pendiente'
  );

create policy "reportes: modificar" on public.reportes for update to authenticated
  using (
    public.rol_actual() in ('administrador','mantenimiento')
    or (public.rol_actual() = 'socio' and autor_id = auth.uid())
  )
  with check (public.rol_actual() in ('administrador','mantenimiento','socio'));
  -- El detalle de qué campo puede cambiar cada rol lo controla el trigger controlar_reporte().

create policy "reportes: eliminar solo prueba" on public.reportes for delete to authenticated
  using (public.rol_actual() = 'administrador' and es_prueba);

create policy "historial: ver" on public.reporte_historial for select to authenticated
  using (public.usuario_activo());
-- Sin políticas de insert/update/delete: el historial lo escribe solo el trigger.

-- ---------------------------------------------------------------------
-- Lecturas de medidores y goteos
-- ---------------------------------------------------------------------
create policy "lecturas: ver" on public.lecturas for select to authenticated
  using (public.usuario_activo());
create policy "lecturas: cargar" on public.lecturas for insert to authenticated
  with check (public.rol_actual() in ('administrador','socio') and cargado_por = auth.uid() and not anulada);
create policy "lecturas: corregir o anular" on public.lecturas for update to authenticated
  using (public.rol_actual() = 'administrador') with check (public.rol_actual() = 'administrador');
create policy "lecturas: eliminar solo prueba" on public.lecturas for delete to authenticated
  using (public.rol_actual() = 'administrador' and es_prueba);

create policy "goteos: ver" on public.goteos for select to authenticated
  using (public.usuario_activo());
create policy "goteos: cargar" on public.goteos for insert to authenticated
  with check (public.rol_actual() in ('administrador','socio') and cargado_por = auth.uid() and not anulada);
create policy "goteos: corregir o anular" on public.goteos for update to authenticated
  using (public.rol_actual() = 'administrador') with check (public.rol_actual() = 'administrador');
create policy "goteos: eliminar solo prueba" on public.goteos for delete to authenticated
  using (public.rol_actual() = 'administrador' and es_prueba);

-- ---------------------------------------------------------------------
-- Permisos de tabla: el público anónimo no accede a nada
-- ---------------------------------------------------------------------
revoke all on all tables in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
revoke insert, delete on public.perfiles from authenticated;           -- los crea el trigger de registro
revoke insert, update, delete on public.reporte_historial from authenticated;

-- ---------------------------------------------------------------------
-- Fotos (Supabase Storage, bucket privado "fotos")
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', false, 2097152, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "fotos: ver"   on storage.objects;
drop policy if exists "fotos: subir" on storage.objects;
create policy "fotos: ver" on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and public.usuario_activo());
create policy "fotos: subir" on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and public.rol_actual() in ('administrador','socio')
              and (storage.foldername(name))[1] = auth.uid()::text);
