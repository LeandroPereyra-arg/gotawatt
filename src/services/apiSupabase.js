// Acceso a los datos en Supabase.
import { supabase } from './supabase'
import { achicarFoto } from '../utils/fotos'

// Traduce los errores de Supabase a mensajes claros
function revisar({ data, error }, mensaje = 'No se pudo completar la operación.') {
  if (error) {
    console.error(error)
    let detalle = error.message || ''
    if (/Invalid login credentials/i.test(detalle)) detalle = 'Correo o contraseña incorrectos.'
    else if (/Email not confirmed/i.test(detalle)) detalle = 'Tenés que confirmar tu correo antes de ingresar.'
    else if (/User already registered/i.test(detalle)) detalle = 'Ya existe una cuenta con ese correo.'
    else if (/row-level security|permission denied/i.test(detalle)) detalle = 'Tu rol no tiene permiso para esta acción.'
    else if (/Failed to fetch|NetworkError/i.test(detalle)) detalle = 'No hay conexión con el servidor. Revisá tu internet.'
    throw new Error(detalle ? `${mensaje} ${detalle}` : mensaje)
  }
  return data
}

// Limpia el texto de búsqueda para usarlo en un filtro
const limpiar = (t) => String(t || '').replace(/[%,()*\\]/g, ' ').trim()

// ---------------- Sesión ----------------
export async function obtenerSesion() {
  const { data } = await supabase.auth.getSession()
  const usuario = data.session?.user
  if (!usuario) return null
  const perfil = revisar(
    await supabase.from('perfiles').select('*').eq('id', usuario.id).maybeSingle(),
    'No se pudo leer tu perfil.'
  )
  return { usuario: { id: usuario.id, correo: usuario.email }, perfil }
}

export async function iniciarSesion(correo, clave) {
  revisar(await supabase.auth.signInWithPassword({ email: correo.trim(), password: clave }), 'No se pudo ingresar.')
  return obtenerSesion()
}

export async function registrarse({ correo, clave, nombre, cursoCargo }) {
  const data = revisar(
    await supabase.auth.signUp({
      email: correo.trim(),
      password: clave,
      options: { data: { nombre: nombre.trim(), curso_cargo: cursoCargo.trim() } }
    }),
    'No se pudo crear la cuenta.'
  )
  return { requiereConfirmacion: !data.session }
}

export async function cerrarSesion() {
  revisar(await supabase.auth.signOut(), 'No se pudo cerrar la sesión.')
}

export function alCambiarSesion(funcion) {
  supabase.auth.onAuthStateChange((evento) => {
    if (evento === 'SIGNED_OUT' || evento === 'TOKEN_REFRESHED') funcion(evento)
  })
}

// ---------------- Catálogos ----------------
export async function obtenerCatalogos() {
  const [lugares, tipos, medidores] = await Promise.all([
    supabase.from('lugares').select('*').eq('activo', true).order('nombre'),
    supabase.from('tipos_desperdicio').select('*').eq('activo', true).order('nombre'),
    supabase.from('medidores').select('*').eq('activo', true).order('nombre')
  ])
  return {
    lugares: revisar(lugares, 'No se pudieron cargar los lugares.'),
    tipos: revisar(tipos, 'No se pudieron cargar los tipos.'),
    medidores: revisar(medidores, 'No se pudieron cargar los medidores.')
  }
}

// ---------------- Reportes ----------------
export async function listarReportes({ texto, estado, lugarId, recurso, soloMios, usuarioId } = {}) {
  let q = supabase.from('reportes_detalle').select('*').order('creado_en', { ascending: false })
  if (estado === 'abiertos') q = q.in('estado', ['pendiente', 'en_reparacion'])
  else if (estado) q = q.eq('estado', estado)
  if (lugarId) q = q.eq('lugar_id', lugarId)
  if (recurso) q = q.eq('recurso', recurso)
  if (soloMios && usuarioId) q = q.eq('autor_id', usuarioId)
  const t = limpiar(texto)
  if (t) q = q.or(`lugar.ilike.%${t}%,tipo.ilike.%${t}%,descripcion.ilike.%${t}%,autor.ilike.%${t}%`)
  return revisar(await q, 'No se pudieron cargar los reportes.')
}

export async function obtenerReporte(id) {
  const reporte = revisar(
    await supabase.from('reportes_detalle').select('*').eq('id', id).maybeSingle(),
    'No se pudo cargar el reporte.'
  )
  if (!reporte) return null
  const historial = revisar(
    await supabase
      .from('reporte_historial')
      .select('*, usuario:perfiles(nombre)')
      .eq('reporte_id', id)
      .order('fecha'),
    'No se pudo cargar el historial.'
  )
  return { ...reporte, historial: historial.map((h) => ({ ...h, usuario: h.usuario?.nombre ?? '' })) }
}

