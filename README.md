# Actas de Activos

Micro-app para crear actas de entrega, recepción, devolución y traslado de activos, con lectura de códigos de barras, dos firmas digitales, historial compartido y PDF.

- `index.html`: la app publicada en Netlify (generada).
- `app-source.html`: código fuente de la app.
- `build.py`: genera `index.html` a partir de `app-source.html` con la URL y la clave pública de Supabase:
  `python3 build.py <SUPABASE_URL> <PUBLISHABLE_KEY> index.html`
- `supabase/`: scripts SQL para crear tablas, permisos y el registro de usuarios con aprobación.

Netlify publica la carpeta raíz automáticamente con cada cambio en la rama principal.
