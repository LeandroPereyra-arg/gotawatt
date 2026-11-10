// Vuelve a cargar los datos de la pantalla cuando cambian las tablas indicadas,
// sin que el usuario tenga que recargar la página.
import { onBeforeUnmount } from 'vue'
import { api } from '../services/api'

export function useTiempoReal(tablas, alCambiar) {
  let espera = null
  // Se espera un momento para juntar varios cambios seguidos en una sola recarga
  const detener = api.escucharCambios(tablas, () => {
    clearTimeout(espera)
    espera = setTimeout(alCambiar, 400)
  })
  onBeforeUnmount(() => {
    clearTimeout(espera)
    detener()
  })
}
