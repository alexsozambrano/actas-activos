-- Actas de Activos: catálogo de códigos de barras (código -> descripción, marca, modelo, serie)
-- Al escanear un código que ya está en el catálogo, la app llena la descripción sola.
-- Cada vez que se guarda un acta, sus activos con código se guardan o actualizan aquí.
-- Ejecútalo DESPUÉS de los archivos 1 a 6 (Supabase -> SQL Editor -> New query -> Run).
-- Se puede ejecutar más de una vez sin problema.

create table if not exists public.catalogo (
  clave        text primary key,              -- el código en minúsculas y sin espacios al inicio/fin
  codigo       text not null,                 -- el código tal como se escaneó
  descripcion  text not null,
  marca        text not null default '',
  modelo       text not null default '',
  serie        text not null default '',
  updated_by   uuid default auth.uid() references auth.users(id) on delete set null,
  updated_at   timestamptz not null default now()
);

-- La clave siempre se calcula en el servidor a partir del código
create or replace function public.catalogo_normalizar() returns trigger
language plpgsql as $$
begin
  new.codigo     := btrim(new.codigo);
  new.clave      := lower(new.codigo);
  new.updated_at := now();
  if auth.uid() is not null then new.updated_by := auth.uid(); end if;
  return new;
end $$;
drop trigger if exists antes_de_guardar_catalogo on public.catalogo;
create trigger antes_de_guardar_catalogo before insert or update on public.catalogo
  for each row execute function public.catalogo_normalizar();

-- Permisos:
--   ver, agregar y actualizar: cualquier usuario aprobado
--   borrar:                    solo el administrador
alter table public.catalogo enable row level security;
drop policy if exists "catalogo: leer"    on public.catalogo;
drop policy if exists "catalogo: crear"   on public.catalogo;
drop policy if exists "catalogo: editar"  on public.catalogo;
drop policy if exists "catalogo: borrar"  on public.catalogo;
create policy "catalogo: leer"   on public.catalogo for select to authenticated using (public.es_aprobado());
create policy "catalogo: crear"  on public.catalogo for insert to authenticated with check (public.es_aprobado());
create policy "catalogo: editar" on public.catalogo for update to authenticated
  using (public.es_aprobado()) with check (public.es_aprobado());
create policy "catalogo: borrar" on public.catalogo for delete to authenticated using (public.es_admin());

-- Llenar el catálogo con los activos de las actas que ya existen (el dato del acta más reciente gana).
-- No pisa códigos que ya estén en el catálogo.
insert into public.catalogo (clave, codigo, descripcion, marca, modelo, serie)
select distinct on (lower(btrim(it->>'codigo')))
       lower(btrim(it->>'codigo')),
       btrim(it->>'codigo'),
       btrim(it->>'descripcion'),
       coalesce(btrim(it->>'marca'), ''),
       coalesce(btrim(it->>'modelo'), ''),
       coalesce(btrim(it->>'serie'), '')
  from public.actas a
  cross join lateral jsonb_array_elements(coalesce(a.data->'activos', '[]'::jsonb)) it
 where coalesce(btrim(it->>'codigo'), '') <> ''
   and coalesce(btrim(it->>'descripcion'), '') <> ''
 order by lower(btrim(it->>'codigo')), a.fecha desc
on conflict (clave) do nothing;
