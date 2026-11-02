import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { iniciarApp } from './stores/sesion'
import './assets/estilos.css'

// Antes de mostrar la app se revisa si ya había una sesión abierta
iniciarApp().then(() => {
  createApp(App).use(router).mount('#app')
})
