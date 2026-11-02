<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { api } from '../services/api'
import { sesion, puede } from '../stores/sesion'
import { avisar, avisarError } from '../stores/avisos'
import { leerPreferencia, guardarPreferencia } from '../stores/preferencias'
import { validarLectura, validarGoteo, convertirNumero, hayErrores } from '../utils/validaciones'
import { formatoFechaHora, formatoNumero } from '../utils/formato'
import CampoFormulario from '../components/CampoFormulario.vue'
import EstadoCarga from '../components/EstadoCarga.vue'
import DialogoConfirmar from '../components/DialogoConfirmar.vue'

const pref = leerPreferencia('mediciones', { pestana: 'medidores', verAnuladas: false })
const pestana = ref(pref.pestana)
const verAnuladas = ref(pref.verAnuladas)
watch([pestana, verAnuladas], () => {
  guardarPreferencia('mediciones', { pestana: pestana.value, verAnuladas: verAnuladas.value })
  cargar()
})

const lecturas = ref([])
const goteos = ref([])
const cargando = ref(true)
const error = ref('')

async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    if (pestana.value === 'medidores') lecturas.value = await api.listarLecturas({ verAnuladas: verAnuladas.value })
    else goteos.value = await api.listarGoteos({ verAnuladas: verAnuladas.value })
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)

const medidores = computed(() => sesion.catalogos.medidores)
const nombreMedidor = (id) => medidores.value.find((m) => m.id === id)?.nombre ?? ''
const unidad = (id) => (medidores.value.find((m) => m.id === id)?.unidad === 'm3' ? 'm³' : 'kWh')

// Consumo de cada lectura respecto de la anterior válida del mismo medidor
const lecturasConConsumo = computed(() =>
  lecturas.value.map((l) => {
    const anterior = lecturas.value
      .filter((x) => x.medidor_id === l.medidor_id && !x.anulada && new Date(x.fecha_lectura) < new Date(l.fecha_lectura))
      .sort((a, b) => new Date(b.fecha_lectura) - new Date(a.fecha_lectura))[0]
    return { ...l, consumo: anterior && !l.anulada ? Number(l.valor) - Number(anterior.valor) : null }
  })
)

// ----- Formulario de lectura -----
const formLectura = reactive({ medidorId: '', valor: '' })
const erroresLectura = ref({})
const guardandoLectura = ref(false)

function ultimaLectura(medidorId) {
  const l = lecturas.value.filter((x) => x.medidor_id === Number(medidorId) && !x.anulada)
  return l.length ? Math.max(...l.map((x) => Number(x.valor))) : null
}

async function guardarLectura() {
  erroresLectura.value = validarLectura(formLectura, formLectura.medidorId ? ultimaLectura(formLectura.medidorId) : null)
  if (hayErrores(erroresLectura.value)) return
  guardandoLectura.value = true
  try {
    await api.crearLectura({ medidorId: formLectura.medidorId, valor: convertirNumero(formLectura.valor) }, sesion.usuario.id)
    avisar('Lectura guardada.')
    formLectura.valor = ''
    await cargar()
  } catch (e) {
    avisarError(e)
  } finally {
    guardandoLectura.value = false
  }
}

// ----- Formulario de goteo -----
const formGoteo = reactive({ lugarId: '', canilla: '', ml: '' })
const erroresGoteo = ref({})
const guardandoGoteo = ref(false)
const litrosPorDia = computed(() => {
  const ml = convertirNumero(formGoteo.ml)
  return Number.isNaN(ml) || ml <= 0 ? null : (ml * 144) / 1000 // 144 períodos de 10 minutos por día
})

async function guardarGoteo() {
  erroresGoteo.value = validarGoteo(formGoteo)
  if (hayErrores(erroresGoteo.value)) return
  guardandoGoteo.value = true
  try {
    await api.crearGoteo({ ...formGoteo, ml: convertirNumero(formGoteo.ml) }, sesion.usuario.id)
    avisar('Medición de goteo guardada.')
    Object.assign(formGoteo, { canilla: '', ml: '' })
    await cargar()
  } catch (e) {
    avisarError(e)
  } finally {
    guardandoGoteo.value = false
  }
}

