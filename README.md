# Garage 1319 V2

Catálogo móvil de Hot Wheels y diecast con inventario, carrito, pedidos por WhatsApp y administración conectada a Supabase.

## Mejoras de esta versión

- HTML, CSS, JavaScript e imágenes separados.
- Una sola representación del catálogo para cuadrícula y vitrina.
- Carrito y favoritos persistentes.
- Pedido transaccional con precio calculado en el servidor.
- Stock separado al registrar el pedido y restaurado al cancelarlo.
- Panel administrativo independiente en `/admin/`.
- Fichas de coleccionista con galería frontal/posterior, escala, empaque, edición, stock, precio y entrega.
- Tarjetas simplificadas y ventana accesible de “Ver detalles”.
- Precio promocional calculado también en el servidor al registrar el pedido.
- RLS, funciones SQL y bucket de imágenes documentados como migración.
- PWA, SEO, accesibilidad y política de privacidad.

## Puesta en marcha

1. Crear una rama de respaldo de la versión actualmente publicada.
2. Ejecutar `supabase/migrations/20260916_garage1319_v2.sql` en un proyecto de prueba.
3. En una base V2 ya existente, ejecutar `supabase/migrations/20260916_collector_product_details.sql`.
4. Crear o invitar al usuario administrador en Supabase Auth.
5. Insertar su UUID en `public.admin_users` usando la instrucción incluida al final de la migración principal.
6. Revisar `assets/js/config.js` y confirmar URL y llave pública de Supabase.
7. Completar escala, condición, fotografía posterior y entrega desde `/admin/`.
8. Probar catálogo, detalle, pedido, cancelación, confirmación de venta y carga de fotografías.
9. Publicar la rama `main` con GitHub Pages.

## Validación automática

### Actualización de fiabilidad — 15/10/2026

- El catálogo mantiene un skeleton mientras consulta Supabase; el estado vacío solo se muestra después de completar la consulta.
- La consulta del inventario tiene límite de 8 segundos por intento, un reintento automático y recuperación manual mediante “Reintentar carga”. Las consultas auxiliares también tienen límite de tiempo.
- Las fotografías verificadas se sirven desde `assets/images/catalog/`, mediante `assets/js/image-map.js`. No se modifican las URL originales de Supabase: una fotografía cambiada posteriormente no queda oculta por una copia anterior.
- El respaldo se identifica expresamente como tal, con advertencia de confirmar precio y disponibilidad.
- La acción de validación se ejecuta también los lunes y manualmente. `npm run check:images` compara el inventario público actual con las copias para detectar fotografías nuevas sin respaldo local.
- Para copiar fotos nuevas, actualizar `scripts/catalog-images-source.json` desde los campos públicos `id,codigo,nombre,imagen,imagen_posterior` y ejecutar `npm run mirror:images`. Solo se generan entradas para archivos descargados y reconocidos como imágenes; revisar los fallos antes de publicar.
- Las fuentes originales permanecen en el inventario y en el archivo de procedencia; alojar una copia no cambia sus derechos de uso.

```bash
npm test
```

La acción de GitHub incluida ejecuta esta validación en cada cambio y evita publicar HTML con IDs duplicados, eventos inline, imágenes base64, referencias rotas o errores de sintaxis JavaScript.

La llave `publishable/anon` es pública por diseño. Nunca debe colocarse una llave `service_role` en los archivos del sitio.

## Desarrollo local

El proyecto no requiere compilación. Debe abrirse desde un servidor HTTP, no directamente como archivo:

```bash
python3 -m http.server 8080
```

Luego abrir `http://localhost:8080/`.

## Estructura

```text
admin/                 Panel administrativo
assets/css/            Estilos
assets/images/         Imágenes optimizadas
assets/js/             Lógica pública y administrativa
assets/vendor/         Supabase JS fijado en 2.116.0
supabase/migrations/    Esquema, políticas y funciones
```

Las versiones HTML anteriores se conservan como respaldo en el repositorio, pero no intervienen en la página principal.
