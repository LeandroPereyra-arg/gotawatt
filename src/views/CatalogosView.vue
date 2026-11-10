<script setup>
// Administración de lugares, tipos de desperdicio y medidores (solo administrador).
// Los registros no se borran: se dan de baja y se pueden reactivar.
import { computed, reactive, ref, watch } from 'vue'
import { api } from '../services/api'
import { recargarCatalogos } from '../stores/sesion'
import { avisar, avisarError } from '../stores/avisos'
import { leerPreferencia, guardarPreferencia } from '../stores/preferencias'
import { useCarga } from '../composables/useCarga'
import { useTiempoReal } from '../composables/useTiempoReal'
import { CATALOGOS, RECURSOS, SECTORES } from '../utils/reglas'
import { validarCatalogo, hayErrores } from '../utils/validaciones'
import CampoFormulario from '../components/CampoFormulario.vue'
import EstadoCarga from '../components/EstadoCarga.vue'
import DialogoConfirmar from '../components/DialogoConfirmar.vue'

const pref = leerPreferencia('catalogos', { tabla: 'lugares', verBajas: false })
const tabla = ref(pref.tabla in CATALOGOS ? pref.tabla : 'lugares')
const verBajas = ref(pref.verBajas)
const busqueda = ref('')
const items = ref([])

const { cargando, error, cargar } = useCarga(async () => {
  items.value = await api.listarCatalogo(tabla.value)
})
cargar()
useTiempoReal(['lugares', 'tipos_desperdicio', 'medidores'], () => cargar({ silencioso: true }))

watch([tabla, verBajas], () => guardarPreferencia('catalogos', { tabla: tabla.value, verBajas: verBajas.value }))
watch(tabla, () => {
  cancelarEdicion()
  busqueda.value = ''
  cargar()
})

const info = computed(() => CATALOGOS[tabla.value])
const filtrados = computed(() => {
  const t = busqueda.value.trim().toLowerCase()
  return items.value.filter((x) => (verBajas.value || x.activo) && (!t || x.nombre.toLowerCase().includes(t)))
})
const cantidadBajas = computed(() => items.value.filter((x) => !x.activo).length)

const detalle = (x) => {
  if (tabla.value === 'lugares') return x.sector.charAt(0).toUpperCase() + x.sector.slice(1)
  if (tabla.value === 'medidores') return `${RECURSOS[x.recurso]} · ${x.unidad === 'm3' ? 'm³' : 'kWh'}`
  return RECURSOS[x.recurso]
}

// ----- Formulario (alta y modificación) -----
const vacio = { nombre: '', sector: '', recurso: '' }
const form = reactive({ ...vacio })
const editandoId = ref(null)
const errores = ref({})
const guardando = ref(false)

function editar(x) {
  editandoId.value = x.id
  Object.assign(form, { nombre: x.nombre, sector: x.sector ?? '', recurso: x.recurso ?? '' })
  errores.value = {}
  document.getElementById('cat-nombre')?.focus()
}

function cancelarEdicion() {
  editandoId.value = null
  Object.assign(form, vacio)
  errores.value = {}
}

function datosAGuardar() {
  const nombre = form.nombre.trim()
  if (tabla.value === 'lugares') return { nombre, sector: form.sector }
  if (tabla.value === 'medidores') {
    // El tipo de medidor no se cambia después de creado: sus lecturas dependen de la unidad
    return editandoId.value ? { nombre } : { nombre, recurso: form.recurso, unidad: form.recurso === 'agua' ? 'm3' : 'kWh' }
  }
  return { nombre, recurso: form.recurso }
}

async function guardar() {
  errores.value = validarCatalogo(tabla.value, form, items.value, editandoId.value)
  if (hayErrores(errores.value)) return
  guardando.value = true
  try {
    await api.guardarCatalogo(tabla.value, datosAGuardar(), editandoId.value)
    avisar(editandoId.value ? 'Cambios guardados.' : `Se agregó el ${info.value.singular} «${form.nombre.trim()}».`)
    cancelarEdicion()
    await Promise.all([cargar(), recargarCatalogos()])
  } catch (e) {
    avisarError(e)
  } finally {
    guardando.value = false
  }
}

// ----- Baja y reactivación (con confirmación) -----
const cambiando = ref(null)
const procesando = ref(false)