// ----- Anular (solo administrador) -----
const anulando = ref(null)
const procesando = ref(false)
async function confirmarAnulacion(motivo) {
  procesando.value = true
  try {
    if (pestana.value === 'medidores') await api.anularLectura(anulando.value.id, motivo)
    else await api.anularGoteo(anulando.value.id, motivo)
    avisar('Registro anulado. Queda guardado en el historial.')
    anulando.value = null
    await cargar()
  } catch (e) {
    avisarError(e)
  } finally {
    procesando.value = false
  }
}
</script>

<template>
  <div class="encabezado-vista">
    <div>
      <h1>Mediciones</h1>
      <p class="subtitulo">Lecturas de los medidores y del agua perdida por goteo.</p>
    </div>
  </div>

  <div class="pestanas" role="tablist">
    <button type="button" role="tab" :aria-selected="pestana === 'medidores'" :class="{ activa: pestana === 'medidores' }" @click="pestana = 'medidores'">
      Medidores de agua y luz
    </button>
    <button type="button" role="tab" :aria-selected="pestana === 'goteo'" :class="{ activa: pestana === 'goteo' }" @click="pestana = 'goteo'">
      Goteo de canillas
    </button>
  </div>

  <div class="grilla columnas">
    <!-- Formularios: solo administrador y socios -->
    <section v-if="puede('cargarMedicion')" class="tarjeta">
      <form v-if="pestana === 'medidores'" novalidate @submit.prevent="guardarLectura">
        <h2>Cargar lectura</h2>
        <CampoFormulario etiqueta="Medidor" para="medidor" :error="erroresLectura.medidorId" obligatorio>
          <select id="medidor" v-model="formLectura.medidorId">
            <option value="" disabled>Elegí el medidor</option>
            <option v-for="m in medidores" :key="m.id" :value="m.id">{{ m.nombre }}</option>
          </select>
        </CampoFormulario>
        <CampoFormulario
          etiqueta="Lectura actual"
          para="valor"
          :error="erroresLectura.valor"
          :ayuda="formLectura.medidorId ? `En ${unidad(formLectura.medidorId)}. Última: ${formatoNumero(ultimaLectura(formLectura.medidorId), 2)}` : 'El número que marca el medidor.'"
          obligatorio
        >
          <input id="valor" v-model="formLectura.valor" inputmode="decimal" placeholder="Ej.: 18452" />
        </CampoFormulario>
        <p class="texto-gris">Se recomienda leerlo todos los lunes a la misma hora. La fecha se guarda sola.</p>
        <button class="boton ancho" type="submit" :disabled="guardandoLectura || cargando">{{ guardandoLectura ? 'Guardando…' : 'Guardar lectura' }}</button>
      </form>

      <form v-else novalidate @submit.prevent="guardarGoteo">
        <h2>Medir goteo</h2>
        <p class="texto-gris">Poné un recipiente graduado debajo de la canilla durante 10 minutos.</p>
        <CampoFormulario etiqueta="Lugar" para="g-lugar" :error="erroresGoteo.lugarId" obligatorio>
          <select id="g-lugar" v-model="formGoteo.lugarId">
            <option value="" disabled>Elegí el lugar</option>
            <option v-for="l in sesion.catalogos.lugares" :key="l.id" :value="l.id">{{ l.nombre }}</option>
          </select>
        </CampoFormulario>
        <CampoFormulario etiqueta="Canilla" para="canilla" :error="erroresGoteo.canilla" obligatorio>
          <input id="canilla" v-model="formGoteo.canilla" maxlength="40" placeholder="Ej.: Izquierda" />
        </CampoFormulario>
        <CampoFormulario etiqueta="Mililitros en 10 minutos" para="ml" :error="erroresGoteo.ml" obligatorio>
          <input id="ml" v-model="formGoteo.ml" inputmode="decimal" placeholder="Ej.: 9,5" />
        </CampoFormulario>
        <p v-if="litrosPorDia !== null" class="calculo">≈ {{ formatoNumero(litrosPorDia, 2) }} litros perdidos por día</p>
        <button class="boton ancho" type="submit" :disabled="guardandoGoteo || cargando">{{ guardandoGoteo ? 'Guardando…' : 'Guardar medición' }}</button>
      </form>
    </section>

    <!-- Listados -->
    <section class="tarjeta">
      <div class="fila separado">
        <h2>{{ pestana === 'medidores' ? 'Lecturas' : 'Mediciones de goteo' }}</h2>
        <label class="casilla"><input v-model="verAnuladas" type="checkbox" /> Ver anuladas</label>
      </div>
      <EstadoCarga :cargando="cargando" :error="error" @reintentar="cargar" />

      <div v-if="!cargando && !error" class="tabla-contenedor">
        <table v-if="pestana === 'medidores' && lecturasConConsumo.length">
          <thead><tr><th>Fecha</th><th>Medidor</th><th>Lectura</th><th>Consumo</th><th></th></tr></thead>
          <tbody>
            <tr v-for="l in lecturasConConsumo" :key="l.id" :class="{ anulada: l.anulada }">
              <td>{{ formatoFechaHora(l.fecha_lectura) }}<br /><span class="texto-gris">{{ l.cargador }}</span></td>
              <td>{{ nombreMedidor(l.medidor_id) }}</td>
              <td>{{ formatoNumero(l.valor, 1) }} {{ unidad(l.medidor_id) }}</td>
              <td>{{ l.consumo !== null ? `${formatoNumero(l.consumo, 1)} ${unidad(l.medidor_id)}` : '–' }}</td>
              <td>
                <span v-if="l.es_prueba" class="chip prueba">Prueba</span>
                <span v-if="l.anulada" class="texto-gris" :title="l.motivo_anulacion">Anulada</span>
                <button v-else-if="puede('corregirMedicion')" type="button" class="boton peligro chico" @click="anulando = l">Anular</button>
              </td>
            </tr>
          </tbody>
        </table>
        <table v-else-if="pestana === 'goteo' && goteos.length">
          <thead><tr><th>Fecha</th><th>Lugar</th><th>ml/10 min</th><th>Litros por día</th><th></th></tr></thead>
          <tbody>
            <tr v-for="g in goteos" :key="g.id" :class="{ anulada: g.anulada }">
              <td>{{ formatoFechaHora(g.fecha) }}<br /><span class="texto-gris">{{ g.cargador }}</span></td>
              <td>{{ g.lugar }}<br /><span class="texto-gris">{{ g.canilla }}</span></td>
              <td>{{ formatoNumero(g.ml_10min, 1) }}</td>
              <td>{{ formatoNumero(g.litros_dia, 2) }} L</td>
              <td>
                <span v-if="g.es_prueba" class="chip prueba">Prueba</span>
                <span v-if="g.anulada" class="texto-gris" :title="g.motivo_anulacion">Anulada</span>
                <button v-else-if="puede('corregirMedicion')" type="button" class="boton peligro chico" @click="anulando = g">Anular</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-else class="vacio">Todavía no hay mediciones cargadas.</p>
      </div>
    </section>
  </div>

  <DialogoConfirmar
    :abierto="Boolean(anulando)"
    titulo="Anular medición"
    mensaje="La medición no se borra: queda marcada como anulada y deja de contar en las estadísticas."
    texto-confirmar="Anular"
    pedir-motivo
    peligro
    :procesando="procesando"
    @confirmar="confirmarAnulacion"
    @cancelar="anulando = null"
  />
</template>

<style scoped>
.pestanas { display: flex; gap: 0.25rem; margin-bottom: 1rem; border-bottom: 2px solid var(--borde); overflow-x: auto; }
.pestanas button {
  font: inherit;
  font-weight: 600;
  background: none;
  border: none;
  padding: 0.7rem 1rem;
  min-height: 44px;
  color: var(--gris);
  cursor: pointer;
  border-bottom: 3px solid transparent;
  margin-bottom: -2px;
  white-space: nowrap;
}
.pestanas button.activa { color: var(--azul); border-bottom-color: var(--azul); }
.columnas > section { min-width: 0; }
.calculo { background: var(--azul-claro); color: var(--azul-oscuro); font-weight: 700; padding: 0.5rem 0.75rem; border-radius: 8px; }
@media (min-width: 860px) {
  .columnas { grid-template-columns: 340px 1fr; align-items: start; }
  .columnas > section:only-child { grid-column: 1 / -1; }
}
</style>
