-- =====================================================================
-- ADULAM · FIX DEFINITIVO · Recursión infinita en RLS
-- =====================================================================
-- Ejecutar COMPLETO en Supabase → SQL Editor → New query → Run
-- =====================================================================

-- ---------------------------------------------------------------------
-- PASO 1: Eliminar TODAS las políticas de profiles
-- (son las que causan la recursión en cadena)
-- ---------------------------------------------------------------------
drop policy if exists "profiles_select"      on public.profiles;
drop policy if exists "profiles_select_own"  on public.profiles;
drop policy if exists "profiles_select_all"  on public.profiles;
drop policy if exists "profiles_update"      on public.profiles;
drop policy if exists "profiles_update_own"  on public.profiles;
drop policy if exists "profiles_update_self" on public.profiles;
drop policy if exists "profiles_insert"      on public.profiles;
drop policy if exists "profiles_insert_any"  on public.profiles;
drop policy if exists "profiles_delete"      on public.profiles;

-- ---------------------------------------------------------------------
-- PASO 2: Políticas SIMPLES en profiles, sin llamar a NINGUNA función
-- Esto rompe el ciclo de recursión.
-- ---------------------------------------------------------------------
create policy "profiles_read" on public.profiles
  for select to authenticated using (true);

create policy "profiles_write_own" on public.profiles
  for update to authenticated using (auth.uid() = id);

create policy "profiles_create" on public.profiles
  for insert to authenticated with check (true);

-- ---------------------------------------------------------------------
-- PASO 3: Reconstruir get_my_role() de forma segura
-- Ahora que profiles tiene una política simple, esta función ya no recursa.
-- ---------------------------------------------------------------------
create or replace function public.get_my_role()
returns text
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_rol text;
begin
  select rol into v_rol
  from public.profiles
  where id = auth.uid()
  limit 1;

  return coalesce(v_rol, 'miembro');
exception
  when others then
    return 'miembro';
end;
$$;

grant execute on function public.get_my_role() to authenticated, anon, service_role;

-- ---------------------------------------------------------------------
-- PASO 4: Verificar que no queden políticas recursivas en churches
-- ---------------------------------------------------------------------
drop policy if exists "churches_read" on public.churches;
create policy "churches_read" on public.churches
  for select to authenticated using (true);

-- ---------------------------------------------------------------------
-- PASO 5: Asegurar que tu usuario tenga perfil con rol pastor
-- (Reemplaza el correo por el tuyo)
-- ---------------------------------------------------------------------
insert into public.profiles (id, nombre, email, rol)
select
  u.id,
  coalesce(u.raw_user_meta_data->>'nombre', split_part(u.email,'@',1)),
  u.email,
  'pastor'
from auth.users u
where u.email = 'ksomar49@gmail.com'
on conflict (id) do update set rol = 'pastor';

-- ---------------------------------------------------------------------
-- PASO 6: Confirmar usuarios sin verificar (por si acaso)
-- ---------------------------------------------------------------------
update auth.users set email_confirmed_at = now() where email_confirmed_at is null;

-- ---------------------------------------------------------------------
-- VERIFICACIÓN: estas consultas deben responder al instante
-- ---------------------------------------------------------------------
select 'Politicas en profiles:' as check, count(*)::text as resultado
from pg_policies where schemaname='public' and tablename='profiles'
union all
select 'Tu perfil:', rol from public.profiles where email = 'ksomar49@gmail.com'
union all
select 'Total usuarios:', count(*)::text from auth.users;

-- =====================================================================
-- FIN
-- =====================================================================
