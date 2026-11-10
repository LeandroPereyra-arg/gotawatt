// Maneja el estado de carga y de error de una pantalla.
// "cargar()" muestra la ruedita; "cargar({ silencioso: true })" actualiza los datos
// sin tapar la pantalla (se usa cuando otro usuario hace un cambio).
import { ref } from 'vue'

export function useCarga(funcion) {
  const cargando = ref(true)
  const error = ref('')

  async function cargar({ silencioso = false } = {}) {
    if (!silencioso) {
      cargando.value = true
      error.value = ''
    }
    try {
      await funcion()
      error.value = ''
    } catch (e) {
      if (silencioso) console.error(e)
      else error.value = e.message
    } finally {
      cargando.value = false
    }
  }

  return { cargando, error, cargar }
}
