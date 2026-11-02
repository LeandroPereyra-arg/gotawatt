<script setup>
import { computed, onMounted, ref } from 'vue'
import { api } from '../services/api'
import { sesion, modoDemo } from '../stores/sesion'
import { avisar, avisarError } from '../stores/avisos'
import { ROLES } from '../utils/reglas'
import { formatoFecha } from '../utils/formato'
import EstadoCarga from '../components/EstadoCarga.vue'

const usuarios = ref([])
const cargando = ref(true)
const error = ref('')
const guardando = ref(null)
const busqueda = ref('')

async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    usuarios.value = await api.listarUsuarios()
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)

const pendientes = computed(() => usuarios.value.filter((u) => !u.activo).length)
const filtrados = computed(() => {
  const t = busqueda.value.trim().toLowerCase()
  return usuarios.value
    .filter((u) => !t || u.nombre.toLowerCase().includes(t) || (u.curso_cargo ?? '').toLowerCase().includes(t))
    .sort((a, b) => Number(a.activo) - Number(b.activo)) // primero los pendientes
})

async function guardar(u, cambios) {
  guardando.value = u.id
  try {
    await api.actualizarUsuario(u.id, { rol: u.rol, activo: u.activo, ...cambios })
    Object.assign(u, cambios)
    avisar(cambios.activo === undefined ? `Rol de ${u.nombre}: ${ROLES[u.rol]}.` : cambios.activo ? `${u.nombre} fue habilitado.` : `${u.nombre} fue deshabilitado.`)
  } catch (e) {
    avisarError(e)
    await cargar()
  } finally {
    guardando.value = null
  }
}
</script>

<template>
  <div class="encabezado-vista">
    <div>
      <h1>Usuarios</h1>
      <p class="subtitulo">Habilitá cuentas nuevas y asigná roles. Las cuentas no se borran: se deshabilitan.</p>
    </div>
  </div>

  <p v-if="modoDemo" class="tarjeta texto-gris">En modo demostración estos usuarios son simulados.</p>
  <p v-if="pendientes" class="tarjeta aviso-pendientes mt">Hay {{ pendientes }} {{ pendientes === 1 ? 'cuenta esperando' : 'cuentas esperando' }} habilitación.</p>

  <div class="campo mt">
    <label for="buscar-usuario">Buscar</label>
    <input id="buscar-usuario" v-model="busqueda" type="search" placeholder="Nombre o curso" />
  </div>

  <EstadoCarga :cargando="cargando" :error="error" @reintentar="cargar" />

  <ul v-if="!cargando && !error" class="lista">
    <li v-for="u in filtrados" :key="u.id" class="tarjeta usuario" :class="{ inactivo: !u.activo }">
      <div>
        <strong>{{ u.nombre }}</strong>
        <span v-if="u.id === sesion.perfil.id" class="chip agua">Vos</span>
        <div class="texto-gris">{{ u.curso_cargo || 'Sin curso o cargo' }}<template v-if="u.creado_en"> · desde {{ formatoFecha(u.creado_en) }}</template></div>
      </div>
      <div class="controles">
        <label :for="`rol-${u.id}`" class="oculto-visual">Rol de {{ u.nombre }}</label>
        <select :id="`rol-${u.id}`" :value="u.rol" :disabled="u.id === sesion.perfil.id || guardando === u.id" @change="guardar(u, { rol: $event.target.value })">
          <option v-for="(nombre, clave) in ROLES" :key="clave" :value="clave">{{ nombre }}</option>
        </select>
        <button
          type="button"
          class="boton chico"
          :class="u.activo ? 'peligro' : 'verde'"
          :disabled="u.id === sesion.perfil.id || guardando === u.id"
          @click="guardar(u, { activo: !u.activo })"
        >
          {{ guardando === u.id ? 'Guardando…' : u.activo ? 'Deshabilitar' : 'Habilitar' }}
        </button>
      </div>
    </li>
  </ul>
</template>

<style scoped>
.usuario { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 0.75rem; }
.usuario.inactivo { border-left: 5px solid var(--amarillo); }
.controles { display: flex; gap: 0.5rem; align-items: center; flex-wrap: wrap; }
.controles select { width: auto; min-width: 170px; }
.aviso-pendientes { background: var(--amarillo-claro); color: var(--amarillo); font-weight: 600; }
.oculto-visual { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
</style>
