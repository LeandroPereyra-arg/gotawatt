-- =====================================================================
-- GotaWatt - 00_primer_administrador.sql
-- Ejecutar UNA sola vez, después de crear tu cuenta desde la app.
-- Cambiá el correo por el tuyo. Los demás usuarios los habilita
-- el administrador desde la pantalla "Usuarios" de la app.
-- =====================================================================
update public.perfiles
set rol = 'administrador', activo = true
where id = (select id from auth.users where email = 'tu-correo@ejemplo.com');
