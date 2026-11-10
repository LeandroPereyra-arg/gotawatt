// Validaciones de formularios. Cada función devuelve un objeto { campo: 'mensaje' }.
// Si el objeto está vacío, el formulario es válido.
import { SECTORES } from './reglas'

const CORREO = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/
const TIPOS_FOTO = ['image/jpeg', 'image/png', 'image/webp']
const MAX_FOTO_MB = 8

const texto = (v) => String(v ?? '').trim()

function numero(v) {
  const limpio = String(v ?? '').trim().replace(',', '.')
  if (limpio === '' || !/^-?\d+(\.\d+)?$/.test(limpio)) return NaN
  return Number(limpio)
}

export function convertirNumero(v) {
  return numero(v)
}

export function validarIngreso({ correo, clave }) {
  const e = {}
  if (!texto(correo)) e.correo = 'Ingresá tu correo.'
  else if (!CORREO.test(texto(correo))) e.correo = 'El correo no tiene un formato válido.'
  if (!clave) e.clave = 'Ingresá tu contraseña.'
  return e
}

export function validarRegistro({ nombre, cursoCargo, correo, clave, clave2 }) {
  const e = validarIngreso({ correo, clave })
  const n = texto(nombre)
  if (!n) e.nombre = 'Ingresá tu nombre y apellido.'
  else if (n.length < 2 || n.length > 80) e.nombre = 'El nombre debe tener entre 2 y 80 caracteres.'
  if (texto(cursoCargo).length > 40) e.cursoCargo = 'Máximo 40 caracteres.'
  if (clave && clave.length < 8) e.clave = 'La contraseña debe tener al menos 8 caracteres.'
  if (clave !== clave2) e.clave2 = 'Las contraseñas no coinciden.'
  return e
}

export function validarReporte({ lugarId, tipoId, descripcion, foto }) {
  const e = {}
  if (!lugarId) e.lugarId = 'Elegí el lugar.'
  if (!tipoId) e.tipoId = 'Elegí el tipo de desperdicio.'
  if (texto(descripcion).length > 300) e.descripcion = 'La descripción admite hasta 300 caracteres.'
  if (foto) {
    if (!TIPOS_FOTO.includes(foto.type)) e.foto = 'La foto debe ser JPG, PNG o WEBP.'
    else if (foto.size > MAX_FOTO_MB * 1024 * 1024) e.foto = `La foto no puede pesar más de ${MAX_FOTO_MB} MB.`
  }
  return e
}

export function validarLectura({ medidorId, valor }, lecturaAnterior = null) {
  const e = {}
  const v = numero(valor)
  if (!medidorId) e.medidorId = 'Elegí el medidor.'
  if (texto(valor) === '') e.valor = 'Ingresá la lectura del medidor.'
  else if (Number.isNaN(v)) e.valor = 'Escribí solo números (podés usar coma para los decimales).'
  else if (v < 0) e.valor = 'La lectura no puede ser negativa.'
  else if (v >= 10000000) e.valor = 'El valor es demasiado grande.'
  else if (!/^\d+([.,]\d{1,2})?$/.test(texto(valor))) e.valor = 'Usá como máximo 2 decimales.'
  else if (lecturaAnterior !== null && v < lecturaAnterior) {
    e.valor = `Un medidor no retrocede: la lectura anterior fue ${lecturaAnterior}.`
  }
  return e
}

export function validarGoteo({ lugarId, canilla, ml }) {
  const e = {}
  const v = numero(ml)
  if (!lugarId) e.lugarId = 'Elegí el lugar.'
  if (!texto(canilla)) e.canilla = 'Indicá qué canilla (por ejemplo: Izquierda).'
  else if (texto(canilla).length > 40) e.canilla = 'Máximo 40 caracteres.'
  if (texto(ml) === '') e.ml = 'Ingresá los mililitros juntados en 10 minutos.'
  else if (Number.isNaN(v)) e.ml = 'Escribí solo números.'
  else if (v <= 0 || v > 5000) e.ml = 'El valor debe estar entre 0,1 y 5000 ml.'
  return e
}

// Lugar, tipo de desperdicio o medidor. "existentes" sirve para evitar nombres repetidos.
export function validarCatalogo(tabla, { nombre, sector, recurso }, existentes = [], idActual = null) {
  const e = {}
  const n = texto(nombre)
  const minimo = tabla === 'lugares' ? 2 : 3
  if (!n) e.nombre = 'Ingresá el nombre.'
  else if (n.length < minimo || n.length > 60) e.nombre = `El nombre debe tener entre ${minimo} y 60 caracteres.`
  else if (existentes.some((x) => x.id !== idActual && x.nombre.trim().toLowerCase() === n.toLowerCase())) {
    e.nombre = 'Ya existe uno con ese nombre.'
  }
  if (tabla === 'lugares' && !SECTORES.includes(sector)) e.sector = 'Elegí el sector.'
  if (tabla !== 'lugares' && !['agua', 'luz'].includes(recurso)) e.recurso = 'Elegí si es de agua o de luz.'
  return e
}

export function validarMotivo(motivo) {
  const m = texto(motivo)
  if (m.length < 5) return 'Explicá el motivo (al menos 5 caracteres).'
  if (m.length > 200) return 'El motivo admite hasta 200 caracteres.'
  return ''
}

export const hayErrores = (e) => Object.keys(e).length > 0
