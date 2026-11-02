<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { api } from '../services/api'
import { recargarPerfil } from '../stores/sesion'
import { avisar } from '../stores/avisos'
import { validarRegistro, hayErrores } from '../utils/validaciones'
import CampoFormulario from '../components/CampoFormulario.vue'

const router = useRouter()
const form = reactive({ nombre: '', cursoCargo: '', correo: '', clave: '', clave2: '' })
const errores = ref({})
const errorGeneral = ref('')
const procesando = ref(false)
const enviado = ref(false)

async function enviar() {
  errorGeneral.value = ''
  errores.value = validarRegistro(form)
  if (hayErrores(errores.value)) return
  procesando.value = true
  try {
    const { requiereConfirmacion } = await api.registrarse(form)
    if (requiereConfirmacion) {
      enviado.value = true
    } else {
      await recargarPerfil()
      avisar('Cuenta creada. Un administrador tiene que habilitarla.')
      router.push('/cuenta-pendiente')
    }
  } catch (e) {
    errorGeneral.value = e.message
  } finally {
    procesando.value = false
  }
}
</script>

<template>
  <section class="registro">
    <h1>Crear cuenta</h1>
    <p class="subtitulo">Tu cuenta queda pendiente hasta que el administrador de la cooperativa la habilite y te asigne un rol.</p>

    <div v-if="enviado" class="tarjeta mt" role="status">
      <h2>Revisá tu correo</h2>
      <p>Te enviamos un enlace para confirmar la cuenta. Después podés ingresar.</p>
      <RouterLink to="/ingresar" class="boton">Ir a ingresar</RouterLink>
    </div>

    <form v-else class="tarjeta mt" novalidate @submit.prevent="enviar">
      <CampoFormulario etiqueta="Nombre y apellido" para="nombre" :error="errores.nombre" obligatorio>
        <input id="nombre" v-model="form.nombre" autocomplete="name" maxlength="80" />
      </CampoFormulario>
      <CampoFormulario etiqueta="Curso o cargo" para="curso" :error="errores.cursoCargo" ayuda="Ej.: 5° A, Maestranza, Docente de Química">
        <input id="curso" v-model="form.cursoCargo" maxlength="40" />
      </CampoFormulario>
      <CampoFormulario etiqueta="Correo electrónico" para="correo" :error="errores.correo" obligatorio>
        <input id="correo" v-model="form.correo" type="email" autocomplete="email" inputmode="email" />
      </CampoFormulario>
      <CampoFormulario etiqueta="Contraseña" para="clave" :error="errores.clave" ayuda="Al menos 8 caracteres." obligatorio>
        <input id="clave" v-model="form.clave" type="password" autocomplete="new-password" />
      </CampoFormulario>
      <CampoFormulario etiqueta="Repetir contraseña" para="clave2" :error="errores.clave2" obligatorio>
        <input id="clave2" v-model="form.clave2" type="password" autocomplete="new-password" />
      </CampoFormulario>
      <p v-if="errorGeneral" class="texto-rojo" role="alert">{{ errorGeneral }}</p>
      <div class="fila">
        <RouterLink to="/ingresar" class="boton secundario">Volver</RouterLink>
        <button class="boton" type="submit" :disabled="procesando">{{ procesando ? 'Creando…' : 'Crear cuenta' }}</button>
      </div>
    </form>
  </section>
</template>

<style scoped>
.registro { max-width: 520px; margin: 0 auto; }
</style>
