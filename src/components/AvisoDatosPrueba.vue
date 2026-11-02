<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import DialogoConfirmar from './DialogoConfirmar.vue'
import { sesion, modoDemo, salir } from '../stores/sesion'
import { ROLES } from '../utils/reglas'
import { api } from '../services/api'
import { avisar } from '../stores/avisos'

const router = useRouter()
const confirmando = ref(false)

async function cambiarRol() {
  await salir()
  router.push('/ingresar')
}

function restablecer() {
  confirmando.value = false
  api.restablecerDatos()
  avisar('Se restablecieron los datos de prueba.')
  router.go(0)
}
</script>

<template>
  <div v-if="modoDemo" class="aviso-demo" role="status">
    <p>
      <strong>Modo demostración.</strong>
      Rol simulado: <strong>{{ ROLES[sesion.perfil.rol] }}</strong>.
      Todos los datos son <strong>de prueba</strong> y se guardan solo en este navegador.
    </p>
    <div class="fila">
      <button type="button" class="boton chico secundario" @click="cambiarRol">Cambiar de rol</button>
      <button type="button" class="boton chico secundario" @click="confirmando = true">Restablecer datos</button>
    </div>
    <DialogoConfirmar
      :abierto="confirmando"
      titulo="Restablecer datos de prueba"
      mensaje="Se borran los cambios hechos en este navegador y vuelven los datos de prueba originales."
      texto-confirmar="Restablecer"
      peligro
      @confirmar="restablecer"
      @cancelar="confirmando = false"
    />
  </div>
</template>

<style scoped>
.aviso-demo {
  background: #efe3fb;
  color: #3f2160;
  border-bottom: 1px solid #d7c1ee;
  padding: 0.6rem 1rem;
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem 1rem;
  align-items: center;
  justify-content: center;
  font-size: 0.9rem;
}
.aviso-demo p { margin: 0; max-width: 640px; }
.aviso-demo .boton { border-color: #6a3d9a; color: #6a3d9a; }
</style>
