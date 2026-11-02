<script setup>
import { computed, onMounted, ref } from 'vue'
import { api } from '../services/api'
import { sesion } from '../stores/sesion'
import { consumosPorPeriodo, contarPor } from '../utils/estadisticas'
import { formatoFecha, formatoNumero, m3ALitros } from '../utils/formato'
import { ESTADOS } from '../utils/reglas'
import EstadoCarga from '../components/EstadoCarga.vue'

const cargando = ref(true)
const error = ref('')
const lecturas = ref([])
const reportes = ref([])
const goteos = ref([])

async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    const [l, r, g] = await Promise.all([api.listarLecturas(), api.listarReportes(), api.listarGoteos()])
    lecturas.value = l
    reportes.value = r.filter((x) => x.estado !== 'anulado')
    goteos.value = g
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)

function serie(recurso) {
  const m = sesion.catalogos.medidores.find((x) => x.recurso === recurso)
  if (!m) return []
  const datos = consumosPorPeriodo(lecturas.value, m.id).slice(-8)
  return datos.map((d) => ({ ...d, valor: recurso === 'agua' ? m3ALitros(d.consumo) : d.consumo }))
}
const luz = computed(() => serie('luz'))
const agua = computed(() => serie('agua'))
const maximo = (lista) => Math.max(1, ...lista.map((d) => d.valor))

const sectores = computed(() => {
  const conSector = reportes.value.map((r) => ({
    ...r,
    sector: sesion.catalogos.lugares.find((l) => l.id === r.lugar_id)?.sector ?? 'otro'
  }))
  return contarPor(conSector, 'sector')
})
const totalReportes = computed(() => reportes.value.length)
const resueltos = computed(() => reportes.value.filter((r) => r.estado === 'resuelto').length)
const porEstado = computed(() => contarPor(reportes.value, 'estado'))
// Para no contar dos veces la misma canilla, se toma la última medición de cada una
const litrosGoteo = computed(() => {
  const ultimas = new Map()
  for (const g of goteos.value) {
    const clave = `${g.lugar_id}-${g.canilla.toLowerCase()}`
    if (!ultimas.has(clave)) ultimas.set(clave, g)
  }
  return [...ultimas.values()].reduce((s, g) => s + Number(g.litros_dia), 0)
})

const variacionTotal = (lista) => {
  if (lista.length < 2 || lista[0].valor === 0) return null
  return ((lista.at(-1).valor - lista[0].valor) / lista[0].valor) * 100
}
</script>

<template>
  <div class="encabezado-vista">
    <div>
      <h1>Estadísticas</h1>
      <p class="subtitulo">Cómo evoluciona el consumo y dónde aparecen más desperdicios.</p>
    </div>
  </div>

  <EstadoCarga :cargando="cargando" :error="error" texto="Calculando estadísticas…" @reintentar="cargar" />

  <template v-if="!cargando && !error">
    <div class="grilla grilla-4">
      <div class="tarjeta">
        <div class="texto-gris">Reportes registrados</div>
        <div class="numero-grande">{{ totalReportes }}</div>
      </div>
      <div class="tarjeta">
        <div class="texto-gris">Resueltos</div>
        <div class="numero-grande">{{ totalReportes ? formatoNumero((resueltos / totalReportes) * 100) : 0 }} %</div>
        <div class="texto-gris">{{ resueltos }} de {{ totalReportes }}</div>
      </div>
      <div class="tarjeta">
        <div class="texto-gris">Agua perdida por goteo</div>
        <div class="numero-grande">{{ formatoNumero(litrosGoteo, 1) }} <small>L/día</small></div>
        <div class="texto-gris">≈ {{ formatoNumero(litrosGoteo * 30) }} litros por mes</div>
      </div>
    </div>

    <div class="grilla grilla-2 mt">
      <section v-for="g in [{ titulo: 'Luz por semana', unidad: 'kWh', datos: luz, color: 'var(--amarillo)' }, { titulo: 'Agua por semana', unidad: 'litros', datos: agua, color: 'var(--azul)' }]" :key="g.titulo" class="tarjeta">
        <h2>{{ g.titulo }} <small class="texto-gris">({{ g.unidad }})</small></h2>
        <div v-if="g.datos.length" class="barras" role="img" :aria-label="`${g.titulo}: ` + g.datos.map((d) => `${formatoFecha(d.hasta)} ${formatoNumero(d.valor)} ${g.unidad}`).join(', ')">
          <div v-for="(d, i) in g.datos" :key="i" class="columna">
            <span class="valor">{{ formatoNumero(d.valor) }}</span>
            <div class="barra" :style="{ height: `${(d.valor / maximo(g.datos)) * 100}%`, background: g.color, opacity: i === g.datos.length - 1 ? 1 : 0.45 }"></div>
            <span class="etiqueta">{{ formatoFecha(d.hasta) }}</span>
          </div>
        </div>
        <p v-else class="vacio">Hacen falta al menos dos lecturas para calcular el consumo.</p>
        <p v-if="variacionTotal(g.datos) !== null" :class="variacionTotal(g.datos) <= 0 ? 'texto-verde' : 'texto-rojo'">
          {{ variacionTotal(g.datos) <= 0 ? 'Bajó' : 'Subió' }} {{ formatoNumero(Math.abs(variacionTotal(g.datos)), 1) }} % desde la primera semana registrada.
        </p>
      </section>
    </div>

    <div class="grilla grilla-2 mt">
      <section class="tarjeta">
        <h2>Reportes por sector</h2>
        <ul class="lista">
          <li v-for="s in sectores" :key="s.nombre" class="horizontal">
            <span class="nombre">{{ s.nombre.charAt(0).toUpperCase() + s.nombre.slice(1) }}</span>
            <span class="pista"><span class="relleno" :style="{ width: `${(s.cantidad / sectores[0].cantidad) * 100}%` }"></span></span>
            <span>{{ s.cantidad }}</span>
          </li>
        </ul>
      </section>
      <section class="tarjeta">
        <h2>Reportes por estado</h2>
        <ul class="lista">
          <li v-for="s in porEstado" :key="s.nombre" class="horizontal">
            <span class="nombre">{{ ESTADOS[s.nombre] }}</span>
            <span class="pista"><span class="relleno" :class="s.nombre" :style="{ width: `${(s.cantidad / totalReportes) * 100}%` }"></span></span>
            <span>{{ s.cantidad }}</span>
          </li>
        </ul>
      </section>
    </div>
  </template>
</template>

<style scoped>
.numero-grande small { font-size: 0.9rem; color: var(--gris); }
.barras { display: flex; align-items: flex-end; gap: 0.5rem; height: 190px; padding-top: 1.25rem; }
.columna { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: flex-end; height: 100%; min-width: 0; }
.barra { width: 100%; max-width: 48px; border-radius: 6px 6px 0 0; min-height: 3px; }
.valor { font-size: 0.75rem; font-weight: 700; margin-bottom: 2px; }
.etiqueta { font-size: 0.72rem; color: var(--gris); margin-top: 4px; }
.horizontal { display: grid; grid-template-columns: 110px 1fr 32px; gap: 0.5rem; align-items: center; }
.pista { height: 12px; background: var(--gris-claro); border-radius: 6px; overflow: hidden; }
.relleno { display: block; height: 100%; background: var(--verde); border-radius: 6px; }
.relleno.pendiente { background: var(--rojo); }
.relleno.en_reparacion { background: #d39e1c; }
</style>
