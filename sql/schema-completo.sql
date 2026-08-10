-- ADULAM · SQL Completo — Ejecutar en Supabase SQL Editor
create extension if not exists "uuid-ossp";

-- Profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null, email text unique,
  rol text not null default 'miembro' check (rol in ('pastor','lider','servidor','miembro')),
  iglesia_id uuid, created_at timestamptz not null default now()
);

-- Churches
create table if not exists public.churches (
  id uuid primary key default uuid_generate_v4(), nombre text not null default 'ADULAM',
  direccion text, created_at timestamptz not null default now()
);
insert into public.churches (id, nombre) values ('00000000-0000-0000-0000-000000000001','ADULAM') on conflict do nothing;

-- Families
create table if not exists public.families (
  id uuid primary key default uuid_generate_v4(), nombre_familia text not null,
  iglesia_id uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at timestamptz not null default now()
);

-- Teams
create table if not exists public.teams (
  id uuid primary key default uuid_generate_v4(), nombre text not null, descripcion text, lider_id uuid,
  iglesia_id uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at timestamptz not null default now()
);

-- Members
create table if not exists public.members (
  id uuid primary key default uuid_generate_v4(), nombre text not null, telefono text, direccion text,
  lat numeric(10,7), lng numeric(10,7),
  familia_id uuid references public.families(id) on delete set null,
  ministerio_id uuid references public.teams(id) on delete set null,
  estado_espiritual text not null default 'nuevo' check (estado_espiritual in ('nuevo','discipulado','bautizado','lider','inactivo')),
  foto_url text, fecha_nacimiento date, notas text,
  iglesia_id uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.teams drop constraint if exists teams_lider_fk,
  add constraint teams_lider_fk foreign key (lider_id) references public.members(id) on delete set null;

create table if not exists public.member_teams (
  member_id uuid references public.members(id) on delete cascade,
  team_id uuid references public.teams(id) on delete cascade,
  primary key (member_id, team_id)
);

-- Houses
create table if not exists public.houses (
  id uuid primary key default uuid_generate_v4(), nombre text not null,
  anfitrion_id uuid references public.members(id) on delete set null,
  direccion text, dia_reunion text, hora text, descripcion text,
  iglesia_id uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at timestamptz not null default now()
);
create table if not exists public.member_houses (
  member_id uuid references public.members(id) on delete cascade,
  house_id uuid references public.houses(id) on delete cascade,
  primary key (member_id, house_id)
);

-- Meeting Types
create table if not exists public.meeting_types (
  id uuid primary key default uuid_generate_v4(), codigo text unique not null, nombre text not null,
  icono text default '⛪', activo boolean default true, orden int default 0,
  iglesia_id uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at timestamptz not null default now()
);
insert into public.meeting_types (codigo,nombre,icono,orden) values
  ('domingo','Culto Dominical','⛪',1),('lunes','Reunión Lunes','📖',2),
  ('miercoles','Reunión Miércoles','🙏',3),('viernes','Reunión Viernes','✨',4),
  ('vigilia','Vigilia','🌙',5),('ayuno','Ayuno','🕊️',6),('especial','Evento Especial','🎉',7)
on conflict (codigo) do nothing;

-- Attendance
create table if not exists public.attendance (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references public.members(id) on delete cascade,
  fecha date not null, tipo_reunion text not null,
  meeting_type_id uuid references public.meeting_types(id) on delete set null,
  asistio boolean not null default false,
  iglesia_id uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at timestamptz not null default now(),
  unique (member_id, fecha, tipo_reunion)
);

-- Discipleship
create table if not exists public.discipleship_courses (
  id uuid primary key default uuid_generate_v4(), nombre text not null, descripcion text,
  orden int default 0, nivel int default 1, color text default 'indigo', icono text default '📖',
  min_asistencia int default 80, nota_minima numeric(4,2) default 70, activo boolean default true,
  iglesia_id uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at timestamptz not null default now()
);
create table if not exists public.discipleship_lessons (
  id uuid primary key default uuid_generate_v4(),
  course_id uuid not null references public.discipleship_courses(id) on delete cascade,
  numero int not null, titulo text not null, descripcion text, contenido text,
  pdf_url text, video_url text, material_extra text,
  created_at timestamptz not null default now(), unique (course_id, numero)
);
create table if not exists public.discipleship_cohorts (
  id uuid primary key default uuid_generate_v4(),
  course_id uuid not null references public.discipleship_courses(id) on delete cascade,
  nombre text not null, fecha_inicio date, fecha_fin date,
  maestro_id uuid references public.members(id) on delete set null,
  estado text default 'activo' check (estado in ('activo','finalizado','cancelado')),
  notas text, iglesia_id uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at timestamptz not null default now()
);
create table if not exists public.discipleship_participants (
  id uuid primary key default uuid_generate_v4(),
  cohort_id uuid not null references public.discipleship_cohorts(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  nota_final numeric(4,2), aprobado boolean, diploma_generado boolean default false,
  observaciones text, created_at timestamptz not null default now(),
  unique (cohort_id, member_id)
);
create table if not exists public.discipleship_attendance (
  id uuid primary key default uuid_generate_v4(),
  cohort_id uuid not null references public.discipleship_cohorts(id) on delete cascade,
  lesson_id uuid not null references public.discipleship_lessons(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  asistio boolean not null default false, fecha date, nota_leccion numeric(4,2),
  created_at timestamptz not null default now(),
  unique (cohort_id, lesson_id, member_id)
);

-- Treasury
create table if not exists public.treasury (
  id uuid primary key default uuid_generate_v4(),
  tipo text not null check (tipo in ('ingreso','egreso')), categoria text not null,
  monto numeric(12,2) not null check (monto >= 0), descripcion text,
  fecha date not null default current_date,
  registrado_por uuid references public.profiles(id) on delete set null,
  iglesia_id uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at timestamptz not null default now()
);

-- Service Plans
create table if not exists public.service_plans (
  id uuid primary key default uuid_generate_v4(), fecha date not null, tipo_reunion text not null,
  meeting_type_id uuid references public.meeting_types(id) on delete set null,
  tema text, predicador text,
  iglesia_id uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at timestamptz not null default now()
);
create table if not exists public.service_tasks (
  id uuid primary key default uuid_generate_v4(),
  service_plan_id uuid not null references public.service_plans(id) on delete cascade,
  nombre_tarea text not null, responsable_id uuid references public.members(id) on delete set null,
  estado text not null default 'pendiente' check (estado in ('pendiente','en_proceso','completado')),
  created_at timestamptz not null default now()
);

-- Social Posts
create table if not exists public.social_posts (
  id uuid primary key default uuid_generate_v4(), titulo text not null, descripcion text,
  fecha_programada date, estado text not null default 'pendiente' check (estado in ('pendiente','en_diseno','aprobado','publicado')),
  plataforma text default 'instagram', responsable_id uuid references public.members(id) on delete set null,
  imagen_url text, iglesia_id uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at timestamptz not null default now()
);

-- Automation Logs
create table if not exists public.automation_logs (
  id uuid primary key default uuid_generate_v4(), tipo text not null,
  member_id uuid references public.members(id) on delete cascade,
  mensaje text, enviado boolean default false, created_at timestamptz not null default now()
);

-- Functions
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nombre, email, rol) values (new.id, coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email,'@',1)), new.email, coalesce(new.raw_user_meta_data->>'rol','miembro'));
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.get_my_role() returns text language plpgsql security definer stable set search_path = public as $$
declare v_rol text;
begin
  select rol into v_rol from public.profiles where id = auth.uid() limit 1;
  return coalesce(v_rol, 'miembro');
