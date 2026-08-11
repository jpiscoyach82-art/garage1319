-- GARAGE 1319 · v32 CLOUD
alter table reservas add column if not exists vence_en timestamptz;
alter table promociones add column if not exists producto_id bigint references productos(id) on delete cascade;
alter table promociones add column if not exists tipo text not null default 'percent';
alter table promociones add column if not exists valor numeric(10,2) not null default 0;
create table if not exists configuracion (clave text primary key, valor text, actualizado_en timestamptz default now());
alter table productos enable row level security;alter table reservas enable row level security;alter table promociones enable row level security;alter table historial enable row level security;alter table configuracion enable row level security;
drop policy if exists "Admin productos cloud" on productos;drop policy if exists "Admin reservas cloud" on reservas;drop policy if exists "Admin promociones cloud" on promociones;drop policy if exists "Admin historial cloud" on historial;drop policy if exists "Config publica lectura" on configuracion;drop policy if exists "Admin config cloud" on configuracion;
create policy "Admin productos cloud" on productos for all to authenticated using (true) with check (true);
create policy "Admin reservas cloud" on reservas for all to authenticated using (true) with check (true);
create policy "Admin promociones cloud" on promociones for all to authenticated using (true) with check (true);
create policy "Admin historial cloud" on historial for all to authenticated using (true) with check (true);
create policy "Config publica lectura" on configuracion for select to anon,authenticated using (true);
create policy "Admin config cloud" on configuracion for all to authenticated using (true) with check (true);
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='productos') then alter publication supabase_realtime add table productos; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='reservas') then alter publication supabase_realtime add table reservas; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='promociones') then alter publication supabase_realtime add table promociones; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='configuracion') then alter publication supabase_realtime add table configuracion; end if;
end $$;
select 'productos' tabla,count(*) registros from productos union all select 'reservas',count(*) from reservas union all select 'promociones',count(*) from promociones union all select 'historial',count(*) from historial;