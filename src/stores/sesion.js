// Estado compartido de la sesión: quién está usando la app y con qué rol.
import { reactive, computed } from 'vue'
import { api, modoDemo } from '../services/api'
import { puede as puedeRol } from '../utils/reglas'

export const sesion = reactive({
  usuario: null,
  perfil: null,
  catalogos: { lugares: [], tipos: [], medidores: [] },
  lista: false // true cuando ya se revisó si había una sesión abierta
})

export const rol = computed(() => (sesion.perfil?.activo ? sesion.perfil.rol : null))
export const puede = (accion) => puedeRol(rol.value, accion)
export { modoDemo }

async function aplicar(datos) {
  sesion.usuario = datos?.usuario ?? null
  sesion.perfil = datos?.perfil ?? null
  if (sesion.perfil?.activo) sesion.catalogos = await api.obtenerCatalogos()
}

export async function iniciarApp() {
  try {
    await aplicar(await api.obtenerSesion())
  } catch (e) {
    console.error(e)
    await aplicar(null)
  }
  sesion.lista = true
  api.alCambiarSesion((evento) => {
    if (evento === 'SIGNED_OUT') aplicar(null)
  })
}

export async function ingresar(correo, clave) {
  await aplicar(await api.iniciarSesion(correo, clave))
}

export async function ingresarDemo(rolElegido) {
  await aplicar(await api.iniciarDemo(rolElegido))
}

export async function salir() {
  await api.cerrarSesion()
  await aplicar(null)
}

// Se llama después de modificar lugares, tipos o medidores
export async function recargarCatalogos() {
  sesion.catalogos = await api.obtenerCatalogos()
}

export async function recargarPerfil() {
  await aplicar(await api.obtenerSesion())
}
