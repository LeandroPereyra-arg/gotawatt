<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { sesion } from './stores/sesion'
import BarraNavegacion from './components/BarraNavegacion.vue'
import AvisoDatosPrueba from './components/AvisoDatosPrueba.vue'
import AvisosFlotantes from './components/AvisosFlotantes.vue'

const ruta = useRoute()
const conMenu = computed(() => sesion.perfil?.activo && !ruta.meta.publica)
// Una vista privada solo se muestra si hay sesión (evita errores al cerrar sesión)
const mostrarVista = computed(() => ruta.meta.publica || Boolean(sesion.perfil))
</script>

<template>
  <BarraNavegacion v-if="conMenu" />
  <AvisoDatosPrueba v-if="conMenu" />
  <main class="contenido">
    <!-- La clave hace que la pantalla se vuelva a crear al pasar, por ejemplo, de un reporte a otro -->
    <RouterView v-if="mostrarVista" :key="ruta.path" />
  </main>
  <AvisosFlotantes />
</template>
