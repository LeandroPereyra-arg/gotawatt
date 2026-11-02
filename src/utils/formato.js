const fechaHora = new Intl.DateTimeFormat('es-AR', {
  day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit'
})
const fechaCorta = new Intl.DateTimeFormat('es-AR', { day: '2-digit', month: '2-digit' })

export const formatoFechaHora = (f) => (f ? fechaHora.format(new Date(f)) : '')
export const formatoFecha = (f) => (f ? fechaCorta.format(new Date(f)) : '')

export function formatoNumero(n, decimales = 0) {
  if (n === null || n === undefined || Number.isNaN(n)) return '–'
  return Number(n).toLocaleString('es-AR', { minimumFractionDigits: decimales, maximumFractionDigits: decimales })
}

export function haceCuanto(f) {
  const min = Math.round((Date.now() - new Date(f).getTime()) / 60000)
  if (min < 1) return 'recién'
  if (min < 60) return `hace ${min} min`
  const h = Math.round(min / 60)
  if (h < 24) return `hace ${h} h`
  const d = Math.round(h / 24)
  return d === 1 ? 'ayer' : `hace ${d} días`
}

// 1 m³ = 1000 litros
export const m3ALitros = (m3) => m3 * 1000
