<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { sesion, salir, recargarPerfil } from '../stores/sesion'
import { avisar, avisarError } from '../stores/avisos'

const router = useRouter()
const revisando = ref(false)

async function revisar() {
  revisando.value = true
  try {
    await recargarPerfil()
    if (sesion.perfil?.activo) {
      avisar('¡Tu cuenta ya está habilitada!')
      router.push('/')
    } else {
      avisar('Tu cuenta todavía no fue habilitada.', 'error')
    }
  } catch (e) {
    avisarError(e)
  } finally {
    revisando.value = false
  }
}

async function cerrar() {
  await salir()
  router.push('/ingresar')
}
</script>

<template>
  <section class="tarjeta pendiente">
    <h1>Cuenta pendiente</h1>
    <p>
      Hola, <strong>{{ sesion.perfil?.nombre }}</strong>. Tu cuenta fue creada, pero el administrador de la
      cooperativa todavía tiene que habilitarla y asignarte un rol.
    </p>
    <div class="fila">
      <button class="boton" type="button" :disabled="revisando" @click="revisar">
        {{ revisando ? 'Revisando…' : 'Volver a revisar' }}
      </button>
      <button class="boton secundario" type="button" @click="cerrar">Cerrar sesión</button>
    </div>
  </section>
</template>

<style scoped>
.pendiente { max-width: 520px; margin: 2rem auto; }
</style>
