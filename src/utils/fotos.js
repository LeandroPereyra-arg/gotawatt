// Achica la foto antes de guardarla para que ocupe poco espacio (máximo 1024 px).
export function achicarFoto(archivo, maximo = 1024, calidad = 0.75) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(archivo)
    const img = new Image()
    img.onload = () => {
      const escala = Math.min(1, maximo / Math.max(img.width, img.height))
      const canvas = document.createElement('canvas')
      canvas.width = Math.round(img.width * escala)
      canvas.height = Math.round(img.height * escala)
      canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height)
      URL.revokeObjectURL(url)
      canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error('No se pudo procesar la foto.'))), 'image/jpeg', calidad)
    }
    img.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('El archivo no es una imagen válida.'))
    }
    img.src = url
  })
}

export function blobADataUrl(blob) {
  return new Promise((resolve, reject) => {
    const lector = new FileReader()
    lector.onload = () => resolve(lector.result)
    lector.onerror = () => reject(new Error('No se pudo leer la foto.'))
    lector.readAsDataURL(blob)
  })
}