async function confirmarCambio() {
  const x = cambiando.value
  procesando.value = true
  try {
    await api.cambiarActivoCatalogo(tabla.value, x.id, !x.activo)
    avisar(x.activo ? `«${x.nombre}» quedó dado de baja.` : `«${x.nombre}» se reactivó.`)
    cambiando.value = null
    if (editandoId.value === x.id) cancelarEdicion()
    await Promise.all([cargar(), recargarCatalogos()])
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
      <h1>Catálogos</h1>
      <p class="subtitulo">Lugares de la escuela, tipos de desperdicio y medidores que se usan en los formularios.</p>
    </div>
  </div>

  <div class="pestanas" role="tablist">
    <button
      v-for="(c, clave) in CATALOGOS"
      :key="clave"
      type="button"
      role="tab"
      :aria-selected="tabla === clave"
      :class="{ activa: tabla === clave }"
      @click="tabla = clave"
    >
      {{ c.titulo }}
    </button>
  </div>

  <div class="grilla columnas">
    <section class="tarjeta">
      <form novalidate @submit.prevent="guardar">
        <h2>{{ editandoId ? `Editar ${info.singular}` : `Nuevo ${info.singular}` }}</h2>
        <CampoFormulario etiqueta="Nombre" para="cat-nombre" :error="errores.nombre" obligatorio>
          <input id="cat-nombre" v-model="form.nombre" maxlength="60" :placeholder="tabla === 'lugares' ? 'Ej.: Aula 6' : tabla === 'medidores' ? 'Ej.: Medidor de agua del gimnasio' : 'Ej.: Bebedero que pierde'" />
        </CampoFormulario>

        <CampoFormulario v-if="tabla === 'lugares'" etiqueta="Sector" para="cat-sector" :error="errores.sector" obligatorio>
          <select id="cat-sector" v-model="form.sector">
            <option value="" disabled>Elegí el sector</option>
            <option v-for="s in SECTORES" :key="s" :value="s">{{ s.charAt(0).toUpperCase() + s.slice(1) }}</option>
          </select>
        </CampoFormulario>

        <CampoFormulario
          v-else
          etiqueta="Recurso"
          para="cat-recurso"
          :error="errores.recurso"
          :ayuda="tabla === 'medidores' ? (editandoId ? 'El recurso de un medidor no se cambia porque sus lecturas dependen de la unidad.' : 'Luz se mide en kWh y agua en m³.') : ''"
          obligatorio
        >
          <select id="cat-recurso" v-model="form.recurso" :disabled="tabla === 'medidores' && Boolean(editandoId)">
            <option value="" disabled>Elegí agua o luz</option>
            <option v-for="(nombre, clave) in RECURSOS" :key="clave" :value="clave">{{ nombre }}</option>
          </select>
        </CampoFormulario>

        <div class="fila">
          <button class="boton" type="submit" :disabled="guardando">{{ guardando ? 'Guardando…' : editandoId ? 'Guardar cambios' : 'Agregar' }}</button>
          <button v-if="editandoId" type="button" class="boton secundario" :disabled="guardando" @click="cancelarEdicion">Cancelar</button>
        </div>
      </form>
    </section>

    <section class="tarjeta">
      <div class="fila separado">
        <h2>{{ info.titulo }}</h2>
        <label class="casilla"><input v-model="verBajas" type="checkbox" /> Ver dados de baja ({{ cantidadBajas }})</label>
      </div>
      <div class="campo">
        <label for="cat-buscar">Buscar</label>
        <input id="cat-buscar" v-model="busqueda" type="search" placeholder="Nombre" />
      </div>

      <EstadoCarga :cargando="cargando" :error="error" @reintentar="cargar" />

      <template v-if="!cargando && !error">
        <ul v-if="filtrados.length" class="lista">
          <li v-for="x in filtrados" :key="x.id" class="item" :class="{ baja: !x.activo, editando: editandoId === x.id }">
            <div>
              <strong>{{ x.nombre }}</strong>
              <div class="texto-gris">{{ detalle(x) }}<template v-if="!x.activo"> · Dado de baja</template></div>
            </div>
            <div class="fila">
              <button v-if="x.activo" type="button" class="boton secundario chico" @click="editar(x)">Editar</button>
              <button type="button" class="boton chico" :class="x.activo ? 'peligro' : 'verde'" @click="cambiando = x">
                {{ x.activo ? 'Dar de baja' : 'Reactivar' }}
              </button>
            </div>
          </li>
        </ul>
        <p v-else class="vacio">No hay registros{{ busqueda ? ' con esa búsqueda' : '' }}.</p>
      </template>
    </section>
  </div>

  <DialogoConfirmar
    :abierto="Boolean(cambiando)"
    :titulo="cambiando?.activo ? `Dar de baja «${cambiando?.nombre}»` : `Reactivar «${cambiando?.nombre}»`"
    :mensaje="cambiando?.activo
      ? 'No se borra: deja de aparecer en los formularios, pero los reportes y mediciones anteriores lo siguen mostrando. Se puede reactivar.'
      : 'Vuelve a aparecer en los formularios.'"
    :texto-confirmar="cambiando?.activo ? 'Dar de baja' : 'Reactivar'"
    :peligro="cambiando?.activo"
    :procesando="procesando"
    @confirmar="confirmarCambio"
    @cancelar="cambiando = null"
  />
</template>

<style scoped>
.columnas > section { min-width: 0; }
.lista { gap: 0; }
.item { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 0.5rem; padding: 0.6rem 0; border-bottom: 1px solid var(--borde); }
.item:last-child { border-bottom: none; }
.item.baja strong { color: var(--gris); text-decoration: line-through; }
.item.editando { background: var(--azul-claro); border-radius: 8px; padding-inline: 0.5rem; }
@media (min-width: 860px) {
  .columnas { grid-template-columns: 340px 1fr; align-items: start; }
}
</style>
