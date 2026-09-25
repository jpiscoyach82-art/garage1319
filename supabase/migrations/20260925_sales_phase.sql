-- Garage 1319 · fase de ventas
-- Pedidos, reservas, métricas comerciales y permisos administrativos.

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  creado_en timestamptz not null default now()
);

alter table public.admin_users enable row level security;

-- El proyecto tenía un único usuario autenticado antes de incorporar roles.
-- Los futuros usuarios no obtienen acceso administrativo automáticamente.
insert into public.admin_users(user_id)
select id from auth.users
on conflict (user_id) do nothing;

create or replace function public.is_garage_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_garage_admin() from public, anon;
grant execute on function public.is_garage_admin() to authenticated;

drop policy if exists "admin users self read" on public.admin_users;
create policy "admin users self read"
on public.admin_users for select to authenticated
using (user_id = (select auth.uid()));

-- Sustituye políticas históricas que daban acceso a cualquier usuario autenticado.
do $$
declare
  table_name text;
  policy_name text;
begin
  foreach table_name in array array[
    'productos','configuracion','promociones','clientes','pedidos',
    'pedido_items','reservas','historial'
  ] loop
    for policy_name in
      select policyname from pg_policies
      where schemaname = 'public'
        and tablename = table_name
        and cmd = 'ALL'
        and roles = array['authenticated']::name[]
    loop
      execute format('drop policy if exists %I on public.%I', policy_name, table_name);
    end loop;
    execute format(
      'create policy %I on public.%I for all to authenticated using ((select public.is_garage_admin())) with check ((select public.is_garage_admin()))',
      'Garage admin gestiona ' || table_name,
      table_name
    );
  end loop;
end;
$$;

drop policy if exists "Administración consulta analítica" on public.eventos_analitica;
create policy "Garage admin consulta analítica"
on public.eventos_analitica for select to authenticated
using ((select public.is_garage_admin()));

alter table public.reservas
  add column if not exists codigo text,
  add column if not exists cantidad integer not null default 1,
  add column if not exists email text,
  add column if not exists precio_unitario numeric(12,2),
  add column if not exists actualizado_en timestamptz not null default now(),
  add column if not exists confirmado_en timestamptz,
  add column if not exists cerrado_en timestamptz;

update public.reservas r
set codigo = coalesce(r.codigo, 'R1319-' || lpad(r.id::text, 8, '0')),
    cantidad = greatest(coalesce(r.cantidad, 1), 1),
    precio_unitario = coalesce(r.precio_unitario, p.precio_promocional, p.precio),
    vence_en = coalesce(r.vence_en, r.creado_en + interval '24 hours'),
    actualizado_en = coalesce(r.actualizado_en, r.creado_en, now())
from public.productos p
where p.id = r.producto_id;

alter table public.reservas alter column codigo set not null;
alter table public.reservas alter column producto_id set not null;
alter table public.reservas alter column cliente set not null;
alter table public.reservas alter column telefono set not null;
alter table public.reservas alter column estado set not null;
alter table public.reservas alter column vence_en set default (now() + interval '24 hours');

alter table public.reservas drop constraint if exists reservas_codigo_key;
alter table public.reservas add constraint reservas_codigo_key unique (codigo);
alter table public.reservas drop constraint if exists reservas_cantidad_check;
alter table public.reservas add constraint reservas_cantidad_check check (cantidad between 1 and 20);
alter table public.reservas drop constraint if exists reservas_estado_check;
alter table public.reservas add constraint reservas_estado_check
  check (estado in ('pendiente','confirmada','vendida','cancelada','vencida'));

create index if not exists reservas_estado_creado_en_idx
  on public.reservas (estado, creado_en desc);
create index if not exists reservas_activas_vence_en_idx
  on public.reservas (vence_en)
  where estado in ('pendiente','confirmada');
create index if not exists pedidos_estado_creado_en_idx
  on public.pedidos (estado, creado_en desc);
create index if not exists pedidos_vendidos_fecha_idx
  on public.pedidos (vendido_en desc)
  where estado = 'vendido';

