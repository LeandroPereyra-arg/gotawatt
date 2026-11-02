<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { api } from '../services/api'
import { sesion, puede } from '../stores/sesion'
import { avisar, avisarError } from '../stores/avisos'
import { ESTADOS, estadosSiguientes, puedeEditarReporte } from '../utils/reglas'
import { formatoFechaHora } from '../utils/formato'
import ChipEstado from '../components/ChipEstado.vue'
import EstadoCarga from '../components/EstadoCarga.vue'
import DialogoConfirmar from '../components/DialogoConfirmar.vue'
import IconoSimple from '../components/IconoSimple.vue'

const props = defineProps({ id: { type: String, required: true } })
const router = useRouter()

const reporte = ref(null)
const foto = ref(null)
const cargando = ref(true)
const error = ref('')
const dialogo = ref(null) // { estado } o { eliminar: true }
const procesando = ref(false)

async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    reporte.value = await api.obtenerReporte(props.id)
    if (!reporte.value) throw new Error('El reporte no existe o no tenés permiso para verlo.')
    foto.value = await api.urlFoto(reporte.value.foto_path)
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)

const siguientes = computed(() => estadosSiguientes(sesion.perfil, reporte.value))
const editable = computed(() => puedeEditarReporte(sesion.perfil, reporte.value))
const eliminable = computed(() => puede('eliminarPrueba') && reporte.value?.es_prueba)

const textoBoton = {
  en_reparacion: 'Marcar en reparación',
  resuelto: 'Marcar resuelto',
  pendiente: 'Volver a pendiente',
  anulado: 'Anular reporte'
}

const tituloDialogo = computed(() => {
  if (!dialogo.value) return ''
  if (dialogo.value.eliminar) return 'Eliminar reporte de prueba'
  return dialogo.value.estado === 'anulado' ? 'Anular reporte' : `Cambiar a «${ESTADOS[dialogo.value.estado]}»`
})
const mensajeDialogo = computed(() => {
  if (!dialogo.value) return ''
  if (dialogo.value.eliminar) return 'Se borra definitivamente. Solo se permite con datos de prueba.'
  if (dialogo.value.estado === 'anulado') return 'El reporte no se borra: queda en el historial como anulado.'
  return `El reporte pasará de «${ESTADOS[reporte.value.estado]}» a «${ESTADOS[dialogo.value.estado]}».`
})

async function confirmar(motivo) {
  procesando.value = true
  try {
    if (dialogo.value.eliminar) {
      await api.eliminarReporte(reporte.value.id)
      avisar('Reporte de prueba eliminado.')
      dialogo.value = null
      return router.push('/reportes')
    }
    const nuevo = dialogo.value.estado
    await api.cambiarEstado(reporte.value.id, nuevo, motivo)
    avisar(`Estado actualizado: ${ESTADOS[nuevo]}.`)
    dialogo.value = null
    await cargar()
  } catch (e) {
    avisarError(e)
  } finally {
    procesando.value = false
  }
}
</script>

