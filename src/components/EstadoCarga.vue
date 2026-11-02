<script setup>
// Muestra "Cargando…" o el error de una operación, con opción de reintentar
defineProps({
  cargando: Boolean,
  error: { type: String, default: '' },
  texto: { type: String, default: 'Cargando…' }
})
defineEmits(['reintentar'])
</script>

<template>
  <div v-if="cargando" class="estado" role="status">
    <span class="ruedita" aria-hidden="true"></span>
    <span>{{ texto }}</span>
  </div>
  <div v-else-if="error" class="estado error" role="alert">
    <p>{{ error }}</p>
    <button type="button" class="boton secundario chico" @click="$emit('reintentar')">Reintentar</button>
  </div>
</template>

<style scoped>
.estado {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.6rem;
  padding: 2rem 1rem;
  color: var(--gris);
  text-align: center;
}
.estado.error { color: var(--rojo); font-weight: 600; }
.ruedita {
  width: 28px;
  height: 28px;
  border: 3px solid var(--azul-claro);
  border-top-color: var(--azul);
  border-radius: 50%;
  animation: girar 0.8s linear infinite;
}
@keyframes girar { to { transform: rotate(360deg); } }
@media (prefers-reduced-motion: reduce) { .ruedita { animation-duration: 2.5s; } }
</style>
