// Cálculos a partir de las lecturas de los medidores.
// El consumo de una semana es la diferencia entre dos lecturas seguidas del mismo medidor.

export function consumosPorPeriodo(lecturas, medidorId) {
  const validas = lecturas
    .filter((l) => l.medidor_id === medidorId && !l.anulada)
    .sort((a, b) => new Date(a.fecha_lectura) - new Date(b.fecha_lectura))
  const consumos = []
  for (let i = 1; i < validas.length; i++) {
    consumos.push({
      desde: validas[i - 1].fecha_lectura,
      hasta: validas[i].fecha_lectura,
      consumo: Number(validas[i].valor) - Number(validas[i - 1].valor)
    })
  }
  return consumos
}

export function ultimoConsumo(lecturas, medidorId) {
  const c = consumosPorPeriodo(lecturas, medidorId)
  const actual = c.at(-1) ?? null
  const anterior = c.at(-2) ?? null
  let variacion = null
  if (actual && anterior && anterior.consumo > 0) {
    variacion = ((actual.consumo - anterior.consumo) / anterior.consumo) * 100
  }
  return { actual, anterior, variacion }
}

export function contarPor(lista, clave) {
  const conteo = {}
  for (const item of lista) {
    const k = item[clave] ?? 'Sin dato'
    conteo[k] = (conteo[k] ?? 0) + 1
  }
  return Object.entries(conteo)
    .map(([nombre, cantidad]) => ({ nombre, cantidad }))
    .sort((a, b) => b.cantidad - a.cantidad)
}
