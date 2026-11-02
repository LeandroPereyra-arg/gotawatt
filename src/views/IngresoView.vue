<script setup>
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ingresar, ingresarDemo, modoDemo, sesion } from '../stores/sesion'
import { avisar } from '../stores/avisos'
import { validarIngreso, hayErrores } from '../utils/validaciones'
import { ROLES } from '../utils/reglas'
import CampoFormulario from '../components/CampoFormulario.vue'
import logo from '../assets/logo.svg'

const router = useRouter()
const ruta = useRoute()

const form = reactive({ correo: '', clave: '' })
const errores = ref({})
const errorGeneral = ref('')
const procesando = ref(false)

const descripciones = {
  administrador: 'Gestiona usuarios, corrige mediciones y ve todo.',
  socio: 'Registra desperdicios y carga mediciones.',
  mantenimiento: 'Ve los reportes y cambia su estado.',
  docente: 'Consulta reportes y estadísticas (solo lectura).'
}

function irAdentro() {
  if (!sesion.perfil?.activo) return router.push('/cuenta-pendiente')
  router.push(ruta.query.volver || '/')
}

async function enviar() {
  errorGeneral.value = ''
  errores.value = validarIngreso(form)
  if (hayErrores(errores.value)) return
  procesando.value = true
  try {
    await ingresar(form.correo, form.clave)
    avisar(`¡Hola, ${sesion.perfil?.nombre ?? ''}!`)
    irAdentro()
  } catch (e) {
    errorGeneral.value = e.message
  } finally {
    procesando.value = false
  }
}

async function entrarComo(rol) {
  procesando.value = true
  try {
    await ingresarDemo(rol)
    avisar(`Ingresaste con el rol simulado: ${ROLES[rol]}.`)
    irAdentro()
  } finally {
    procesando.value = false
  }
}
</script>

<template>
  <section class="ingreso">
    <div class="cabecera">
      <img :src="logo" alt="" width="64" height="64" />
      <h1>GotaWatt</h1>
      <p class="subtitulo">Cooperativa Escolar · Ahorro de agua y energía</p>
    </div>

    <!-- MODO DEMOSTRACIÓN: roles simulados -->
    <div v-if="modoDemo" class="tarjeta">
      <h2>Elegí un rol para probar</h2>
      <p class="texto-gris">
        La app está en <strong>modo demostración</strong>: los roles son simulados (no hay contraseña)
        y todos los datos son de prueba.
      </p>
      <div class="roles">
        <button v-for="(nombre, rol) in ROLES" :key="rol" type="button" class="rol" :disabled="procesando" @click="entrarComo(rol)">
          <strong>{{ nombre }}</strong>
          <span>{{ descripciones[rol] }}</span>
        </button>
      </div>
    </div>

    <!-- CON SUPABASE: cuentas reales -->
    <form v-else class="tarjeta" novalidate @submit.prevent="enviar">
      <h2>Ingresar</h2>
      <CampoFormulario etiqueta="Correo electrónico" para="correo" :error="errores.correo" obligatorio>
        <input id="correo" v-model="form.correo" type="email" autocomplete="email" inputmode="email" />
      </CampoFormulario>
      <CampoFormulario etiqueta="Contraseña" para="clave" :error="errores.clave" obligatorio>
        <input id="clave" v-model="form.clave" type="password" autocomplete="current-password" />
      </CampoFormulario>
      <p v-if="errorGeneral" class="texto-rojo" role="alert">{{ errorGeneral }}</p>
      <button class="boton ancho" type="submit" :disabled="procesando">
        {{ procesando ? 'Ingresando…' : 'Ingresar' }}
      </button>
      <p class="mt texto-gris centro">
        ¿Querés sumarte a la cooperativa? <RouterLink to="/registro">Creá tu cuenta</RouterLink>
      </p>
    </form>
  </section>
</template>

<style scoped>
.ingreso { max-width: 460px; margin: 1rem auto; }
.cabecera { text-align: center; margin-bottom: 1.25rem; }
.cabecera img { border-radius: 16px; }
.cabecera h1 { font-size: 2rem; margin-top: 0.5rem; color: var(--azul); }
.roles { display: grid; gap: 0.6rem; }
.rol {
  display: grid;
  gap: 0.15rem;
  text-align: left;
  padding: 0.8rem 1rem;
  border: 1px solid var(--borde);
  border-radius: 10px;
  background: #fff;
  font: inherit;
  cursor: pointer;
  min-height: 56px;
}
.rol:hover { border-color: var(--azul); background: var(--azul-claro); }
.rol span { color: var(--gris); font-size: 0.9rem; }
.centro { text-align: center; }
</style>
