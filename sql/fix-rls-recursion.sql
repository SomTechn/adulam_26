-- =====================================================================
-- ADULAM · PARCHE CRÍTICO · Arreglar recursión infinita en RLS
-- =====================================================================
-- PROBLEMA: la política de SELECT en profiles llamaba a get_my_role(),
-- y esa función consulta profiles → recursión infinita → la app se cuelga.
--
-- SOLUCIÓN: política simple sin llamar a get_my_role().
-- Ejecutar en Supabase → SQL Editor → New query → Run
-- =====================================================================

-- 1. Eliminar políticas problemáticas de profiles
drop policy if exists "profiles_select" on public.profiles;
drop policy if exists "profiles_update" on public.profiles;
drop policy if exists "profiles_update_self" on public.profiles;
drop policy if exists "profiles_insert" on public.profiles;

-- 2. Políticas simples SIN recursión
-- Cada usuario puede leer su propio perfil (sin llamar a ninguna función)
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

-- Permitir lectura de todos los perfiles a usuarios autenticados
-- (necesario para listar miembros, asignar roles, etc.)
create policy "profiles_select_all" on public.profiles
  for select to authenticated using (true);

-- Cada usuario puede actualizar su propio perfil
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- Permitir insert (necesario para el trigger de nuevo usuario)
create policy "profiles_insert_any" on public.profiles
  for insert with check (true);

-- 3. Hacer get_my_role() a prueba de recursión
-- SECURITY DEFINER + búsqueda directa sin RLS
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
  select rol into v_rol from public.profiles where id = auth.uid() limit 1;
  return coalesce(v_rol, 'miembro');
exception
  when others then
    return 'miembro';
end;
$$;

-- 4. Asegurar permisos de la función
grant execute on function public.get_my_role() to authenticated, anon;

-- 5. Verificación: esta consulta debe responder rápido
-- select public.get_my_role();

-- =====================================================================
-- FIN DEL PARCHE
-- =====================================================================