exception when others then return 'miembro';
end; $$;
grant execute on function public.get_my_role() to authenticated, anon;

create or replace function public.auto_mark_inactive() returns void language plpgsql as $$
declare m record; faltas int;
begin
  for m in select id from public.members where estado_espiritual <> 'inactivo' loop
    select count(*) into faltas from (select asistio from public.attendance where member_id = m.id order by fecha desc limit 3) t where asistio = false;
    if faltas = 3 then
      update public.members set estado_espiritual = 'inactivo' where id = m.id;
      insert into public.automation_logs (tipo, member_id, mensaje) values ('inactividad', m.id, 'Marcado inactivo por 3 faltas');
    end if;
  end loop;
end; $$;

create or replace function public.auto_alert_sin_discipulador() returns void language plpgsql as $$
declare m record;
begin
  for m in select mb.id, mb.nombre from public.members mb left join public.discipleship_participants dp on dp.member_id = mb.id where mb.estado_espiritual in ('nuevo','discipulado') and dp.id is null loop
    insert into public.automation_logs (tipo, member_id, mensaje) values ('sin_discipulador', m.id, m.nombre || ' sin proceso de discipulado');
  end loop;
end; $$;

-- Views
create or replace view public.v_dashboard as
select
  (select count(*) from public.members where estado_espiritual <> 'inactivo') as total_miembros,
  (select count(*) from public.members where estado_espiritual = 'nuevo' and created_at > now() - interval '30 days') as nuevos_miembros,
  (select count(distinct member_id) from public.discipleship_participants p join public.discipleship_cohorts co on co.id = p.cohort_id where co.estado = 'activo') as en_discipulado,
  (select count(*) from public.members where estado_espiritual = 'inactivo') as inactivos,
  (select count(distinct member_id) from public.attendance where asistio = true and fecha > now() - interval '7 days') as asistencia_semanal,
  (select coalesce(sum(case when tipo='ingreso' then monto else -monto end),0) from public.treasury where fecha >= date_trunc('month', current_date)) as balance_mes;

