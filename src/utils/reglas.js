// Reglas del sistema compartidas por la interfaz y el modo demostración.
// En Supabase estas mismas reglas se aplican en la base de datos (supabase/02_politicas.sql).

export const ROLES = {
  administrador: 'Administrador',
  socio: 'Socio relevador',
  docente: 'Docente asesor',
  mantenimiento: 'Mantenimiento'
}

export const ESTADOS = {
  pendiente: 'Pendiente',
  en_reparacion: 'En reparación',
  resuelto: 'Resuelto',
  anulado: 'Anulado'
}

export const SECTORES = ['aula', 'baño', 'laboratorio', 'cocina', 'patio', 'oficina', 'otro']

export const RECURSOS = { agua: 'Agua', luz: 'Luz' }

// Catálogos que administra el administrador
export const CATALOGOS = {
  lugares: { titulo: 'Lugares', singular: 'lugar' },
  tipos_desperdicio: { titulo: 'Tipos de desperdicio', singular: 'tipo de desperdicio' },
  medidores: { titulo: 'Medidores', singular: 'medidor' }
}

// Qué puede hacer cada rol
const PERMISOS = {
  crearReporte: ['administrador', 'socio'],
  cambiarEstado: ['administrador', 'mantenimiento'],
  cargarMedicion: ['administrador', 'socio'],
  corregirMedicion: ['administrador'],
  gestionarUsuarios: ['administrador'],
  gestionarCatalogos: ['administrador'],
  eliminarPrueba: ['administrador']
}

export function puede(rol, accion) {
  return Boolean(rol && PERMISOS[accion]?.includes(rol))
}

// ¿Puede este usuario editar los datos (lugar, tipo, descripción) del reporte?
export function puedeEditarReporte(perfil, reporte) {
  if (!perfil || !reporte) return false
  if (['resuelto', 'anulado'].includes(reporte.estado)) return false
  if (perfil.rol === 'administrador') return true
  return perfil.rol === 'socio' && reporte.autor_id === perfil.id && reporte.estado === 'pendiente'
}

// Estados a los que puede pasar un reporte según el rol (mismo orden que en la base de datos)
export function estadosSiguientes(perfil, reporte) {
  if (!perfil || !reporte) return []
  const { rol } = perfil
  const actual = reporte.estado
  let posibles = []
  if (actual === 'pendiente') posibles = ['en_reparacion', 'resuelto', 'anulado']
  if (actual === 'en_reparacion') posibles = ['pendiente', 'resuelto', 'anulado']
  if (actual === 'resuelto') posibles = rol === 'administrador' ? ['en_reparacion'] : []

  if (rol === 'administrador') return posibles
  if (rol === 'mantenimiento') return posibles.filter((e) => ['en_reparacion', 'resuelto'].includes(e))
  if (rol === 'socio' && reporte.autor_id === perfil.id && actual === 'pendiente') {
    return posibles.filter((e) => e === 'anulado')
  }
  return []
}
