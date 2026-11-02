// Punto único de acceso a los datos.
// Si hay datos de Supabase en .env se usa la base de datos; si no, el modo demostración.
import { modoDemo } from './supabase'
import * as apiSupabase from './apiSupabase'
import * as apiDemo from './apiDemo'

export { modoDemo }
export const api = modoDemo ? apiDemo : apiSupabase
