# GotaWatt · Cooperativa Escolar

Sistema web para **detectar, registrar y reducir el desperdicio de agua y energía** en la escuela.
Permite reportar canillas que gotean, luces o equipos encendidos sin uso, cargar las lecturas de los
medidores y ver cómo evoluciona el consumo.

Hecho con **Vue 3 + Vite**, **Vue Router** y **Supabase** (base de datos PostgreSQL, autenticación y almacenamiento de fotos).

---

## Funciones de la primera versión

| Función | Administrador | Socio relevador | Mantenimiento | Docente asesor |
|---|:---:|:---:|:---:|:---:|
| Ver panel, reportes y estadísticas | ✔ | ✔ | ✔ | ✔ |
| Crear reporte con foto | ✔ | ✔ | | |
| Editar o anular su reporte pendiente | ✔ (todos) | ✔ (propios) | | |
| Cambiar estado (en reparación / resuelto) | ✔ | | ✔ | |
| Cargar lecturas de medidores y goteo | ✔ | ✔ | | |
| Anular mediciones con error | ✔ | | | |
| Habilitar cuentas y asignar roles | ✔ | | | |
| Eliminar registros **de prueba** | ✔ | | | |

Quedan para una próxima versión: reporte anónimo con código QR para la comunidad, encuestas, inventario
de equipos e informe en PDF.

## Cómo usarlo

Necesitás [Node.js](https://nodejs.org) 18 o superior.

```bash
npm install
npm run dev
```

Abrí la dirección que aparece en la terminal (por ejemplo `http://localhost:5173`).

### Modo demostración (sin configurar nada)

Si no hay archivo `.env`, la app arranca en **modo demostración**:

- Los **roles son simulados**: en la pantalla de ingreso se elige con qué rol entrar, sin contraseña.
- Los **datos son de prueba** (`src/data/datos-prueba.json`) y se guardan solo en ese navegador.
- Una franja violeta en la parte superior y la etiqueta **Prueba** en cada registro lo indican.

### Conectar con Supabase

1. Creá un proyecto en [supabase.com](https://supabase.com).
2. En **SQL Editor** ejecutá, en este orden:
   - `supabase/01_estructura.sql` (tablas, claves, relaciones y reglas)
   - `supabase/02_politicas.sql` (permisos por rol y bucket de fotos)
3. Copiá `.env.example` como `.env` y completá `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY`
   (en **Project Settings → API**). **Usá solo la clave pública `anon`.**
4. Iniciá la app, creá tu cuenta desde **Crear cuenta** y confirmá el correo si Supabase lo pide.
5. En el SQL Editor ejecutá `supabase/00_primer_administrador.sql` con tu correo para hacerte administrador.
6. Ejecutá `supabase/03_datos_prueba.sql` para cargar los lugares, tipos, medidores y registros simulados.

Los demás usuarios se registran desde la app y el administrador los habilita en **Usuarios**.

## Estructura del proyecto

```
├── index.html
├── public/                  ícono de la app
├── supabase/                scripts SQL para crear la base de datos
├── docs/                    documentación del diseño
└── src/
    ├── main.js              punto de entrada
    ├── App.vue              estructura general (barra, avisos)
    ├── router/              rutas y control de acceso por rol
    ├── views/               pantallas (ingreso, panel, reportes, mediciones, estadísticas, usuarios)
    ├── components/          piezas reutilizables (barra, diálogos, chips, mensajes)
    ├── services/            acceso a datos: Supabase o modo demostración
    ├── stores/              sesión, avisos y preferencias
    ├── utils/               reglas por rol, validaciones, formatos y cálculos
    ├── data/                datos de prueba
    └── assets/              estilos y logo
```

## Seguridad

- Los permisos se aplican **en la base de datos** con Row Level Security (`supabase/02_politicas.sql`),
  no solo ocultando botones.
- Los registros reales no se borran: se **anulan** con un motivo y queda el historial.
- El archivo `.env` no se sube al repositorio. Nunca pongas la clave `service_role` en la app.

Más detalles en [`docs/documentacion.md`](docs/documentacion.md).

## Publicar la app

```bash
npm run build
```

Genera la carpeta `dist/`, que se puede subir a cualquier hosting estático (GitHub Pages, Netlify, Vercel).
Como la app usa rutas con `#`, funciona sin configuración extra.
