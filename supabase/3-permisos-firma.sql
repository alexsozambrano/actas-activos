-- Actas de Activos: solo el administrador crea, corrige y borra; quien recibe solo firma "conforme"
-- Ejecútalo DESPUÉS de 1-crear-tablas.sql y 2-registro-usuarios.sql (Supabase -> SQL Editor -> New query -> Run)
-- Se puede ejecutar más de una vez sin problema.

-- Correo de la sesión actual (en minúsculas)
create or replace function public.mi_correo() returns text
language sql stable as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''));
$$;

-- Actas: el administrador ve todas; un usuario aprobado ve solo las que van a su correo
drop policy if exists "actas: leer"    on public.actas;
drop policy if exists "actas: crear"   on public.actas;
drop policy if exists "actas: editar"  on public.actas;
drop policy if exists "actas: borrar"  on public.actas;
create policy "actas: leer" on public.actas for select to authenticated
  using (
    public.es_admin()
    or (public.es_aprobado()
        and public.mi_correo() <> ''
        and lower(coalesce(data -> 'recibe' ->> 'correo', '')) = public.mi_correo())
  );
create policy "actas: crear"  on public.actas for insert to authenticated with check (public.es_admin());
create policy "actas: editar" on public.actas for update to authenticated using (public.es_admin()) with check (public.es_admin());
create policy "actas: borrar" on public.actas for delete to authenticated using (public.es_admin());

-- Firma "conforme" de quien recibe: solo agrega su firma, no puede cambiar nada más del acta
create or replace function public.firmar_acta(p_id text, p_firma text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_data   jsonb;
  v_correo text := public.mi_correo();
begin
  if not public.es_aprobado() then
    raise exception 'Tu cuenta no está aprobada.';
  end if;
  select data into v_data from public.actas where id = p_id for update;
  if not found then
    raise exception 'El acta no existe.';
  end if;
  if v_correo = '' or lower(coalesce(v_data -> 'recibe' ->> 'correo', '')) <> v_correo then
    raise exception 'Esta acta no está a tu nombre.';
  end if;
  if coalesce(v_data ->> 'firmaRecibe', '') <> '' then
    raise exception 'Esta acta ya fue firmada.';
  end if;
  if p_firma is null or left(p_firma, 22) <> 'data:image/png;base64,' or length(p_firma) > 400000 then
    raise exception 'La firma no es válida.';
  end if;
  v_data := v_data || jsonb_build_object(
    'firmaRecibe', p_firma,
    'conforme', true,
    'estadoFirma', 'firmada',
    'firmadoRecibeEn', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'firmadoRecibePor', v_correo
  );
  update public.actas set data = v_data where id = p_id;
  return v_data;
end $$;
revoke all on function public.firmar_acta(text, text) from public, anon;
grant execute on function public.firmar_acta(text, text) to authenticated;
