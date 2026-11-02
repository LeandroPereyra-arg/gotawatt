// Preferencias de este dispositivo (se guardan en el navegador, no se comparten).
const PREFIJO = 'gotawatt-pref-'

export function leerPreferencia(clave, valorPorDefecto) {
  try {
    const guardado = localStorage.getItem(PREFIJO + clave)
    return guardado ? { ...valorPorDefecto, ...JSON.parse(guardado) } : { ...valorPorDefecto }
  } catch {
    return { ...valorPorDefecto }
  }
}

export function guardarPreferencia(clave, valor) {
  try {
    localStorage.setItem(PREFIJO + clave, JSON.stringify(valor))
  } catch {
    // Si no se puede guardar, la app sigue funcionando igual
  }
}
