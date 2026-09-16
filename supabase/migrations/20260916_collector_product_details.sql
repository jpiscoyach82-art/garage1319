-- Garage 1319: ficha completa para coleccionistas.
-- Migración aditiva: no elimina productos, pedidos ni fotografías existentes.

alter table public.productos add column if not exists precio_promocional numeric(12,2);
alter table public.productos add column if not exists imagen_posterior text not null default '';
alter table public.productos add column if not exists escala text not null default '';
alter table public.productos add column if not exists condicion_empaque text not null default '';
alter table public.productos add column if not exists tipo_edicion text not null default '';
alter table public.productos add column if not exists entrega text not null default '';
alter table public.productos add column if not exists caracteristicas text[] not null default '{}';

update public.productos
set tipo_edicion=categoria
where coalesce(tipo_edicion,'')='';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='productos_precio_promocional_valido'
      and conrelid='public.productos'::regclass
  ) then
    alter table public.productos
      add constraint productos_precio_promocional_valido
      check (precio_promocional is null or (precio_promocional >= 0 and precio_promocional < precio));
  end if;
end $$;

create or replace function public.crear_pedido(p_cliente jsonb,p_items jsonb,p_notas text default '')
returns table(codigo text,total numeric,pedido_id bigint)
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_cliente_id bigint; v_pedido_id bigint; v_codigo text; v_total numeric(12,2):=0;
  v_item jsonb; v_producto public.productos%rowtype; v_cantidad integer;
  v_subtotal numeric(12,2); v_precio numeric(12,2);
  v_nombre text:=trim(coalesce(p_cliente->>'nombre',''));
  v_telefono text:=regexp_replace(coalesce(p_cliente->>'telefono',''),'\D','','g');
  v_email text:=trim(coalesce(p_cliente->>'email',''));
  v_direccion text:=trim(coalesce(p_cliente->>'direccion',''));
begin
  if length(v_nombre)<2 then raise exception 'Nombre inválido'; end if;
  if length(v_telefono)<9 or length(v_telefono)>15 then raise exception 'Teléfono inválido'; end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'El pedido no contiene productos'; end if;
  if jsonb_array_length(p_items)>30 then raise exception 'El pedido supera el máximo de productos'; end if;

  insert into public.clientes(nombre,telefono,email,direccion)
  values(v_nombre,v_telefono,v_email,v_direccion)
  on conflict(telefono) do update set nombre=excluded.nombre,email=excluded.email,direccion=excluded.direccion,actualizado_en=now()
  returning id into v_cliente_id;

  v_codigo:='G1319-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
  insert into public.pedidos(codigo,cliente_id,cliente_nombre,telefono,email,direccion,notas,estado,total)
  values(v_codigo,v_cliente_id,v_nombre,v_telefono,v_email,v_direccion,left(coalesce(p_notas,''),500),'pendiente',0)
  returning id into v_pedido_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_cantidad:=greatest(0,coalesce((v_item->>'cantidad')::integer,0));
    if v_cantidad<1 or v_cantidad>20 then raise exception 'Cantidad inválida'; end if;
    select * into v_producto from public.productos
      where id=(v_item->>'producto_id')::bigint and visible=true for update;
    if not found then raise exception 'Producto no disponible'; end if;
    if v_producto.stock<v_cantidad then raise exception 'Stock insuficiente para %',v_producto.nombre; end if;

    v_precio:=coalesce(v_producto.precio_promocional,v_producto.precio);
    select case
      when p.tipo='percent' then greatest(0,round(v_producto.precio*(1-p.valor/100),2))
      else p.valor
    end into v_precio
    from public.promociones p
    where p.producto_id=v_producto.id and p.activa=true and (p.fin is null or p.fin>now())
    order by p.id desc limit 1;
    v_precio:=coalesce(v_precio,v_producto.precio_promocional,v_producto.precio);
    v_subtotal:=v_precio*v_cantidad;
    v_total:=v_total+v_subtotal;

    insert into public.pedido_items(pedido_id,producto_id,producto_nombre,codigo,cantidad,precio_unitario,subtotal)
    values(v_pedido_id,v_producto.id,v_producto.nombre,v_producto.codigo,v_cantidad,v_precio,v_subtotal);
    update public.productos
      set stock=stock-v_cantidad,
          estado=case when stock-v_cantidad<=0 then 'vendido' else 'disponible' end,
          visible=(stock-v_cantidad>0),actualizado_en=now()
      where id=v_producto.id;
  end loop;

  update public.pedidos set total=v_total where id=v_pedido_id;
  insert into public.historial(accion,detalle) values('Pedido creado',v_codigo);
  return query select v_codigo,v_total,v_pedido_id;
end $$;

revoke all on function public.crear_pedido(jsonb,jsonb,text) from public;
grant execute on function public.crear_pedido(jsonb,jsonb,text) to anon,authenticated;

