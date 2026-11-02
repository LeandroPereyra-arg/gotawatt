// MODO DEMOSTRACIÓN: se usa cuando no hay datos de Supabase en el archivo .env.
// - Los roles son SIMULADOS: se elige con qué rol entrar, sin contraseña.
// - Los datos son DE PRUEBA (src/data/datos-prueba.json) y se guardan solo en este
//   navegador (localStorage). No se comparten con otros usuarios ni dispositivos.
import base from '../data/datos-prueba.json'
import { achicarFoto, blobADataUrl } from '../utils/fotos'
import { estadosSiguientes, puede, puedeEditarReporte } from '../utils/reglas'

const CLAVE_DATOS = 'gotawatt-demo-datos'
const CLAVE_SESION = 'gotawatt-demo-sesion'
const DIA = 24 * 60 * 60 * 1000

const esperar = (ms = 250) => new Promise((r) => setTimeout(r, ms))
const copia = (x) => JSON.parse(JSON.stringify(x))

function leer(clave) {
  try {
    return JSON.parse(localStorage.getItem(clave))
  } catch {
    return null
  }
}
function escribir(clave, valor) {
  try {
    localStorage.setItem(clave, JSON.stringify(valor))
  } catch {
    // Si el navegador no permite guardar (modo privado o sin espacio), los datos quedan solo en memoria
  }
}

// Convierte los datos de prueba (con "hace_dias") en registros con fechas reales
function datosIniciales() {
  const ahora = Date.now()
  const lunes = new Date()
  lunes.setHours(8, 0, 0, 0)
  lunes.setDate(lunes.getDate() - ((lunes.getDay() + 6) % 7))
  const d = copia(base)
  delete d._aviso
  d.reportes = d.reportes.map((r) => {
    const fecha = new Date(ahora - r.hace_dias * DIA).toISOString()
    const historial = [{ estado_anterior: null, estado_nuevo: 'pendiente', comentario: 'Reporte creado', usuario_id: r.autor_id, fecha }]
    let previo = 'pendiente'
    const pasos = { en_reparacion: ['en_reparacion'], resuelto: ['en_reparacion', 'resuelto'], anulado: ['anulado'] }[r.estado] ?? []
    pasos.forEach((p, i) => {
      historial.push({
        estado_anterior: previo,
        estado_nuevo: p,
        comentario: p === 'anulado' ? r.motivo_anulacion : null,
        usuario_id: p === 'anulado' ? r.autor_id : 'demo-mant',
        fecha: new Date(ahora - r.hace_dias * DIA + (i + 1) * 3 * 3600 * 1000).toISOString()
      })
      previo = p
    })
    const { hace_dias, ...resto } = r
    return { ...resto, foto: null, creado_en: fecha, actualizado_en: historial.at(-1).fecha, es_prueba: true, historial }
  })
  d.lecturas = d.lecturas.map(({ semanas_atras, ...l }) => ({
    ...l,
    fecha_lectura: new Date(lunes.getTime() - semanas_atras * 7 * DIA).toISOString(),
    cargado_por: 'demo-admin',
    anulada: false,
    es_prueba: true
  }))
  d.goteos = d.goteos.map(({ hace_dias, ...g }) => ({
    ...g,
    litros_dia: Math.round(g.ml_10min * 144) / 1000,
    fecha: new Date(ahora - hace_dias * DIA).toISOString(),
    cargado_por: 'demo-admin',
    anulada: false,
    es_prueba: true
  }))
  return d
}

let datos = leer(CLAVE_DATOS) ?? datosIniciales()
const guardar = () => escribir(CLAVE_DATOS, datos)
const siguienteId = (lista) => Math.max(0, ...lista.map((x) => x.id)) + 1

export function restablecerDatos() {
  datos = datosIniciales()
  guardar()
}

// ---------------- Sesión (roles simulados) ----------------
function perfilActual() {
  const id = leer(CLAVE_SESION)
  return datos.perfiles.find((p) => p.id === id) ?? null
}

function exigir(accion) {
  const perfil = perfilActual()
  if (!perfil || !perfil.activo) throw new Error('Tenés que ingresar con un usuario activo.')
  if (accion && !puede(perfil.rol, accion)) throw new Error('Tu rol no tiene permiso para esta acción.')
  return perfil
}

