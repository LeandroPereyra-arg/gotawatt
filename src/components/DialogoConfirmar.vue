<script setup>
// Ventana para confirmar una acción. Si "pedirMotivo" es true, exige escribir un motivo.
import { ref, watch, nextTick } from 'vue'
import { validarMotivo } from '../utils/validaciones'

const props = defineProps({
  abierto: Boolean,
  titulo: { type: String, required: true },
  mensaje: { type: String, default: '' },
  textoConfirmar: { type: String, default: 'Confirmar' },
  peligro: Boolean,
  pedirMotivo: Boolean,
  procesando: Boolean
})
const emit = defineEmits(['confirmar', 'cancelar'])

const motivo = ref('')
const error = ref('')
const caja = ref(null)

watch(
  () => props.abierto,
  async (abierto) => {
    if (abierto) {
      motivo.value = ''
      error.value = ''
      await nextTick()
      caja.value?.querySelector('textarea, button')?.focus()
    }
  }
)

function confirmar() {
  if (props.pedirMotivo) {
    error.value = validarMotivo(motivo.value)
    if (error.value) return
  }
  emit('confirmar', motivo.value.trim())
}
</script>

<template>
  <div v-if="abierto" class="fondo" @click.self="!procesando && emit('cancelar')" @keydown.esc="!procesando && emit('cancelar')">
    <div ref="caja" class="dialogo" role="dialog" aria-modal="true" :aria-label="titulo">
      <h2>{{ titulo }}</h2>
      <p v-if="mensaje">{{ mensaje }}</p>
      <div v-if="pedirMotivo" class="campo" :class="{ 'con-error': error }">
        <label for="motivo">Motivo <span class="obligatorio">*</span></label>
        <textarea id="motivo" v-model="motivo" maxlength="200" placeholder="Ej.: Reporte duplicado"></textarea>
        <span v-if="error" class="error">{{ error }}</span>
      </div>
      <div class="fila acciones">
        <button type="button" class="boton secundario" :disabled="procesando" @click="emit('cancelar')">Cancelar</button>
        <button type="button" class="boton" :class="{ peligro }" :disabled="procesando" @click="confirmar">
          {{ procesando ? 'Guardando…' : textoConfirmar }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.fondo {
  position: fixed;
  inset: 0;
  z-index: 40;
  background: rgba(20, 24, 30, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
}
.dialogo {
  background: #fff;
  border-radius: 12px;
  padding: 1.25rem;
  width: min(100%, 440px);
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.25);
}
.acciones { justify-content: flex-end; margin-top: 0.5rem; }
</style>
