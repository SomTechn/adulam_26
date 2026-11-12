-- ADULAM · 2026-11-12 · YA APLICADA en Supabase (migración: seguridad_vistas_roles_revision_movimientos)
-- Se guarda aquí como registro. Es segura de volver a ejecutar.
--
-- 1) Vistas con security_invoker=on: respetan RLS del usuario (antes corrían como
--    dueño y cualquiera con sesión —o sin sesión— podía leer finanzas).
-- 2) v_movimientos expone actividad_id y meta_id (Revisión de movimientos).
-- 3) anon no puede leer vistas ni ejecutar funciones de datos.
-- 4) El registro ya no permite elegir rol: todo usuario nuevo nace 'miembro'.
-- 5) Índices para filtrar movimientos por fecha y usuario.

alter view public.v_stats_decisiones          set (security_invoker=on);
alter view public.v_stats_decisiones_mes      set (security_invoker=on);
alter view public.v_stats_en_riesgo           set (security_invoker=on);
alter view public.v_stats_ingresos_pastorales set (security_invoker=on);
alter view public.v_plan_servicio             set (security_invoker=on);
alter view public.v_fondo_resumen             set (security_invoker=on);
alter view public.v_actividad_recaudo         set (security_invoker=on);
alter view public.v_dashboard                 set (security_invoker=on);
alter view public.v_discipleship_progress     set (security_invoker=on);
alter view public.v_actividad_resumen         set (security_invoker=on);
alter view public.v_cajas_saldos              set (security_invoker=on);
alter view public.v_stats_finanzas_mes        set (security_invoker=on);
alter view public.v_stats_finanzas_categoria  set (security_invoker=on);
alter view public.v_stats_casas               set (security_invoker=on);

create or replace view public.v_movimientos with (security_invoker=on) as
 SELECT t.id, t.caja_id, c.nombre AS caja_nombre, c.tipo AS caja_tipo, c.ambito AS caja_ambito,
    c.color AS caja_color, c.icono AS caja_icono, t.tipo, t.monto, t.fecha, t.descripcion, t.notas,
    t.referencia, t.metodo, t.comprobante_url, t.categoria, t.categoria_id,
    cat.nombre AS categoria_nombre, cat.icono AS categoria_icono, cat.color AS categoria_color,
    t.registrado_por, p.nombre AS registrado_por_nombre, p.rol AS registrado_por_rol, p.email AS registrado_por_email,
    t.actualizado_por, pa.nombre AS actualizado_por_nombre, t.created_at, t.updated_at, t.transferencia_id,
    (COALESCE(c.saldo_inicial, 0::numeric) + sum(CASE WHEN t.tipo = 'ingreso'::text THEN t.monto ELSE - t.monto END)
       OVER (PARTITION BY t.caja_id ORDER BY t.fecha, t.created_at, t.id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) AS saldo_despues,
    (( SELECT count(*) FROM comprobantes cp WHERE cp.treasury_id = t.id))::integer AS n_comprobantes,
    t.actividad_id, t.meta_id
   FROM treasury t
     JOIN cajas c ON c.id = t.caja_id
     LEFT JOIN caja_categorias cat ON cat.id = t.categoria_id
     LEFT JOIN profiles p ON p.id = t.registrado_por
     LEFT JOIN profiles pa ON pa.id = t.actualizado_por;

do $$ declare r record; begin
  for r in select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='v' loop
    execute format('revoke select on public.%I from anon', r.relname);
  end loop;
  for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public' and p.prokind='f' and p.prorettype <> 'trigger'::regtype
             and p.proname in ('busqueda_global','caja_responsable','comprobante_caja_de_ruta','informe_categorias','informe_rango','informe_rango_cajas',
                               'ip_grupos','ip_por_persona','ip_promedios','member_asistencia','member_asistencia_pct','member_comportamiento_asistencia',
                               'member_ingresos_pastorales','siguiente_recibo','stats_antiguedad','stats_asistencia_dia','stats_asistencia_servicio',
                               'stats_edades','stats_finanzas_mes','stats_ofrenda_asistente','stats_por_dia','stats_por_servicio','auto_alert_sin_discipulador','auto_mark_inactive') loop
    execute format('revoke execute on function %s from anon, public', r.sig);
    execute format('grant execute on function %s to authenticated', r.sig);
  end loop;
end $$;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nombre, email, rol)
  values (new.id, coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email,'@',1)), new.email, 'miembro');
  return new;
end; $$;

drop policy if exists profiles_insert_any on public.profiles;
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles for insert to authenticated
  with check (id = auth.uid() and rol = 'miembro');

create index if not exists idx_treasury_fecha          on public.treasury (fecha desc, created_at desc);
create index if not exists idx_treasury_registrado_por on public.treasury (registrado_por);

notify pgrst, 'reload schema';
