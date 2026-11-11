-- Actas de Activos: peticiones de activos
-- Ejecútalo DESPUÉS de los archivos 1 a 4 (Supabase -> SQL Editor -> New query -> Run).
-- Se puede ejecutar más de una vez sin problema.

create table if not exists public.peticiones (
  id          text primary key,
  folio       text not null unique,
  estado      text not null default 'pendiente' check (estado in ('pendiente','aprobada','rechazada','atendida')),
  data        jsonb not null,
  created_by  uuid default auth.uid() references auth.users(id),
  created_at  timestamptz not null default now()
);
create index if not exists peticiones_created_idx on public.peticiones (created_at desc);

-- El servidor asigna el folio PET-AAAA-NNNN y registra quién la creó; toda petición nueva empieza "pendiente"
create or replace function public.asignar_folio_peticion() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_pref text := 'PET-' || to_char(now() at time zone 'America/Lima', 'YYYY') || '-';
  v_n    int;
begin
  if auth.uid() is not null then
    new.created_by := auth.uid();
  end if;
  if not public.es_admin() then
    new.estado := 'pendiente';
  end if;
  perform pg_advisory_xact_lock(hashtext('peticiones-folio-' || v_pref));
  select coalesce(max(substring(folio from length(v_pref) + 1)::int), 0) + 1
    into v_n
    from public.peticiones
   where left(folio, length(v_pref)) = v_pref
     and substring(folio from length(v_pref) + 1) ~ '^[0-9]+$';
  new.folio := v_pref || lpad(v_n::text, 4, '0');
  new.data  := jsonb_set(jsonb_set(new.data, '{folio}', to_jsonb(new.folio)), '{estado}', to_jsonb(new.estado));
  return new;
end $$;
drop trigger if exists antes_de_crear_peticion on public.peticiones;
create trigger antes_de_crear_peticion before insert on public.peticiones
  for each row execute function public.asignar_folio_peticion();

-- Permisos:
--   ver:      el administrador ve todas; cada usuario ve las suyas
--   crear:    cualquier usuario aprobado
--   cambiar:  solo el administrador (aprobar, rechazar, atender)
--   borrar:   el administrador, o quien la creó mientras siga pendiente
alter table public.peticiones enable row level security;
drop policy if exists "peticiones: leer"    on public.peticiones;
drop policy if exists "peticiones: crear"   on public.peticiones;
drop policy if exists "peticiones: editar"  on public.peticiones;
drop policy if exists "peticiones: borrar"  on public.peticiones;
create policy "peticiones: leer"   on public.peticiones for select to authenticated
  using (public.es_admin() or (public.es_aprobado() and created_by = auth.uid()));
create policy "peticiones: crear"  on public.peticiones for insert to authenticated
  with check (public.es_aprobado() and created_by = auth.uid());
create policy "peticiones: editar" on public.peticiones for update to authenticated
  using (public.es_admin()) with check (public.es_admin());
create policy "peticiones: borrar" on public.peticiones for delete to authenticated
  using (public.es_admin() or (created_by = auth.uid() and estado = 'pendiente'));

do $$ begin
  alter publication supabase_realtime add table public.peticiones;
exception when duplicate_object then null; end $$;
