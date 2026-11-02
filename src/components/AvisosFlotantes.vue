<script setup>
import { avisos, cerrarAviso } from '../stores/avisos'
</script>

<template>
  <div class="avisos" aria-live="polite">
    <div v-for="a in avisos.lista" :key="a.id" class="aviso" :class="a.tipo" :role="a.tipo === 'error' ? 'alert' : 'status'">
      <span>{{ a.texto }}</span>
      <button type="button" aria-label="Cerrar aviso" @click="cerrarAviso(a.id)">×</button>
    </div>
  </div>
</template>

<style scoped>
.avisos {
  position: fixed;
  left: 50%;
  transform: translateX(-50%);
  bottom: 76px;
  z-index: 50;
  display: grid;
  gap: 0.5rem;
  width: min(92vw, 460px);
}
.aviso {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  border-radius: 10px;
  color: #fff;
  font-weight: 600;
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.2);
}
.aviso.exito { background: var(--verde); }
.aviso.error { background: var(--rojo); }
.aviso button {
  background: none;
  border: none;
  color: #fff;
  font-size: 1.4rem;
  line-height: 1;
  cursor: pointer;
  min-width: 32px;
  min-height: 32px;
}
@media (min-width: 760px) {
  .avisos { bottom: 24px; }
}
</style>
