-- Actas de Activos: tablas y permisos
-- Pégalo completo en Supabase -> SQL Editor -> New query -> Run

create table if not exists public.actas (
  id          text primary key,
  folio       text not null unique,
  tipo        text not null check (tipo in ('entrega','recepcion','devolucion','traslado')),
  fecha       timestamptz not null,
  data        jsonb not null,
  created_by  uuid default auth.uid() references auth.users(id),
  created_at  timestamptz not null default now()
);
create index if not exists actas_fecha_idx on public.actas (fecha desc);

create table if not exists public.config (
  id          text primary key,
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

-- Solo usuarios con sesión iniciada pueden leer y escribir (todo el equipo comparte el historial)
alter table public.actas  enable row level security;
alter table public.config enable row level security;

drop policy if exists "actas: leer"    on public.actas;
drop policy if exists "actas: crear"   on public.actas;
drop policy if exists "actas: editar"  on public.actas;
drop policy if exists "actas: borrar"  on public.actas;
create policy "actas: leer"   on public.actas for select to authenticated using (true);
create policy "actas: crear"  on public.actas for insert to authenticated with check (true);
create policy "actas: editar" on public.actas for update to authenticated using (true) with check (true);
create policy "actas: borrar" on public.actas for delete to authenticated using (true);

drop policy if exists "config: leer"    on public.config;
drop policy if exists "config: crear"   on public.config;
drop policy if exists "config: editar"  on public.config;
create policy "config: leer"   on public.config for select to authenticated using (true);
create policy "config: crear"  on public.config for insert to authenticated with check (true);
create policy "config: editar" on public.config for update to authenticated using (true) with check (true);

-- Actualización en vivo entre celular y computador
do $$ begin
  alter publication supabase_realtime add table public.actas;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.config;
exception when duplicate_object then null; end $$;