create or replace function public.crear_reserva(
  p_producto_id bigint,
  p_cliente jsonb,
  p_cantidad integer default 1,
  p_notas text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_producto public.productos%rowtype;
  v_codigo text;
  v_nombre text := trim(coalesce(p_cliente->>'nombre',''));
  v_telefono text := regexp_replace(coalesce(p_cliente->>'telefono',''),'\D','','g');
  v_email text := trim(coalesce(p_cliente->>'email',''));
  v_precio numeric(12,2);
  v_vence timestamptz := now() + interval '24 hours';
  v_reserva_id bigint;
begin
  if length(v_nombre) < 2 then raise exception 'Nombre inválido'; end if;
  if length(v_telefono) < 9 or length(v_telefono) > 15 then raise exception 'Teléfono inválido'; end if;
  if p_cantidad < 1 or p_cantidad > 20 then raise exception 'Cantidad inválida'; end if;
  if length(coalesce(p_notas,'')) > 500 then raise exception 'Nota demasiado extensa'; end if;

  select * into v_producto
  from public.productos
  where id = p_producto_id and visible = true and stock > 0 and estado <> 'vendido'
  for update;

  if not found then raise exception 'Producto no disponible'; end if;
  if v_producto.stock < p_cantidad then raise exception 'Stock insuficiente'; end if;

  if coalesce((
    select sum(cantidad) from public.reservas
    where producto_id = p_producto_id
      and estado = 'confirmada'
      and vence_en > now()
  ),0) + p_cantidad > v_producto.stock then
    raise exception 'Las unidades disponibles ya están reservadas';
  end if;

  v_precio := coalesce(v_producto.precio_promocional, v_producto.precio);
  v_codigo := 'R1319-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));

  insert into public.reservas(
    codigo, producto_id, cliente, telefono, email, cantidad, precio_unitario,
    estado, notas, vence_en
  ) values (
    v_codigo, p_producto_id, v_nombre, v_telefono, nullif(v_email,''), p_cantidad,
    v_precio, 'pendiente', left(coalesce(p_notas,''),500), v_vence
  ) returning id into v_reserva_id;

  insert into public.historial(accion, detalle)
  values ('Reserva solicitada', v_codigo || ' · ' || v_producto.codigo);

  return jsonb_build_object(
    'reserva_id', v_reserva_id,
    'codigo', v_codigo,
    'vence_en', v_vence,
    'precio_unitario', v_precio
  );
end;
$$;

revoke all on function public.crear_reserva(bigint,jsonb,integer,text) from public;
grant execute on function public.crear_reserva(bigint,jsonb,integer,text) to anon, authenticated;

create or replace function public.actualizar_reserva(
  p_reserva_id bigint,
  p_estado text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reserva public.reservas%rowtype;
  v_producto public.productos%rowtype;
  v_otras_confirmadas integer;
begin
  if not (select public.is_garage_admin()) then raise exception 'Acceso denegado'; end if;
  if p_estado not in ('confirmada','vendida','cancelada','vencida') then
    raise exception 'Estado de reserva inválido';
  end if;

  select * into v_reserva from public.reservas where id = p_reserva_id for update;
  if not found then raise exception 'Reserva no encontrada'; end if;
  if v_reserva.estado in ('vendida','cancelada','vencida') then
    return jsonb_build_object('ok',true,'estado',v_reserva.estado);
  end if;

  select * into v_producto from public.productos where id = v_reserva.producto_id for update;
  if not found then raise exception 'Producto no encontrado'; end if;

  if p_estado = 'confirmada' then
    if v_reserva.vence_en <= now() then raise exception 'La reserva ya venció'; end if;
    select coalesce(sum(cantidad),0)::integer into v_otras_confirmadas
    from public.reservas
    where producto_id = v_reserva.producto_id
      and estado = 'confirmada'
      and id <> v_reserva.id
      and vence_en > now();
    if v_otras_confirmadas + v_reserva.cantidad > v_producto.stock then
      raise exception 'Stock insuficiente para confirmar la reserva';
    end if;
    update public.reservas set estado='confirmada', confirmado_en=now(), actualizado_en=now()
    where id=v_reserva.id;
    if v_otras_confirmadas + v_reserva.cantidad >= v_producto.stock then
      update public.productos set estado='reservado', actualizado_en=now()
      where id=v_producto.id;
    end if;
  elsif p_estado = 'vendida' then
    if v_reserva.estado <> 'confirmada' then raise exception 'Primero confirma la reserva'; end if;
    if v_producto.stock < v_reserva.cantidad then raise exception 'Stock insuficiente'; end if;
    update public.reservas set estado='vendida', cerrado_en=now(), actualizado_en=now()
    where id=v_reserva.id;
    update public.productos
    set stock = stock - v_reserva.cantidad,
        estado = case when stock - v_reserva.cantidad <= 0 then 'vendido' else 'disponible' end,
        visible = true,
        actualizado_en = now()
    where id=v_producto.id;
  else
    update public.reservas set estado=p_estado, cerrado_en=now(), actualizado_en=now()
    where id=v_reserva.id;
    if v_producto.stock > 0 and v_producto.estado = 'reservado' and not exists (
      select 1 from public.reservas
      where producto_id=v_producto.id and estado='confirmada' and id<>v_reserva.id and vence_en>now()
    ) then
      update public.productos set estado='disponible', actualizado_en=now() where id=v_producto.id;
    end if;
  end if;

  insert into public.historial(accion, detalle)
  values ('Reserva ' || p_estado, v_reserva.codigo);
  return jsonb_build_object('ok',true,'estado',p_estado);
end;
$$;

revoke all on function public.actualizar_reserva(bigint,text) from public, anon;
grant execute on function public.actualizar_reserva(bigint,text) to authenticated;

create or replace function public.expirar_reservas_vencidas()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not (select public.is_garage_admin()) then raise exception 'Acceso denegado'; end if;
  update public.reservas set estado='vencida', cerrado_en=now(), actualizado_en=now()
  where estado in ('pendiente','confirmada') and vence_en <= now();
  get diagnostics v_count = row_count;

  update public.productos p set estado='disponible', actualizado_en=now()
  where p.estado='reservado' and p.stock>0 and not exists (
    select 1 from public.reservas r
    where r.producto_id=p.id and r.estado='confirmada' and r.vence_en>now()
  );
  return v_count;
end;
$$;

revoke all on function public.expirar_reservas_vencidas() from public, anon;
grant execute on function public.expirar_reservas_vencidas() to authenticated;

create or replace function public.confirmar_pedido_venta(p_pedido_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_estado text;
  v_codigo text;
  v_item record;
  v_stock integer;
begin
  if not (select public.is_garage_admin()) then raise exception 'Acceso denegado'; end if;
  select estado,codigo into v_estado,v_codigo from public.pedidos where id=p_pedido_id for update;
  if not found then raise exception 'Pedido no encontrado'; end if;
  if v_estado='vendido' then return jsonb_build_object('ok',true,'estado','vendido'); end if;
  if v_estado='cancelado' then raise exception 'El pedido está cancelado'; end if;

  for v_item in
    select producto_id,cantidad,producto_nombre from public.pedido_items where pedido_id=p_pedido_id
  loop
    if v_item.producto_id is null then raise exception 'Producto eliminado: %',v_item.producto_nombre; end if;
    select stock into v_stock from public.productos where id=v_item.producto_id for update;
    if not found or coalesce(v_stock,0)<v_item.cantidad then
      raise exception 'Stock insuficiente: %',v_item.producto_nombre;
    end if;
    update public.productos
    set stock=stock-v_item.cantidad,
        estado=case when stock-v_item.cantidad<=0 then 'vendido' else 'disponible' end,
        visible=true,
        actualizado_en=now()
    where id=v_item.producto_id;
  end loop;

  update public.pedidos set estado='vendido',vendido_en=now(),actualizado_en=now()
  where id=p_pedido_id;
  insert into public.historial(accion,detalle) values('Venta confirmada',v_codigo);
  return jsonb_build_object('ok',true,'estado','vendido');
end;
$$;

create or replace function public.cancelar_pedido(p_pedido_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_estado text;
  v_codigo text;
begin
  if not (select public.is_garage_admin()) then raise exception 'Acceso denegado'; end if;
  select estado,codigo into v_estado,v_codigo from public.pedidos where id=p_pedido_id for update;
  if not found then raise exception 'Pedido no encontrado'; end if;
  if v_estado='vendido' then raise exception 'Una venta registrada no se cancela desde este flujo'; end if;
  update public.pedidos set estado='cancelado',actualizado_en=now() where id=p_pedido_id;
  insert into public.historial(accion,detalle) values('Pedido cancelado',v_codigo);
  return jsonb_build_object('ok',true,'estado','cancelado');
end;
$$;

revoke all on function public.confirmar_pedido_venta(bigint) from public, anon;
revoke all on function public.cancelar_pedido(bigint) from public, anon;
grant execute on function public.confirmar_pedido_venta(bigint) to authenticated;
grant execute on function public.cancelar_pedido(bigint) to authenticated;

-- Las reservas forman parte del embudo comercial público.
alter table public.eventos_analitica drop constraint if exists eventos_analitica_evento_check;
alter table public.eventos_analitica add constraint eventos_analitica_evento_check check (
  evento in ('visita','detalle_producto','clic_whatsapp','agregar_carrito',
             'compartir_producto','pedido_registrado','reserva_registrada')
);

drop policy if exists "Registrar eventos públicos" on public.eventos_analitica;
create policy "Registrar eventos públicos"
on public.eventos_analitica for insert to anon,authenticated
with check (
  evento in ('visita','detalle_producto','clic_whatsapp','agregar_carrito',
             'compartir_producto','pedido_registrado','reserva_registrada')
  and char_length(sesion_id) between 8 and 120
  and jsonb_typeof(datos)='object'
  and pg_column_size(datos)<=4096
);
