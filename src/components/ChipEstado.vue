<script setup>
import { ESTADOS } from '../utils/reglas'
defineProps({ estado: { type: String, required: true } })
</script>

<template>
  <span class="chip" :class="estado">{{ ESTADOS[estado] }}</span>
</template>
