import { createRouter, createWebHashHistory } from 'vue-router'
import { sesion, puede, modoDemo } from '../stores/sesion'
import { avisar } from '../stores/avisos'

const routes = [
  { path: '/ingresar', name: 'ingresar', component: () => import('../views/IngresoView.vue'), meta: { publica: true } },
  { path: '/registro', name: 'registro', component: () => import('../views/RegistroView.vue'), meta: { publica: true } },
  { path: '/cuenta-pendiente', name: 'pendiente', component: () => import('../views/CuentaPendienteView.vue'), meta: { inactivos: true } },
  { path: '/', name: 'panel', component: () => import('../views/PanelView.vue'), meta: { titulo: 'Inicio' } },
  { path: '/reportes', name: 'reportes', component: () => import('../views/ReportesView.vue'), meta: { titulo: 'Reportes' } },
  { path: '/reportes/nuevo', name: 'nuevo-reporte', component: () => import('../views/ReporteFormView.vue'), meta: { titulo: 'Nuevo reporte', permiso: 'crearReporte' } },
  { path: '/reportes/:id', name: 'reporte', component: () => import('../views/ReporteDetalleView.vue'), props: true, meta: { titulo: 'Reporte' } },
  { path: '/reportes/:id/editar', name: 'editar-reporte', component: () => import('../views/ReporteFormView.vue'), props: true, meta: { titulo: 'Editar reporte' } },
  { path: '/mediciones', name: 'mediciones', component: () => import('../views/MedicionesView.vue'), meta: { titulo: 'Mediciones' } },
  { path: '/estadisticas', name: 'estadisticas', component: () => import('../views/EstadisticasView.vue'), meta: { titulo: 'Estadísticas' } },
  { path: '/usuarios', name: 'usuarios', component: () => import('../views/UsuariosView.vue'), meta: { titulo: 'Usuarios', permiso: 'gestionarUsuarios' } },
  { path: '/:ruta(.*)*', name: 'no-encontrado', component: () => import('../views/NoEncontradoView.vue'), meta: { publica: true } }
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 })
})

// Control de acceso en la interfaz (la base de datos aplica los mismos permisos)
router.beforeEach((to) => {
  const conectado = Boolean(sesion.usuario)
  const activo = Boolean(sesion.perfil?.activo)

  if (to.name === 'registro' && modoDemo) return { name: 'ingresar' }
  if (to.meta.publica) {
    if (conectado && activo && ['ingresar', 'registro'].includes(to.name)) return { name: 'panel' }
    return true
  }
  if (!conectado) return { name: 'ingresar', query: to.fullPath !== '/' ? { volver: to.fullPath } : {} }
  if (!activo) return to.meta.inactivos ? true : { name: 'pendiente' }
  if (to.meta.inactivos) return { name: 'panel' }
  if (to.meta.permiso && !puede(to.meta.permiso)) {
    avisar('Tu rol no tiene acceso a esa sección.', 'error')
    return { name: 'panel' }
  }
  return true
})

router.afterEach((to) => {
  document.title = to.meta.titulo ? `${to.meta.titulo} · GotaWatt` : 'GotaWatt · Cooperativa Escolar'
})

export default router
