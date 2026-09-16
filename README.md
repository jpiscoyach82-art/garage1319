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
