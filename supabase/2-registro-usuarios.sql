-- Actas de Activos: registro de usuarios con aprobación
-- Ejecútalo DESPUÉS de 1-crear-tablas.sql (Supabase -> SQL Editor -> New query -> Run)
-- Los usuarios que ya existen quedan aprobados y como administradores.

create table if not exists public.perfiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  nombre      text,
  rol         text not null default 'usuario' check (rol in ('admin','usuario')),
  estado      text not null default 'pendiente' check (estado in ('pendiente','aprobado','rechazado')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Funciones de apoyo (se ejecutan con permisos del sistema para evitar recursión en las políticas)
create or replace function public.es_aprobado() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfiles where id = auth.uid() and estado = 'aprobado');
$$;
create or replace function public.es_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfiles where id = auth.uid() and estado = 'aprobado' and rol = 'admin');
$$;

-- Al registrarse alguien, se crea su perfil como "pendiente"
create or replace function public.crear_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfiles (id, email, nombre)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'nombre', ''))
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario after insert on auth.users
  for each row execute function public.crear_perfil();

-- Usuarios existentes: aprobados y administradores
insert into public.perfiles (id, email, nombre, rol, estado)
select id, email, coalesce(raw_user_meta_data->>'nombre', ''), 'admin', 'aprobado' from auth.users
on conflict (id) do update set rol = 'admin', estado = 'aprobado';

-- Permisos de perfiles: cada quien ve el suyo; el administrador ve y cambia todos
alter table public.perfiles enable row level security;
drop policy if exists "perfiles: ver"     on public.perfiles;
drop policy if exists "perfiles: editar"  on public.perfiles;
drop policy if exists "perfiles: borrar"  on public.perfiles;
create policy "perfiles: ver"    on public.perfiles for select to authenticated using (id = auth.uid() or public.es_admin());
create policy "perfiles: editar" on public.perfiles for update to authenticated using (public.es_admin()) with check (public.es_admin());
create policy "perfiles: borrar" on public.perfiles for delete to authenticated using (public.es_admin());

-- Las actas y los ajustes ahora exigen cuenta aprobada
drop policy if exists "actas: leer"    on public.actas;
drop policy if exists "actas: crear"   on public.actas;
drop policy if exists "actas: editar"  on public.actas;
drop policy if exists "actas: borrar"  on public.actas;
create policy "actas: leer"   on public.actas for select to authenticated using (public.es_aprobado());
create policy "actas: crear"  on public.actas for insert to authenticated with check (public.es_aprobado());
create policy "actas: editar" on public.actas for update to authenticated using (public.es_aprobado()) with check (public.es_aprobado());
create policy "actas: borrar" on public.actas for delete to authenticated using (public.es_aprobado());

drop policy if exists "config: leer"    on public.config;
drop policy if exists "config: crear"   on public.config;
drop policy if exists "config: editar"  on public.config;
create policy "config: leer"   on public.config for select to authenticated using (public.es_aprobado());
create policy "config: crear"  on public.config for insert to authenticated with check (public.es_admin());
create policy "config: editar" on public.config for update to authenticated using (public.es_admin()) with check (public.es_admin());

do $$ begin
  alter publication supabase_realtime add table public.perfiles;
exception when duplicate_object then null; end $$;