async function subirFoto(archivo, usuarioId) {
  const blob = await achicarFoto(archivo)
  const ruta = `${usuarioId}/${Date.now()}.jpg`
  revisar(
    await supabase.storage.from('fotos').upload(ruta, blob, { contentType: 'image/jpeg' }),
    'No se pudo subir la foto.'
  )
  return ruta
}

export async function urlFoto(ruta) {
  if (!ruta) return null
  const { data, error } = await supabase.storage.from('fotos').createSignedUrl(ruta, 3600)
  return error ? null : data.signedUrl
}

export async function crearReporte({ lugarId, tipoId, descripcion, foto }, usuarioId) {
  const foto_path = foto ? await subirFoto(foto, usuarioId) : null
  return revisar(
    await supabase
      .from('reportes')
      .insert({ lugar_id: lugarId, tipo_id: tipoId, descripcion: descripcion?.trim() || null, foto_path, autor_id: usuarioId })
      .select()
      .single(),
    'No se pudo guardar el reporte.'
  )
}

export async function editarReporte(id, { lugarId, tipoId, descripcion, foto }, usuarioId) {
  const cambios = { lugar_id: lugarId, tipo_id: tipoId, descripcion: descripcion?.trim() || null }
  if (foto) cambios.foto_path = await subirFoto(foto, usuarioId)
  const filas = revisar(await supabase.from('reportes').update(cambios).eq('id', id).select(), 'No se pudo modificar el reporte.')
  if (!filas.length) throw new Error('No tenés permiso para modificar este reporte.')
}

export async function cambiarEstado(id, estado, motivo = null) {
  const cambios = { estado }
  if (estado === 'anulado') cambios.motivo_anulacion = motivo.trim()
  const filas = revisar(await supabase.from('reportes').update(cambios).eq('id', id).select(), 'No se pudo cambiar el estado.')
  if (!filas.length) throw new Error('No tenés permiso para cambiar el estado de este reporte.')
}

export async function eliminarReporte(id) {
  const filas = revisar(await supabase.from('reportes').delete().eq('id', id).select(), 'No se pudo eliminar.')
  if (!filas.length) throw new Error('Solo se pueden eliminar reportes de prueba.')
}

// ---------------- Mediciones ----------------
export async function listarLecturas({ medidorId, verAnuladas } = {}) {
  let q = supabase.from('lecturas').select('*, cargador:perfiles(nombre)').order('fecha_lectura', { ascending: false })
  if (medidorId) q = q.eq('medidor_id', medidorId)
  if (!verAnuladas) q = q.eq('anulada', false)
  const datos = revisar(await q, 'No se pudieron cargar las lecturas.')
  return datos.map((l) => ({ ...l, cargador: l.cargador?.nombre ?? '' }))
}

export async function crearLectura({ medidorId, valor }, usuarioId) {
  return revisar(
    await supabase.from('lecturas').insert({ medidor_id: medidorId, valor, cargado_por: usuarioId }).select().single(),
    'No se pudo guardar la lectura.'
  )
}

export async function anularLectura(id, motivo) {
  const filas = revisar(
    await supabase.from('lecturas').update({ anulada: true, motivo_anulacion: motivo.trim() }).eq('id', id).select(),
    'No se pudo anular la lectura.'
  )
  if (!filas.length) throw new Error('Solo el administrador puede anular lecturas.')
}

export async function listarGoteos({ verAnuladas } = {}) {
  let q = supabase.from('goteos').select('*, lugar:lugares(nombre), cargador:perfiles(nombre)').order('fecha', { ascending: false })
  if (!verAnuladas) q = q.eq('anulada', false)
  const datos = revisar(await q, 'No se pudieron cargar los goteos.')
  return datos.map((g) => ({ ...g, lugar: g.lugar?.nombre ?? '', cargador: g.cargador?.nombre ?? '' }))
}

export async function crearGoteo({ lugarId, canilla, ml }, usuarioId) {
  return revisar(
    await supabase.from('goteos').insert({ lugar_id: lugarId, canilla: canilla.trim(), ml_10min: ml, cargado_por: usuarioId }).select().single(),
    'No se pudo guardar la medición de goteo.'
  )
}

export async function anularGoteo(id, motivo) {
  const filas = revisar(
    await supabase.from('goteos').update({ anulada: true, motivo_anulacion: motivo.trim() }).eq('id', id).select(),
    'No se pudo anular la medición.'
  )
  if (!filas.length) throw new Error('Solo el administrador puede anular mediciones.')
}

// ---------------- Usuarios ----------------
export async function listarUsuarios() {
  return revisar(await supabase.from('perfiles').select('*').order('creado_en'), 'No se pudieron cargar los usuarios.')
}

export async function actualizarUsuario(id, { rol, activo }) {
  const filas = revisar(await supabase.from('perfiles').update({ rol, activo }).eq('id', id).select(), 'No se pudo actualizar el usuario.')
  if (!filas.length) throw new Error('Solo el administrador puede modificar usuarios.')
}
