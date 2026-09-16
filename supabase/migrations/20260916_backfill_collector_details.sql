-- Garage 1319: datos comunes verificados del inventario actual.
-- Solo completa campos vacíos para respetar futuras ediciones del administrador.

update public.productos
set escala='1:64'
where coalesce(escala,'')='';

update public.productos
set condicion_empaque='Sellado'
where coalesce(condicion_empaque,'')='';

update public.productos
set entrega='Coordina entrega o recojo por WhatsApp.'
where coalesce(entrega,'')='';

update public.productos
set caracteristicas=case codigo
  when 'JJH30-N7C6' then array['2026','1:64','Sellado']
  when 'JBL11-4B10' then array['Real Riders','Metal/Metal']
  when 'JBL67-JA10-21A' then array['Real Riders','Forza']
  when 'JCB78-ND511' then array['1:64','Sellado']
  when 'JBL76-JA10-21A' then array['Real Riders','Premium']
  when 'JBM04-4B10' then array['Real Riders','Premium']
  when 'JBK78-4B10' then array['Car Culture','Real Riders']
  when 'JBK74-4B10' then array['Off Road','Real Riders']
  else array['1:64','Sellado']
end
where coalesce(cardinality(caracteristicas),0)=0;