<template>
  <div class="detalle">
    <RouterLink to="/reportes" class="volver"><IconoSimple nombre="atras" :tam="18" /> Reportes</RouterLink>
    <EstadoCarga :cargando="cargando" :error="error" texto="Cargando reporte…" @reintentar="cargar" />

    <template v-if="reporte && !cargando">
      <div class="encabezado-vista">
        <div>
          <h1>{{ reporte.lugar }}</h1>
          <p class="subtitulo">{{ reporte.tipo }} · Reporte n.º {{ reporte.id }}</p>
        </div>
        <div class="fila">
          <ChipEstado :estado="reporte.estado" />
          <span v-if="reporte.es_prueba" class="chip prueba">Dato de prueba</span>
        </div>
      </div>

      <div class="grilla grilla-2">
        <section class="tarjeta">
          <img v-if="foto" :src="foto" alt="Foto del desperdicio reportado" class="foto" />
          <p v-else class="sin-foto">Sin foto</p>
          <dl class="datos">
            <dt>Descripción</dt><dd>{{ reporte.descripcion || 'Sin descripción' }}</dd>
            <dt>Recurso</dt><dd><span class="chip" :class="reporte.recurso">{{ reporte.recurso === 'agua' ? 'Agua' : 'Luz' }}</span></dd>
            <dt>Reportado por</dt><dd>{{ reporte.autor }}</dd>
            <dt>Fecha</dt><dd>{{ formatoFechaHora(reporte.creado_en) }}</dd>
            <template v-if="reporte.estado === 'anulado'">
              <dt>Motivo de anulación</dt><dd>{{ reporte.motivo_anulacion }}</dd>
            </template>
          </dl>
        </section>

        <section class="tarjeta">
          <h2>Acciones</h2>
          <div v-if="siguientes.length || editable || eliminable" class="acciones">
            <button
              v-for="e in siguientes.filter((x) => x !== 'anulado')"
              :key="e"
              type="button"
              class="boton"
              :class="{ verde: e === 'resuelto' }"
              @click="dialogo = { estado: e }"
            >
              {{ textoBoton[e] }}
            </button>
            <RouterLink v-if="editable" :to="`/reportes/${reporte.id}/editar`" class="boton secundario">Editar datos</RouterLink>
            <button v-if="siguientes.includes('anulado')" type="button" class="boton peligro" @click="dialogo = { estado: 'anulado' }">
              Anular reporte
            </button>
            <button v-if="eliminable" type="button" class="boton peligro" @click="dialogo = { eliminar: true }">
              Eliminar (dato de prueba)
            </button>
          </div>
          <p v-else class="texto-gris">Tu rol no tiene acciones disponibles para este reporte.</p>

          <h2 class="mt">Historial</h2>
          <ol class="historial">
            <li v-for="(h, i) in reporte.historial" :key="i">
              <ChipEstado :estado="h.estado_nuevo" />
              <div>
                <div>{{ h.estado_anterior ? `${ESTADOS[h.estado_anterior]} → ${ESTADOS[h.estado_nuevo]}` : 'Reporte creado' }}</div>
                <div class="texto-gris">{{ formatoFechaHora(h.fecha) }} · {{ h.usuario }}</div>
                <div v-if="h.comentario && h.estado_anterior" class="texto-gris">«{{ h.comentario }}»</div>
              </div>
            </li>
          </ol>
        </section>
      </div>
    </template>

    <DialogoConfirmar
      :abierto="Boolean(dialogo)"
      :titulo="tituloDialogo"
      :mensaje="mensajeDialogo"
      :pedir-motivo="dialogo?.estado === 'anulado'"
      :peligro="dialogo?.estado === 'anulado' || dialogo?.eliminar"
      :texto-confirmar="dialogo?.eliminar ? 'Eliminar' : 'Confirmar'"
      :procesando="procesando"
      @confirmar="confirmar"
      @cancelar="dialogo = null"
    />
  </div>
</template>

<style scoped>
.volver { display: inline-flex; align-items: center; gap: 0.2rem; margin-bottom: 0.5rem; font-weight: 600; text-decoration: none; }
.foto { width: 100%; max-height: 320px; object-fit: cover; border-radius: 8px; }
.sin-foto { background: var(--gris-claro); color: var(--gris); text-align: center; padding: 2rem; border-radius: 8px; }
.datos { display: grid; grid-template-columns: auto 1fr; gap: 0.4rem 1rem; margin: 1rem 0 0; }
.datos dt { color: var(--gris); font-size: 0.9rem; }
.datos dd { margin: 0; }
.acciones { display: grid; gap: 0.5rem; }
.historial { list-style: none; padding: 0; margin: 0; display: grid; gap: 0.75rem; }
.historial li { display: grid; grid-template-columns: 110px 1fr; gap: 0.5rem; align-items: start; }
</style>
