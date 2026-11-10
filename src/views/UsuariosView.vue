<script setup>
import { computed, ref } from 'vue'
import { api } from '../services/api'
import { sesion, modoDemo } from '../stores/sesion'
import { avisar, avisarError } from '../stores/avisos'
import { useCarga } from '../composables/useCarga'
import { useTiempoReal } from '../composables/useTiempoReal'
import { ROLES } from '../utils/reglas'
import { formatoFecha } from '../utils/formato'
import EstadoCarga from '../components/EstadoCarga.vue'
import DialogoConfirmar from '../components/DialogoConfirmar.vue'

const usuarios = ref([])
const guardando = ref(null)
const busqueda = ref('')
const filtroRol = ref('')
const filtroEstado = ref('')

const { cargando, error, cargar } = useCarga(async () => {
  usuarios.value = await api.listarUsuarios()
})
cargar()
// Cuando alguien nuevo se registra, aparece sin recargar la página
useTiempoReal(['perfiles'], () => {
  if (!confirmando.value) cargar({ silencioso: true })
})

const pendientes = computed(() => usuarios.value.filter((u) => !u.activo).length)
const filtrados = computed(() => {
  const t = busqueda.value.trim().toLowerCase()
  return usuarios.value
    .filter((u) => !t || u.nombre.toLowerCase().includes(t) || (u.curso_cargo ?? '').toLowerCase().includes(t))
    .filter((u) => !filtroRol.value || u.rol === filtroRol.value)
    .filter((u) => !filtroEstado.value || (filtroEstado.value === 'habilitados' ? u.activo : !u.activo))
    .sort((a, b) => Number(a.activo) - Number(b.activo) || a.nombre.localeCompare(b.nombre, 'es')) // primero los pendientes
})

// Los cambios de rol y de habilitación se confirman antes de guardarse
const confirmando = ref(null) // { usuario, cambios, selector }
const textoConfirmacion = computed(() => {
  const c = confirmando.value
  if (!c) return { titulo: '', mensaje: '', boton: '' }
  const { usuario: u, cambios } = c
  if (cambios.rol) {
    return {
      titulo: `Cambiar el rol de ${u.nombre}`,
      mensaje: `Pasará de «${ROLES[u.rol]}» a «${ROLES[cambios.rol]}» y verá solo las funciones de ese rol.`,
      boton: 'Cambiar rol'
    }
  }
  return cambios.activo
    ? { titulo: `Habilitar a ${u.nombre}`, mensaje: `Va a poder ingresar como «${ROLES[u.rol]}». Revisá que el rol sea el correcto.`, boton: 'Habilitar' }
    : { titulo: `Deshabilitar a ${u.nombre}`, mensaje: 'No va a poder ingresar al sistema. Sus reportes y mediciones se conservan.', boton: 'Deshabilitar' }
})

function pedirConfirmacion(usuario, cambios, evento = null) {
  confirmando.value = { usuario, cambios, selector: evento?.target ?? null }
}

function cancelar() {
  // Si se canceló un cambio de rol, el selector vuelve al rol anterior
  const c = confirmando.value
  if (c?.selector) c.selector.value = c.usuario.rol
  confirmando.value = null
}

async function guardar() {
  const { usuario: u, cambios } = confirmando.value
  guardando.value = u.id
  try {
    await api.actualizarUsuario(u.id, { rol: u.rol, activo: u.activo, ...cambios })
    Object.assign(u, cambios)
    avisar(cambios.activo === undefined ? `Rol de ${u.nombre}: ${ROLES[u.rol]}.` : cambios.activo ? `${u.nombre} fue habilitado.` : `${u.nombre} fue deshabilitado.`)
    confirmando.value = null
  } catch (e) {
    avisarError(e)
    cancelar()
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

  <div class="filtros mt">
    <div class="campo">
      <label for="buscar-usuario">Buscar</label>
      <input id="buscar-usuario" v-model="busqueda" type="search" placeholder="Nombre o curso" />
    </div>
    <div class="campo">
      <label for="filtro-rol">Rol</label>
      <select id="filtro-rol" v-model="filtroRol">
        <option value="">Todos</option>
        <option v-for="(nombre, clave) in ROLES" :key="clave" :value="clave">{{ nombre }}</option>
      </select>
    </div>
    <div class="campo">
      <label for="filtro-estado">Estado</label>
      <select id="filtro-estado" v-model="filtroEstado">
        <option value="">Todos</option>
        <option value="pendientes">Esperando habilitación</option>
        <option value="habilitados">Habilitados</option>
      </select>
    </div>
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
        <select :id="`rol-${u.id}`" :value="u.rol" :disabled="u.id === sesion.perfil.id || guardando === u.id" @change="pedirConfirmacion(u, { rol: $event.target.value }, $event)">
          <option v-for="(nombre, clave) in ROLES" :key="clave" :value="clave">{{ nombre }}</option>
        </select>
        <button
          type="button"
          class="boton chico"
          :class="u.activo ? 'peligro' : 'verde'"
          :disabled="u.id === sesion.perfil.id || guardando === u.id"
          @click="pedirConfirmacion(u, { activo: !u.activo })"
        >
          {{ guardando === u.id ? 'Guardando…' : u.activo ? 'Deshabilitar' : 'Habilitar' }}
        </button>
      </div>
    </li>
  </ul>
  <p v-if="!cargando && !error && !filtrados.length" class="vacio tarjeta">No hay usuarios con esos filtros.</p>

  <DialogoConfirmar
    :abierto="Boolean(confirmando)"
    :titulo="textoConfirmacion.titulo"
    :mensaje="textoConfirmacion.mensaje"
    :texto-confirmar="textoConfirmacion.boton"
    :peligro="confirmando?.cambios.activo === false"
    :procesando="Boolean(guardando)"
    @confirmar="guardar"
    @cancelar="cancelar"
  />
</template>

<style scoped>
.filtros { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 0 1rem; }
.usuario { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 0.75rem; }
.usuario.inactivo { border-left: 5px solid var(--amarillo); }
.controles { display: flex; gap: 0.5rem; align-items: center; flex-wrap: wrap; }
.controles select { width: auto; min-width: 170px; }
.aviso-pendientes { background: var(--amarillo-claro); color: var(--amarillo); font-weight: 600; }
</style>