export async function obtenerSesion() {
  const perfil = perfilActual()
  return perfil ? { usuario: { id: perfil.id, correo: `${perfil.rol}@demo` }, perfil: copia(perfil) } : null
}

export async function iniciarDemo(rol) {
  await esperar()
  const perfil = datos.perfiles.find((p) => p.rol === rol && p.activo)
  escribir(CLAVE_SESION, perfil.id)
  return obtenerSesion()
}

export async function iniciarSesion() {
  throw new Error('En modo demostración elegí un rol simulado.')
}

export async function registrarse() {
  throw new Error('En modo demostración no se crean cuentas. Conectá Supabase para usar el registro.')
}

export async function cerrarSesion() {
  try {
    localStorage.removeItem(CLAVE_SESION)
  } catch {
    // sin almacenamiento disponible
  }
}

export function alCambiarSesion() {}

// ---------------- Catálogos ----------------
export async function obtenerCatalogos() {
  await esperar(100)
  return copia({ lugares: datos.lugares, tipos: datos.tipos, medidores: datos.medidores })
}

// ---------------- Reportes ----------------
function conNombres(r) {
  const lugar = datos.lugares.find((l) => l.id === r.lugar_id)
  const tipo = datos.tipos.find((t) => t.id === r.tipo_id)
  const autor = datos.perfiles.find((p) => p.id === r.autor_id)
  const { historial, foto, ...resto } = r
  return { ...resto, lugar: lugar?.nombre, tipo: tipo?.nombre, recurso: tipo?.recurso, autor: autor?.nombre, foto_path: foto }
}

export async function listarReportes({ texto, estado, lugarId, recurso, soloMios, usuarioId } = {}) {
  exigir()
  await esperar()
  const t = String(texto || '').trim().toLowerCase()
  return datos.reportes
    .map(conNombres)
    .filter((r) => {
      if (estado === 'abiertos' && !['pendiente', 'en_reparacion'].includes(r.estado)) return false
      if (estado && estado !== 'abiertos' && r.estado !== estado) return false
      if (lugarId && r.lugar_id !== Number(lugarId)) return false
      if (recurso && r.recurso !== recurso) return false
      if (soloMios && r.autor_id !== usuarioId) return false
      if (t && ![r.lugar, r.tipo, r.descripcion, r.autor].some((v) => v?.toLowerCase().includes(t))) return false
      return true
    })
    .sort((a, b) => new Date(b.creado_en) - new Date(a.creado_en))
}

export async function obtenerReporte(id) {
  exigir()
  await esperar()
  const r = datos.reportes.find((x) => x.id === Number(id))
  if (!r) return null
  const historial = r.historial.map((h) => ({ ...h, usuario: datos.perfiles.find((p) => p.id === h.usuario_id)?.nombre ?? '' }))
  return copia({ ...conNombres(r), historial })
}

export async function urlFoto(foto) {
  return foto || null
}

async function prepararFoto(archivo) {
  return archivo ? blobADataUrl(await achicarFoto(archivo, 640, 0.7)) : null
}

export async function crearReporte({ lugarId, tipoId, descripcion, foto }) {
  const perfil = exigir('crearReporte')
  const imagen = await prepararFoto(foto)
  await esperar()
  const ahora = new Date().toISOString()
  const nuevo = {
    id: siguienteId(datos.reportes),
    lugar_id: Number(lugarId),
    tipo_id: Number(tipoId),
    descripcion: descripcion?.trim() || null,
    foto: imagen,
    estado: 'pendiente',
    autor_id: perfil.id,
    creado_en: ahora,
    actualizado_en: ahora,
    es_prueba: true,
    historial: [{ estado_anterior: null, estado_nuevo: 'pendiente', comentario: 'Reporte creado', usuario_id: perfil.id, fecha: ahora }]
  }
  datos.reportes.push(nuevo)
  guardar()
  return copia(conNombres(nuevo))
}

export async function editarReporte(id, { lugarId, tipoId, descripcion, foto }) {
  const perfil = exigir()
  const r = datos.reportes.find((x) => x.id === Number(id))
  if (!puedeEditarReporte(perfil, r)) throw new Error('No tenés permiso para modificar este reporte.')
  const imagen = await prepararFoto(foto)
  await esperar()
  Object.assign(r, { lugar_id: Number(lugarId), tipo_id: Number(tipoId), descripcion: descripcion?.trim() || null, actualizado_en: new Date().toISOString() })
  if (imagen) r.foto = imagen
  guardar()
}

