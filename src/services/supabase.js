import { createClient } from '@supabase/supabase-js'

// Los datos de conexión se leen del archivo .env (ver .env.example).
// Solo se usa la clave pública "anon": los permisos reales los controla la base de datos.
const url = import.meta.env.VITE_SUPABASE_URL
const clave = import.meta.env.VITE_SUPABASE_ANON_KEY

export const modoDemo = !url || !clave

export const supabase = modoDemo ? null : createClient(url, clave)
