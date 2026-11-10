<script setup>
// Íconos simples dibujados con SVG (sin librerías externas)
defineProps({ nombre: { type: String, required: true }, tam: { type: Number, default: 22 } })

const trazos = {
  inicio: 'M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z',
  reportes: 'M6 3h9l4 4v14H6zM14 3v5h5M9 12h7M9 16h7',
  medir: 'M12 3c-4 5-7 9-7 12a7 7 0 0 0 14 0c0-3-3-7-7-12z',
  datos: 'M4 20V10M10 20V4M16 20v-7M22 20H2',
  usuarios: 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21v-1a6 6 0 0 1 12 0v1M17 11a3 3 0 1 0 0-6M22 21v-1a5 5 0 0 0-4-4.9',
  salir: 'M15 4h4a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-4M10 17l5-5-5-5M15 12H3',
  mas: 'M12 5v14M5 12h14',
  atras: 'M15 18l-6-6 6-6',
  buscar: 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM21 21l-5-5',
  catalogo: 'M4 6h16M4 12h16M4 18h10',
  foto: 'M4 7h3l2-3h6l2 3h3v13H4zM12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8z'
}
</script>

<template>
  <svg :width="tam" :height="tam" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
       stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
    <path :d="trazos[nombre]" />
  </svg>
</template>