create or replace view public.v_discipleship_progress as
select p.id as participant_id, p.cohort_id, p.member_id, m.nombre as miembro_nombre, c.id as course_id, c.nombre as curso_nombre, c.min_asistencia as curso_min_asistencia, c.nota_minima as curso_nota_minima, co.nombre as cohort_nombre, co.estado as cohort_estado,
  (select count(*) from public.discipleship_lessons l where l.course_id = c.id) as total_lecciones,
  (select count(*) from public.discipleship_attendance da where da.cohort_id = p.cohort_id and da.member_id = p.member_id and da.asistio = true) as asistencias,
  case when (select count(*) from public.discipleship_lessons l where l.course_id = c.id) = 0 then 0
    else round((select count(*) from public.discipleship_attendance da where da.cohort_id = p.cohort_id and da.member_id = p.member_id and da.asistio = true)::numeric * 100 / (select count(*) from public.discipleship_lessons l where l.course_id = c.id), 1) end as porcentaje_asistencia,
  p.nota_final, p.aprobado, p.diploma_generado
from public.discipleship_participants p
join public.members m on m.id = p.member_id
join public.discipleship_cohorts co on co.id = p.cohort_id
join public.discipleship_courses c on c.id = co.course_id;

-- RLS
alter table public.profiles enable row level security;
alter table public.churches enable row level security;
create policy "profiles_select_all" on public.profiles for select to authenticated using (true);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);
create policy "profiles_insert_any" on public.profiles for insert with check (true);
create policy "churches_read" on public.churches for select using (auth.role() = 'authenticated');

do $$ declare t text;
  tablas text[] := array['families','teams','members','member_teams','attendance','service_plans','service_tasks','social_posts','automation_logs','houses','member_houses','meeting_types','discipleship_courses','discipleship_lessons','discipleship_cohorts','discipleship_participants','discipleship_attendance'];
begin foreach t in array tablas loop
  execute format('alter table public.%I enable row level security', t);
  execute format($p$create policy "%1$s_sel" on public.%1$s for select using (auth.role() = 'authenticated')$p$, t);
  execute format($p$create policy "%1$s_ins" on public.%1$s for insert with check (public.get_my_role() in ('pastor','lider','servidor'))$p$, t);
  execute format($p$create policy "%1$s_upd" on public.%1$s for update using (public.get_my_role() in ('pastor','lider','servidor'))$p$, t);
  execute format($p$create policy "%1$s_del" on public.%1$s for delete using (public.get_my_role() in ('pastor','lider'))$p$, t);
end loop; end $$;

alter table public.treasury enable row level security;
create policy "treasury_sel" on public.treasury for select using (public.get_my_role() in ('pastor','lider'));
create policy "treasury_ins" on public.treasury for insert with check (public.get_my_role() = 'pastor');
create policy "treasury_upd" on public.treasury for update using (public.get_my_role() = 'pastor');
create policy "treasury_del" on public.treasury for delete using (public.get_my_role() = 'pastor');

-- Storage
insert into storage.buckets (id, name, public) values ('member-photos','member-photos',true) on conflict (id) do update set public = true;
create policy "photos_read" on storage.objects for select using (bucket_id = 'member-photos');
create policy "photos_upload" on storage.objects for insert to authenticated with check (bucket_id = 'member-photos');
create policy "photos_update" on storage.objects for update to authenticated using (bucket_id = 'member-photos');
create policy "photos_delete" on storage.objects for delete to authenticated using (bucket_id = 'member-photos');

-- Seed Data
insert into public.families (nombre_familia) values ('Familia López'),('Familia García'),('Familia Mendoza') on conflict do nothing;
insert into public.teams (nombre, descripcion) values ('Alabanza','Música y adoración'),('Diaconía','Servicio'),('Intercesión','Oración'),('Jóvenes','Ministerio juvenil'),('Niños','Escuela dominical') on conflict do nothing;
insert into public.houses (nombre, direccion, dia_reunion, hora) values ('Casa de Pan López Norte','Sector López','martes','19:00'),('Casa de Pan Arellano Sur','Col. Arellano','jueves','19:30') on conflict do nothing;
insert into public.discipleship_courses (nombre, descripcion, orden, nivel, color, icono, min_asistencia, nota_minima) values ('Fiesta de Asnas','Charla intensiva para bautismo.',1,1,'amber','🫏',100,70),('Conociendo el León','Fundamentos de la fe.',2,2,'indigo','🦁',80,70),('Subiendo a Galaad','Formación para liderazgo.',3,3,'emerald','⛰️',80,75) on conflict do nothing;
-- FIN
