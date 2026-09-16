-- Garage 1319: endurecimiento de permisos e índices para relaciones frecuentes.
-- No modifica ni elimina filas existentes.

-- Confirmar una venta es una operación administrativa. La función ya valida
-- una sesión autenticada, pero también retiramos el permiso directo a anon.
revoke all on function public.confirmar_pedido_venta(bigint) from public;
revoke all on function public.confirmar_pedido_venta(bigint) from anon;
grant execute on function public.confirmar_pedido_venta(bigint) to authenticated;

-- Índices de cobertura para las claves foráneas señaladas por el asesor.
create index if not exists pedido_items_pedido_id_idx
  on public.pedido_items (pedido_id);

create index if not exists pedido_items_producto_id_idx
  on public.pedido_items (producto_id);

create index if not exists pedidos_cliente_id_idx
  on public.pedidos (cliente_id);

create index if not exists promociones_producto_id_idx
  on public.promociones (producto_id);

create index if not exists reservas_producto_id_idx
  on public.reservas (producto_id);
