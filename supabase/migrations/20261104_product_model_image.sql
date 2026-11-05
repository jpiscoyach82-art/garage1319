alter table public.productos
  add column if not exists imagen_modelo text;

comment on column public.productos.imagen_modelo is
  'Fotografía verificada del vehículo fuera del empaque, preferentemente sobre fondo blanco.';
