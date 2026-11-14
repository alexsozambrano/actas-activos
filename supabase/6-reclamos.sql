-- Actas de Activos: reclamos por daños o deterioro de activos (con fotos)
-- Ejecútalo DESPUÉS de los archivos 1 a 5 (Supabase -> SQL Editor -> New query -> Run).
-- Se puede ejecutar más de una vez sin problema.

create table if not exists public.reclamos (
  id          text primary key,
  folio       text not null unique,
  estado      text not null default 'abierto' check (estado in ('abierto','revision','resuelto','rechazado')),
  acta_id     text not null references public.actas(id) on delete cascade,
  data        jsonb not null,
  fotos       jsonb not null default '[]'::jsonb,
  created_by  uuid default auth.uid() references auth.users(id),
  created_at  timestamptz not null default now()
);
create index if not exists reclamos_created_idx on public.reclamos (created_at desc);
create index if not exists reclamos_acta_idx on public.reclamos (acta_id);

-- El servidor asigna el folio RCL-AAAA-NNNN y registra quién lo creó; todo reclamo nuevo empieza "abierto"
create or replace function public.asignar_folio_reclamo() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_pref text := 'RCL-' || to_char(now() at time zone 'America/Lima', 'YYYY') || '-';
  v_n    int;
begin
  if auth.uid() is not null then
    new.created_by := auth.uid();
  end if;
  if not public.es_admin() then
    new.estado := 'abierto';
  end if;
  perform pg_advisory_xact_lock(hashtext('reclamos-folio-' || v_pref));
  select coalesce(max(substring(folio from length(v_pref) + 1)::int), 0) + 1
    into v_n
    from public.reclamos
   where left(folio, length(v_pref)) = v_pref
     and substring(folio from length(v_pref) + 1) ~ '^[0-9]+$';
  new.folio := v_pref || lpad(v_n::text, 4, '0');
  new.data  := jsonb_set(jsonb_set(new.data, '{folio}', to_jsonb(new.folio)), '{estado}', to_jsonb(new.estado));
  return new;
end $$;
drop trigger if exists antes_de_crear_reclamo on public.reclamos;
create trigger antes_de_crear_reclamo before insert on public.reclamos
  for each row execute function public.asignar_folio_reclamo();

-- Permisos:
--   ver:      el administrador ve todos; cada usuario ve los suyos
--   crear:    usuario aprobado, solo sobre un acta que puede ver (la creó o va a su correo)
--   cambiar:  solo el administrador (revisión, resolver, rechazar)
--   borrar:   el administrador, o quien lo creó mientras siga abierto
alter table public.reclamos enable row level security;
drop policy if exists "reclamos: leer"    on public.reclamos;
drop policy if exists "reclamos: crear"   on public.reclamos;
drop policy if exists "reclamos: editar"  on public.reclamos;
drop policy if exists "reclamos: borrar"  on public.reclamos;
create policy "reclamos: leer"   on public.reclamos for select to authenticated
  using (public.es_admin() or (public.es_aprobado() and created_by = auth.uid()));
create policy "reclamos: crear"  on public.reclamos for insert to authenticated
  with check (public.es_aprobado() and created_by = auth.uid()
              and exists (select 1 from public.actas a where a.id = acta_id));
create policy "reclamos: editar" on public.reclamos for update to authenticated
  using (public.es_admin()) with check (public.es_admin());
create policy "reclamos: borrar" on public.reclamos for delete to authenticated
  using (public.es_admin() or (created_by = auth.uid() and estado = 'abierto'));

do $$ begin
  alter publication supabase_realtime add table public.reclamos;
exception when duplicate_object then null; end $$;
