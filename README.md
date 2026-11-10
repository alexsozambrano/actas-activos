# Actas de Activos

Micro-app para crear actas de entrega, recepción, devolución y traslado de activos, con lectura de códigos de barras, dos firmas digitales, historial compartido y PDF.

- `index.html`: la app publicada en Netlify (generada).
- `app-source.html`: código fuente de la app.
- `build.py`: genera `index.html` a partir de `app-source.html` con la URL y la clave pública de Supabase:
  `python3 build.py <SUPABASE_URL> <PUBLISHABLE_KEY> index.html`
- `supabase/`: scripts SQL, en orden:
  1. `1-crear-tablas.sql`: tablas de actas y ajustes.
  2. `2-registro-usuarios.sql`: registro de usuarios con aprobación del administrador.
  3. `3-permisos-firma.sql`: solo el administrador crea, corrige y borra actas; quien recibe ve solo las actas con su correo y firma "conforme".

Netlify publica la carpeta raíz automáticamente con cada cambio en la rama principal.
