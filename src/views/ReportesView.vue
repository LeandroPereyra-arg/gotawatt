<script setup>
import { reactive, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { api } from '../services/api'
import { sesion, puede } from '../stores/sesion'
import { leerPreferencia, guardarPreferencia } from '../stores/preferencias'
import { useCarga } from '../composables/useCarga'
import { useTiempoReal } from '../composables/useTiempoReal'
import { ESTADOS } from '../utils/reglas'
import EstadoCarga from '../components/EstadoCarga.vue'
import TarjetaReporte from '../components/TarjetaReporte.vue'
import IconoSimple from '../components/IconoSimple.vue'

const ruta = useRoute()
const vacios = { texto: '', estado: '', lugarId: '', recurso: '', soloMios: false, orden: 'recientes' }
const ORDENES = {
  recientes: 'Más recientes primero',
  antiguos: 'Más antiguos primero',
  actualizados: 'Últimos actualizados',
  lugar: 'Lugar (A a Z)'
}

// Los filtros se recuerdan en este dispositivo
// Si se llega desde un enlace (por ejemplo, desde Estadísticas) se aplican solo esos filtros
const filtros = reactive(leerPreferencia('filtros-reportes', vacios))
if (ruta.query.estado || ruta.query.lugar) {
  Object.assign(filtros, { ...vacios, orden: filtros.orden })
  if (ruta.query.estado) filtros.estado = String(ruta.query.estado)
  if (ruta.query.lugar) filtros.lugarId = Number(ruta.query.lugar)
}

const reportes = ref([])
let espera = null

const { cargando, error, cargar } = useCarga(async () => {
  reportes.value = await api.listarReportes({ ...filtros, usuarioId: sesion.usuario.id })
})
cargar()
// Si otro usuario crea o cambia un reporte, la lista se actualiza sola
useTiempoReal(['reportes'], () => cargar({ silencioso: true }))

watch(
  filtros,
  () => {
    guardarPreferencia('filtros-reportes', filtros)
    clearTimeout(espera)
    espera = setTimeout(cargar, 300) // espera a que se termine de escribir
  },
  { deep: true }
)

function limpiar() {
  Object.assign(filtros, { ...vacios })
}
</script>

<template>
  <div class="encabezado-vista">
    <div>
      <h1>Reportes</h1>
      <p class="subtitulo">Desperdicios de agua y energía detectados en la escuela.</p>
    </div>
    <RouterLink v-if="puede('crearReporte')" to="/reportes/nuevo" class="boton verde">
      <IconoSimple nombre="mas" :tam="20" /> Nuevo reporte
    </RouterLink>
  </div>

  <form class="tarjeta filtros" role="search" @submit.prevent>
    <div class="campo buscar">
      <label for="buscar">Buscar</label>
      <input id="buscar" v-model="filtros.texto" type="search" placeholder="Lugar, tipo, descripción o autor" />
    </div>
    <div class="campo">
      <label for="f-estado">Estado</label>
      <select id="f-estado" v-model="filtros.estado">
        <option value="">Todos</option>
        <option value="abiertos">Abiertos (pendiente o en reparación)</option>
        <option v-for="(nombre, clave) in ESTADOS" :key="clave" :value="clave">{{ nombre }}</option>
      </select>
    </div>
    <div class="campo">
      <label for="f-lugar">Lugar</label>
      <select id="f-lugar" v-model="filtros.lugarId">
        <option value="">Todos</option>
        <option v-for="l in sesion.catalogos.lugares" :key="l.id" :value="l.id">{{ l.nombre }}</option>
      </select>
    </div>
    <div class="campo">
      <label for="f-recurso">Recurso</label>
      <select id="f-recurso" v-model="filtros.recurso">
        <option value="">Agua y luz</option>
        <option value="agua">Agua</option>
        <option value="luz">Luz</option>
      </select>
    </div>
    <div class="campo">
      <label for="f-orden">Ordenar por</label>
      <select id="f-orden" v-model="filtros.orden">
        <option v-for="(nombre, clave) in ORDENES" :key="clave" :value="clave">{{ nombre }}</option>
      </select>
    </div>
    <div class="fila pie-filtros">
      <label v-if="puede('crearReporte')" class="casilla">
        <input v-model="filtros.soloMios" type="checkbox" /> Solo mis reportes
      </label>
      <button type="button" class="boton secundario chico" @click="limpiar">Limpiar filtros</button>
    </div>
  </form>

  <EstadoCarga :cargando="cargando" :error="error" texto="Buscando reportes…" @reintentar="cargar" />

  <template v-if="!cargando && !error">
    <p class="texto-gris" aria-live="polite">{{ reportes.length }} {{ reportes.length === 1 ? 'reporte' : 'reportes' }}</p>
    <ul v-if="reportes.length" class="lista grilla-2 grilla">
      <li v-for="r in reportes" :key="r.id"><TarjetaReporte :reporte="r" /></li>
    </ul>
    <p v-else class="vacio tarjeta">No hay reportes con esos filtros.</p>
  </template>
</template>

<style scoped>
.filtros {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 0 1rem;
  margin-bottom: 1rem;
}
.buscar { grid-column: 1 / -1; }
.pie-filtros { grid-column: 1 / -1; justify-content: space-between; }
</style>
