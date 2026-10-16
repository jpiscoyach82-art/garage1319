alter table public.productos
  add column if not exists marca text not null default 'Hot Wheels';

comment on column public.productos.marca is
  'Marca comercial del coleccionable, por ejemplo Hot Wheels, Matchbox o Jada.';

update public.productos
set marca = 'Jada'
where upper(codigo) like 'JADA-%'
   or lower(coalesce(nombre, '') || ' ' || coalesce(descripcion, '')) like '%jada toys%';

update public.productos
set marca = 'Matchbox'
where upper(codigo) = 'JBN91-4B10';
