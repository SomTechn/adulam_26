-- ADULAM · 2026-11-12 · YA APLICADA en Supabase (migración: activar_tiempo_real)
-- Publica los cambios de todas las tablas para el tiempo real de la app.
-- Cada usuario solo recibe cambios de filas que su RLS le permite leer.
-- Al crear una tabla nueva, vuelve a ejecutar este archivo para incluirla.
do $$ declare r record; begin
  if not exists (select 1 from pg_publication where pubname='supabase_realtime') then
    create publication supabase_realtime;
  end if;
  for r in select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
           where n.nspname='public' and c.relkind='r'
             and not exists (select 1 from pg_publication_tables p where p.pubname='supabase_realtime' and p.schemaname='public' and p.tablename=c.relname) loop
    execute format('alter publication supabase_realtime add table public.%I', r.relname);
  end loop;
end $$;
