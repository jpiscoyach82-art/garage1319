create or replace function public.sincronizar_estado_producto()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.stock := greatest(coalesce(new.stock, 0), 0);

  if new.stock = 0 then
    new.estado := 'vendido';
    new.visible := true;
  elsif lower(coalesce(new.estado, '')) = 'vendido' then
    new.estado := 'disponible';
    new.visible := true;
  end if;

  new.actualizado_en := now();
  return new;
end;
$$;

drop trigger if exists trg_sincronizar_estado_producto on public.productos;

create trigger trg_sincronizar_estado_producto
before insert or update of stock on public.productos
for each row
execute function public.sincronizar_estado_producto();

update public.productos
set estado = 'vendido', visible = true
where stock <= 0
  and (estado is distinct from 'vendido' or visible is distinct from true);

update public.productos
set estado = 'disponible', visible = true
where stock > 0
  and lower(coalesce(estado, '')) = 'vendido';
