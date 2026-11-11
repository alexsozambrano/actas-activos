-- Actas de Activos: los usuarios aprobados pueden crear y llenar actas.
-- Corregir y borrar actas sigue siendo solo del administrador.
-- Ejecútalo DESPUÉS de los archivos 1, 2 y 3 (Supabase -> SQL Editor -> New query -> Run).
-- Se puede ejecutar más de una vez sin problema.

-- El servidor asigna el folio (ENT-2026-0001, ...) al crear el acta, para que nunca se repita
-- aunque varias personas guarden al mismo tiempo, y registra quién la creó.
create or replace function public.asignar_folio() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_pref text;
  v_n    int;
begin
  -- Si el acta ya existe (corrección del administrador), no se toca el folio
  if exists (select 1 from public.actas where id = new.id) then
    return new;
  end if;
  if auth.uid() is not null then
    new.created_by := auth.uid();
  end if;
  v_pref := substring(new.folio from '^[A-Z]+-[0-9]{4}-');
  if v_pref is null then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtext('actas-folio-' || v_pref));
  select coalesce(max(substring(folio from length(v_pref) + 1)::int), 0) + 1
    into v_n
    from public.actas
   where left(folio, length(v_pref)) = v_pref
     and substring(folio from length(v_pref) + 1) ~ '^[0-9]+$';
  new.folio := v_pref || lpad(v_n::text, 4, '0');
  new.data  := jsonb_set(new.data, '{folio}', to_jsonb(new.folio));
  return new;
end $$;

drop trigger if exists antes_de_crear_acta on public.actas;
create trigger antes_de_crear_acta before insert on public.actas
  for each row execute function public.asignar_folio();

-- Permisos de actas
--   ver:     el administrador ve todas; cada usuario ve las que creó y las que van a su correo
--   crear:   cualquier usuario aprobado
--   editar y borrar: solo el administrador
drop policy if exists "actas: leer"    on public.actas;
drop policy if exists "actas: crear"   on public.actas;
drop policy if exists "actas: editar"  on public.actas;
drop policy if exists "actas: borrar"  on public.actas;
create policy "actas: leer" on public.actas for select to authenticated
  using (
    public.es_admin()
    or (public.es_aprobado()
        and (created_by = auth.uid()
             or (public.mi_correo() <> ''
                 and lower(coalesce(data -> 'recibe' ->> 'correo', '')) = public.mi_correo())))
  );
create policy "actas: crear"  on public.actas for insert to authenticated
  with check (public.es_aprobado() and created_by = auth.uid());
create policy "actas: editar" on public.actas for update to authenticated using (public.es_admin()) with check (public.es_admin());
create policy "actas: borrar" on public.actas for delete to authenticated using (public.es_admin());
