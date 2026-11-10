<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { sesion, puede, salir } from '../stores/sesion'
import { avisarError } from '../stores/avisos'
import { ROLES } from '../utils/reglas'
import IconoSimple from './IconoSimple.vue'
import logo from '../assets/logo.svg'

const router = useRouter()

// Cada rol ve solo las secciones que le corresponden
const enlaces = computed(() =>
  [
    { a: '/', texto: 'Inicio', icono: 'inicio' },
    { a: '/reportes', texto: 'Reportes', icono: 'reportes' },
    { a: '/mediciones', texto: 'Mediciones', icono: 'medir' },
    { a: '/estadisticas', texto: 'Estadísticas', icono: 'datos' },
    { a: '/catalogos', texto: 'Catálogos', icono: 'catalogo', permiso: 'gestionarCatalogos' },
    { a: '/usuarios', texto: 'Usuarios', icono: 'usuarios', permiso: 'gestionarUsuarios' }
  ].filter((e) => !e.permiso || puede(e.permiso))
)

async function cerrar() {
  try {
    await salir()
    router.push('/ingresar')
  } catch (e) {
    avisarError(e)
  }
}
</script>

<template>
  <header class="barra">
    <div class="barra-interior">
      <RouterLink to="/" class="marca" aria-label="GotaWatt, ir al inicio">
        <img :src="logo" alt="" width="32" height="32" />
        <span>GotaWatt</span>
      </RouterLink>

      <nav class="enlaces-escritorio" aria-label="Secciones">
        <RouterLink v-for="e in enlaces" :key="e.a" :to="e.a" class="enlace">{{ e.texto }}</RouterLink>
      </nav>

      <div class="usuario">
        <div class="usuario-datos">
          <strong>{{ sesion.perfil.nombre }}</strong>
          <span>{{ ROLES[sesion.perfil.rol] }}</span>
        </div>
        <button class="boton secundario chico" type="button" @click="cerrar" title="Cerrar sesión">
          <IconoSimple nombre="salir" :tam="18" />
          <span class="solo-escritorio">Salir</span>
        </button>
      </div>
    </div>
  </header>

  <nav class="enlaces-celular" aria-label="Secciones">
    <RouterLink v-for="e in enlaces" :key="e.a" :to="e.a" class="enlace-celular">
      <IconoSimple :nombre="e.icono" />
      <span>{{ e.texto }}</span>
    </RouterLink>
  </nav>
</template>

<style scoped>
.barra {
  background: var(--azul);
  color: #fff;
  position: sticky;
  top: 0;
  z-index: 10;
}
.barra-interior {
  max-width: 980px;
  margin: 0 auto;
  padding: 0.5rem 1rem;
  display: flex;
  align-items: center;
  gap: 1rem;
}
.marca {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #fff;
  font-weight: 800;
  font-size: 1.15rem;
  text-decoration: none;
}
.marca img { border-radius: 8px; border: 2px solid rgba(255, 255, 255, 0.6); }
.enlaces-escritorio { display: none; gap: 0.25rem; flex: 1; }
.enlace {
  color: #fff;
  text-decoration: none;
  padding: 0.45rem 0.75rem;
  border-radius: 8px;
  font-weight: 600;
}
.enlace:hover { background: rgba(255, 255, 255, 0.15); }
.enlace.router-link-exact-active,
.enlace.router-link-active:not([href='#/']) { background: rgba(255, 255, 255, 0.22); }
.usuario { margin-left: auto; display: flex; align-items: center; gap: 0.6rem; }
.usuario-datos { display: flex; flex-direction: column; text-align: right; line-height: 1.15; }
.usuario-datos strong { font-size: 0.9rem; }
.usuario-datos span { font-size: 0.78rem; opacity: 0.9; }
.usuario .boton { background: #fff; }
.solo-escritorio { display: none; }

.enlaces-celular {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 10;
  display: flex;
  background: #fff;
  border-top: 1px solid var(--borde);
  padding-bottom: env(safe-area-inset-bottom);
}
.enlace-celular {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  padding: 0.45rem 0.2rem;
  min-height: 56px;
  color: var(--gris);
  text-decoration: none;
  font-size: 0.72rem;
  font-weight: 600;
}
.enlace-celular.router-link-exact-active,
.enlace-celular.router-link-active:not([href='#/']) { color: var(--azul); }

@media (min-width: 760px) {
  .enlaces-escritorio { display: flex; }
  .enlaces-celular { display: none; }
  .solo-escritorio { display: inline; }
}
@media (max-width: 380px) {
  .usuario-datos strong { display: none; }
}
</style>
