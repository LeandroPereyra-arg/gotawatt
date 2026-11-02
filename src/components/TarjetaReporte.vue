<script setup>
import ChipEstado from './ChipEstado.vue'
import { haceCuanto } from '../utils/formato'

defineProps({ reporte: { type: Object, required: true } })
</script>

<template>
  <RouterLink :to="`/reportes/${reporte.id}`" class="tarjeta-reporte">
    <div class="fila separado">
      <strong>{{ reporte.lugar }}</strong>
      <span class="texto-gris">{{ haceCuanto(reporte.creado_en) }}</span>
    </div>
    <div class="texto-gris">{{ reporte.tipo }}</div>
    <div class="fila">
      <ChipEstado :estado="reporte.estado" />
      <span class="chip" :class="reporte.recurso">{{ reporte.recurso === 'agua' ? 'Agua' : 'Luz' }}</span>
      <span v-if="reporte.es_prueba" class="chip prueba" title="Dato de prueba">Prueba</span>
    </div>
  </RouterLink>
</template>

<style scoped>
.tarjeta-reporte {
  display: grid;
  gap: 0.3rem;
  background: #fff;
  border: 1px solid var(--borde);
  border-radius: var(--radio);
  padding: 0.8rem 1rem;
  color: inherit;
  text-decoration: none;
  box-shadow: var(--sombra);
}
.tarjeta-reporte:hover { border-color: var(--azul); }
</style>
