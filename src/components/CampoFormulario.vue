<script setup>
// Etiqueta + control + mensaje de error o ayuda
defineProps({
  etiqueta: { type: String, required: true },
  para: { type: String, required: true },
  error: { type: String, default: '' },
  ayuda: { type: String, default: '' },
  obligatorio: Boolean
})
</script>

<template>
  <div class="campo" :class="{ 'con-error': error }">
    <label :for="para">
      {{ etiqueta }} <span v-if="obligatorio" class="obligatorio" aria-label="obligatorio">*</span>
    </label>
    <slot />
    <span v-if="error" :id="`${para}-error`" class="error">{{ error }}</span>
    <span v-else-if="ayuda" class="ayuda">{{ ayuda }}</span>
  </div>
</template>
