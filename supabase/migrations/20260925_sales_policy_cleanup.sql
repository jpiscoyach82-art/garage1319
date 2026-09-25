-- Permisos finales de la fase de ventas.

-- Evita políticas SELECT duplicadas para usuarios autenticados.
drop policy if exists "Catalogo publico visible" on public.productos;
create policy "Catalogo publico visible"
on public.productos for select to anon
using (visible = true);

drop policy if exists "Config publica lectura" on public.configuracion;
create policy "Config publica lectura"
on public.configuracion for select to anon
using (true);

drop policy if exists "Promociones publicas" on public.promociones;
create policy "Promociones publicas"
on public.promociones for select to anon
using (activa = true);

-- Esta función puede respetar RLS porque cada administrador solo consulta su fila.
alter function public.is_garage_admin() security invoker;

-- Las operaciones administrativas respetan las políticas RLS del usuario conectado.
alter function public.actualizar_reserva(bigint,text) security invoker;
alter function public.expirar_reservas_vencidas() security invoker;
alter function public.confirmar_pedido_venta(bigint) security invoker;
alter function public.cancelar_pedido(bigint) security invoker;

-- El bucket real del proyecto es "productos".
drop policy if exists "Garage admin upload fotos" on storage.objects;
drop policy if exists "Garage admin update fotos" on storage.objects;
drop policy if exists "Garage admin delete fotos" on storage.objects;

create policy "Garage admin upload fotos"
on storage.objects for insert to authenticated
with check (bucket_id='productos' and (select public.is_garage_admin()));

create policy "Garage admin update fotos"
on storage.objects for update to authenticated
using (bucket_id='productos' and (select public.is_garage_admin()))
with check (bucket_id='productos' and (select public.is_garage_admin()));

create policy "Garage admin delete fotos"
on storage.objects for delete to authenticated
using (bucket_id='productos' and (select public.is_garage_admin()));
