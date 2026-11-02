// Mensajes breves de confirmación o error que aparecen en pantalla.
import { reactive } from 'vue'

export const avisos = reactive({ lista: [] })
let contador = 0

export function avisar(texto, tipo = 'exito', duracion = 4000) {
  const id = ++contador
  avisos.lista.push({ id, texto, tipo })
  if (avisos.lista.length > 3) avisos.lista.shift() // como máximo 3 a la vez
  setTimeout(() => cerrarAviso(id), tipo === 'error' ? 7000 : duracion)
}

export const avisarError = (error) => avisar(error?.message || String(error), 'error')

export function cerrarAviso(id) {
  avisos.lista = avisos.lista.filter((a) => a.id !== id)
}
