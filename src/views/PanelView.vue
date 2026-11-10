<script setup>
import { computed, ref } from 'vue'
import { api } from '../services/api'
import { sesion, puede } from '../stores/sesion'
import { useCarga } from '../composables/useCarga'
import { useTiempoReal } from '../composables/useTiempoReal'
import { ultimoConsumo } from '../utils/estadisticas'
import { formatoNumero, m3ALitros } from '../utils/formato'
import EstadoCarga from '../components/EstadoCarga.vue'
import TarjetaReporte from '../components/TarjetaReporte.vue'
import IconoSimple from '../components/IconoSimple.vue'

const reportes = ref([])
const lecturas = ref([])

const { cargando, error, cargar } = useCarga(async () => {
  const [r, l] = await Promise.all([api.listarReportes(), api.listarLecturas()])
  reportes.value = r
  lecturas.value = l
})
cargar()
useTiempoReal(['reportes', 'lecturas'], () => cargar({ silencioso: true }))

const medidor = (recurso) => sesion.catalogos.medidores.find((m) => m.recurso === recurso)
const luz = computed(() => (medidor('luz') ? ultimoConsumo(lecturas.value, medidor('luz').id) : {}))
const agua = computed(() => (medidor('agua') ? ultimoConsumo(lecturas.value, medidor('agua').id) : {}))
const pendientes = computed(() => reportes.value.filter((r) => r.estado === 'pendiente').length)
const enReparacion = computed(() => reportes.value.filter((r) => r.estado === 'en_reparacion').length)

// Mantenimiento ve primero lo que tiene que arreglar
const recientes = computed(() => {
  const lista = sesion.perfil.rol === 'mantenimiento'
    ? reportes.value.filter((r) => ['pendiente', 'en_reparacion'].includes(r.estado))
    : reportes.value
  return lista.slice(0, 4)
})

const textoVariacion = (v) => (v === null || v === undefined ? 'sin datos para comparar' : `${v > 0 ? '+' : ''}${formatoNumero(v, 1)} % vs. semana anterior`)
const claseVariacion = (v) => (v === null || v === undefined ? 'texto-gris' : v <= 0 ? 'texto-verde' : 'texto-rojo')
</script>

<template>
  <div class="encabezado-vista">
    <div>
      <h1>Hola, {{ sesion.perfil.nombre.split(' ')[0] }}</h1>
      <p class="subtitulo">Resumen del consumo y de los reportes de la escuela.</p>
    </div>
  </div>

  <EstadoCarga :cargando="cargando" :error="error" texto="Cargando resumen…" @reintentar="cargar" />

  <template v-if="!cargando && !error">
    <div class="grilla grilla-4">
      <div class="tarjeta">
        <div class="texto-gris">Luz · última semana</div>
        <div class="numero-grande">{{ luz.actual ? formatoNumero(luz.actual.consumo) : '–' }} <small>kWh</small></div>
        <div :class="claseVariacion(luz.variacion)">{{ textoVariacion(luz.variacion) }}</div>
      </div>
      <div class="tarjeta">
        <div class="texto-gris">Agua · última semana</div>
        <div class="numero-grande">{{ agua.actual ? formatoNumero(m3ALitros(agua.actual.consumo)) : '–' }} <small>L</small></div>
        <div :class="claseVariacion(agua.variacion)">{{ textoVariacion(agua.variacion) }}</div>
      </div>
      <RouterLink to="/reportes" class="tarjeta enlace-tarjeta abiertos">
        <div class="texto-gris">Reportes abiertos</div>
        <div class="numero-grande">{{ pendientes + enReparacion }}</div>
        <div>{{ pendientes }} pendientes · {{ enReparacion }} en reparación</div>
      </RouterLink>
    </div>

    <div class="fila mt acciones">
      <RouterLink v-if="puede('crearReporte')" to="/reportes/nuevo" class="boton verde">
        <IconoSimple nombre="mas" :tam="20" /> Nuevo reporte
      </RouterLink>
      <RouterLink v-if="puede('cargarMedicion')" to="/mediciones" class="boton">
        <IconoSimple nombre="medir" :tam="20" /> Cargar medición
      </RouterLink>
      <RouterLink v-if="sesion.perfil.rol === 'mantenimiento'" :to="{ path: '/reportes', query: { estado: 'abiertos' } }" class="boton">
        Ver reportes para reparar
      </RouterLink>
      <RouterLink v-if="puede('gestionarCatalogos')" to="/catalogos" class="boton secundario">
        <IconoSimple nombre="catalogo" :tam="20" /> Lugares y medidores
      </RouterLink>
      <RouterLink v-if="sesion.perfil.rol === 'docente'" to="/estadisticas" class="boton">
        <IconoSimple nombre="datos" :tam="20" /> Ver estadísticas
      </RouterLink>
    </div>

    <section class="mt">
      <div class="fila separado">
        <h2>{{ sesion.perfil.rol === 'mantenimiento' ? 'Para reparar' : 'Últimos reportes' }}</h2>
        <RouterLink to="/reportes">Ver todos</RouterLink>
      </div>
      <ul v-if="recientes.length" class="lista">
        <li v-for="r in recientes" :key="r.id"><TarjetaReporte :reporte="r" /></li>
      </ul>
      <p v-else class="vacio tarjeta">No hay reportes para mostrar.</p>
    </section>
  </template>
</template>

<style scoped>
.numero-grande small { font-size: 0.9rem; color: var(--gris); }
.enlace-tarjeta { color: inherit; text-decoration: none; }
.abiertos { background: var(--amarillo-claro); border-color: #f0d79a; }
.abiertos:hover { border-color: var(--amarillo); }
.acciones .boton { flex: 1 1 200px; }
</style>
