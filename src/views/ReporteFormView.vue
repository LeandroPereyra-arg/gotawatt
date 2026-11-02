<script setup>
import { computed, onMounted, onBeforeUnmount, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { api } from '../services/api'
import { sesion } from '../stores/sesion'
import { avisar } from '../stores/avisos'
import { puedeEditarReporte } from '../utils/reglas'
import { validarReporte, hayErrores } from '../utils/validaciones'
import CampoFormulario from '../components/CampoFormulario.vue'
import EstadoCarga from '../components/EstadoCarga.vue'
import IconoSimple from '../components/IconoSimple.vue'

// Si llega un "id" se edita un reporte existente; si no, se crea uno nuevo
const props = defineProps({ id: { type: String, default: null } })
const router = useRouter()
const editando = computed(() => Boolean(props.id))

const form = reactive({ lugarId: '', tipoId: '', descripcion: '', foto: null })
const errores = ref({})
const errorGeneral = ref('')
const procesando = ref(false)
const cargando = ref(false)
const errorCarga = ref('')
const vistaPrevia = ref(null)
const fotoActual = ref(null)

const tiposAgua = computed(() => sesion.catalogos.tipos.filter((t) => t.recurso === 'agua'))
const tiposLuz = computed(() => sesion.catalogos.tipos.filter((t) => t.recurso === 'luz'))

async function cargar() {
  if (!editando.value) return
  cargando.value = true
  errorCarga.value = ''
  try {
    const r = await api.obtenerReporte(props.id)
    if (!r) throw new Error('El reporte no existe.')
    if (!puedeEditarReporte(sesion.perfil, r)) {
      avisar('No podés editar este reporte.', 'error')
      return router.replace(`/reportes/${props.id}`)
    }
    Object.assign(form, { lugarId: r.lugar_id, tipoId: r.tipo_id, descripcion: r.descripcion ?? '' })
    fotoActual.value = await api.urlFoto(r.foto_path)
  } catch (e) {
    errorCarga.value = e.message
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)

function elegirFoto(evento) {
  const archivo = evento.target.files[0] ?? null
  form.foto = archivo
  if (vistaPrevia.value) URL.revokeObjectURL(vistaPrevia.value)
  vistaPrevia.value = archivo ? URL.createObjectURL(archivo) : null
  errores.value = { ...errores.value, foto: validarReporte(form).foto }
  if (!errores.value.foto) delete errores.value.foto
}
function quitarFoto() {
  form.foto = null
  if (vistaPrevia.value) URL.revokeObjectURL(vistaPrevia.value)
  vistaPrevia.value = null
}
onBeforeUnmount(() => vistaPrevia.value && URL.revokeObjectURL(vistaPrevia.value))

async function enviar() {
  errorGeneral.value = ''
  errores.value = validarReporte(form)
  if (hayErrores(errores.value)) return
  procesando.value = true
  try {
    if (editando.value) {
      await api.editarReporte(props.id, form, sesion.usuario.id)
      avisar('Cambios guardados.')
      router.push(`/reportes/${props.id}`)
    } else {
      const nuevo = await api.crearReporte(form, sesion.usuario.id)
      avisar('¡Reporte enviado! Quedó como pendiente.')
      router.push(`/reportes/${nuevo.id}`)
    }
  } catch (e) {
    errorGeneral.value = e.message
  } finally {
    procesando.value = false
  }
}
</script>

<template>
  <div class="formulario-reporte">
    <RouterLink :to="editando ? `/reportes/${id}` : '/reportes'" class="volver">
      <IconoSimple nombre="atras" :tam="18" /> Volver
    </RouterLink>
    <h1>{{ editando ? 'Editar reporte' : 'Nuevo reporte' }}</h1>
    <p class="subtitulo">Los campos con <span class="texto-rojo">*</span> son obligatorios.</p>

    <EstadoCarga :cargando="cargando" :error="errorCarga" @reintentar="cargar" />

    <form v-if="!cargando && !errorCarga" class="tarjeta mt" novalidate @submit.prevent="enviar">
      <CampoFormulario etiqueta="Lugar" para="lugar" :error="errores.lugarId" obligatorio>
        <select id="lugar" v-model="form.lugarId">
          <option value="" disabled>Elegí dónde está el desperdicio</option>
          <option v-for="l in sesion.catalogos.lugares" :key="l.id" :value="l.id">{{ l.nombre }}</option>
        </select>
      </CampoFormulario>

      <CampoFormulario etiqueta="Tipo de desperdicio" para="tipo" :error="errores.tipoId" obligatorio>
        <select id="tipo" v-model="form.tipoId">
          <option value="" disabled>Elegí qué pasa</option>
          <optgroup label="Agua">
            <option v-for="t in tiposAgua" :key="t.id" :value="t.id">{{ t.nombre }}</option>
          </optgroup>
          <optgroup label="Luz">
            <option v-for="t in tiposLuz" :key="t.id" :value="t.id">{{ t.nombre }}</option>
          </optgroup>
        </select>
      </CampoFormulario>

      <CampoFormulario etiqueta="Foto" para="foto" :error="errores.foto" ayuda="Opcional. JPG, PNG o WEBP. Que no se vean personas.">
        <label class="zona-foto" for="foto">
          <img v-if="vistaPrevia || fotoActual" :src="vistaPrevia || fotoActual" alt="Vista previa de la foto" />
          <span v-else><IconoSimple nombre="foto" :tam="28" /><br />Tocá para sacar o elegir una foto</span>
        </label>
        <input id="foto" class="oculto" type="file" accept="image/jpeg,image/png,image/webp" capture="environment" @change="elegirFoto" />
        <button v-if="form.foto" type="button" class="boton secundario chico quitar" @click="quitarFoto">Quitar foto nueva</button>
      </CampoFormulario>

      <CampoFormulario etiqueta="Descripción" para="descripcion" :error="errores.descripcion" :ayuda="`${form.descripcion.length}/300 caracteres`">
        <textarea id="descripcion" v-model="form.descripcion" maxlength="300" placeholder="Ej.: Gotea fuerte la canilla de la izquierda"></textarea>
      </CampoFormulario>

      <p v-if="!editando" class="texto-gris">La fecha, la hora y tu nombre se guardan automáticamente.</p>
      <p v-if="errorGeneral" class="texto-rojo" role="alert">{{ errorGeneral }}</p>

      <button class="boton verde ancho" type="submit" :disabled="procesando">
        {{ procesando ? 'Guardando…' : editando ? 'Guardar cambios' : 'Enviar reporte' }}
      </button>
    </form>
  </div>
</template>

<style scoped>
.formulario-reporte { max-width: 560px; margin: 0 auto; }
.volver { display: inline-flex; align-items: center; gap: 0.2rem; margin-bottom: 0.5rem; font-weight: 600; text-decoration: none; }
.zona-foto {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 140px;
  border: 2px dashed var(--borde);
  border-radius: 10px;
  background: var(--gris-claro);
  color: var(--gris);
  text-align: center;
  cursor: pointer;
  overflow: hidden;
  font-weight: 600;
}
.zona-foto:hover { border-color: var(--azul); }
.zona-foto img { max-width: 100%; max-height: 260px; display: block; }
.oculto { position: absolute; width: 1px; height: 1px; opacity: 0; }
.quitar { align-self: flex-start; }
</style>