export async function cambiarEstado(id, estado, motivo = null) {
  const perfil = exigir()
  const r = datos.reportes.find((x) => x.id === Number(id))
  if (!estadosSiguientes(perfil, r).includes(estado)) throw new Error('Tu rol no permite ese cambio de estado.')
  await esperar()
  const ahora = new Date().toISOString()
  r.historial.push({ estado_anterior: r.estado, estado_nuevo: estado, comentario: estado === 'anulado' ? motivo.trim() : null, usuario_id: perfil.id, fecha: ahora })
  r.estado = estado
  if (estado === 'anulado') r.motivo_anulacion = motivo.trim()
  r.actualizado_en = ahora
  guardar()
}

export async function eliminarReporte(id) {
  exigir('eliminarPrueba')
  await esperar()
  const r = datos.reportes.find((x) => x.id === Number(id))
  if (!r?.es_prueba) throw new Error('Solo se pueden eliminar reportes de prueba.')
  datos.reportes = datos.reportes.filter((x) => x.id !== Number(id))
  guardar()
}

// ---------------- Mediciones ----------------
const nombreDe = (id) => datos.perfiles.find((p) => p.id === id)?.nombre ?? ''

export async function listarLecturas({ medidorId, verAnuladas } = {}) {
  exigir()
  await esperar()
  return copia(
    datos.lecturas
      .filter((l) => (!medidorId || l.medidor_id === Number(medidorId)) && (verAnuladas || !l.anulada))
      .map((l) => ({ ...l, cargador: nombreDe(l.cargado_por) }))
      .sort((a, b) => new Date(b.fecha_lectura) - new Date(a.fecha_lectura))
  )
}

export async function crearLectura({ medidorId, valor }) {
  const perfil = exigir('cargarMedicion')
  await esperar()
  const nueva = {
    id: siguienteId(datos.lecturas),
    medidor_id: Number(medidorId),
    valor,
    fecha_lectura: new Date().toISOString(),
    cargado_por: perfil.id,
    anulada: false,
    es_prueba: true
  }
  datos.lecturas.push(nueva)
  guardar()
  return copia(nueva)
}

export async function anularLectura(id, motivo) {
  exigir('corregirMedicion')
  await esperar()
  Object.assign(datos.lecturas.find((l) => l.id === id), { anulada: true, motivo_anulacion: motivo.trim() })
  guardar()
}

export async function listarGoteos({ verAnuladas } = {}) {
  exigir()
  await esperar()
  return copia(
    datos.goteos
      .filter((g) => verAnuladas || !g.anulada)
      .map((g) => ({ ...g, lugar: datos.lugares.find((l) => l.id === g.lugar_id)?.nombre, cargador: nombreDe(g.cargado_por) }))
      .sort((a, b) => new Date(b.fecha) - new Date(a.fecha))
  )
}

export async function crearGoteo({ lugarId, canilla, ml }) {
  const perfil = exigir('cargarMedicion')
  await esperar()
  const nuevo = {
    id: siguienteId(datos.goteos),
    lugar_id: Number(lugarId),
    canilla: canilla.trim(),
    ml_10min: ml,
    litros_dia: Math.round(ml * 144) / 1000,
    fecha: new Date().toISOString(),
    cargado_por: perfil.id,
    anulada: false,
    es_prueba: true
  }
  datos.goteos.push(nuevo)
  guardar()
  return copia(nuevo)
}

export async function anularGoteo(id, motivo) {
  exigir('corregirMedicion')
  await esperar()
  Object.assign(datos.goteos.find((g) => g.id === id), { anulada: true, motivo_anulacion: motivo.trim() })
  guardar()
}

// ---------------- Usuarios ----------------
export async function listarUsuarios() {
  exigir('gestionarUsuarios')
  await esperar()
  return copia(datos.perfiles)
}

export async function actualizarUsuario(id, { rol, activo }) {
  const perfil = exigir('gestionarUsuarios')
  if (id === perfil.id) throw new Error('No podés cambiar tu propio rol ni desactivar tu cuenta.')
  await esperar()
  Object.assign(datos.perfiles.find((p) => p.id === id), { rol, activo })
  guardar()
}
