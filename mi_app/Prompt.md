=== MÓDULO 0: CONTEXTO Y REGLAS GENERALES ===

Eres un desarrollador front-end. Trabajas sobre el proyecto actual: "Planteapp", app de punto de venta e inventario para un vivero. Antes de cambiar nada, explora el repositorio: identifica el stack, las pantallas, los estilos/tema y las rutas. No cambies de tecnología ni reestructures el proyecto.

Referencia de diseño (Figma): Se te anexó en forma de imagenes en el chat

ALCANCE
- Cambios VISUALES en todas las pantallas.
- Solo DOS cambios de estructura: eliminar el escáner QR (Módulo 7) y agregar la pantalla de Historial (Módulo 8).
- La sección de IA solo se deja como espacio visual (Módulo 9).
- Todo lo demás queda fuera de alcance. No agregues funciones nuevas ni modifiques la lógica de negocio existente.

REGLA CRÍTICA SOBRE DATOS
Todos los números, montos, nombres de productos, cantidades, fechas, horas, folios, usuarios y porcentajes que aparecen en el Figma son SOLO EJEMPLOS para ilustrar el diseño. No los copies al código ni los dejes fijos (hardcodeados). Usa siempre los datos reales de la app. Si algún dato aún no existe, deja un valor vacío o un marcador claramente identificado, nunca un número inventado. Los textos fijos de la interfaz (etiquetas, botones, mensajes de estado vacío) sí se copian tal como están en este prompt.

ORDEN DE TRABAJO
Módulo 1 (colores) → Módulos 2 a 6 (pantallas) → Módulo 7 (QR) → Módulo 8 (Historial) → Módulo 9 (IA) → Módulo 10 (entrega).


=== MÓDULO 1: SISTEMA DE DISEÑO (PALETA DE COLORES) ===

Centraliza los colores en variables/tokens del tema. No dejes colores sueltos en los componentes. Reemplaza la paleta anterior (verde bosque + crema + terracota).

Modo claro:
- Fondo de app: #FAF7F2
- Superficie / tarjetas: #FFFFFF
- Superficie secundaria / chips / campos: #EAE5DC y #EFE9E0
- Primario (botones, elemento activo, acentos): #2E8B57
- Verde oscuro (énfasis): #0B1D0F
- Advertencia / stock bajo: #E3A813 (texto sobre ese amarillo: #7B5900)
- Texto principal: #171717
- Texto secundario: #737373
- Destructivo (Borrar): conserva el rojo actual

Modo oscuro:
- Fondo de app: #161616
- Fondo de pantalla: #1A1A1A
- Tarjetas: #242424
- Tarjetas secundarias / campos: #2A2A2A
- Bordes y elementos inactivos: #333333
- Primario: #437046
- Verdes claros para texto/indicadores: #71B675 y #A1D3A0
- Advertencia / stock bajo / botón "Reponer": #E5B655
- Texto principal: #F4F4F4
- Texto secundario: #A0A0A0

"Tema Visual" ya ofrece Claro / Oscuro / Automático (del sistema). Ambos modos deben usar los mismos tokens. Conserva la tipografía actual del proyecto (no agregues fuentes nuevas).


=== MÓDULO 2: PANTALLA INICIO (solo visual) ===

- Aplica la nueva paleta en claro y oscuro.
- Tarjeta principal de ventas del día: agrega un selector visual con las opciones "Hoy", "Semana" y "Mes", y una etiqueta sobre la barra seleccionada de la gráfica que muestre hora, monto y número de ventas. Son elementos visuales: usa los datos que la app ya tenga, sin crear lógica ni consultas nuevas.
- Las 3 métricas (ventas, ticket promedio, stock bajo) van en una franja plana con divisores verticales, sin borde de botón ni sombra, para que se vean como datos de solo lectura.
- Elimina la sección "Accesos Rápidos" por completo.
- Sección "Últimas ventas": si no hay ventas, muestra el título "Aún no hay ventas el día de hoy" y debajo "Cuando registres una venta, aparecerá aquí.".
- El botón "Reponer" de la alerta de stock bajo usa el color de advertencia.


=== MÓDULO 3: PANTALLA INVENTARIO (solo visual) ===

- Nueva paleta en claro y oscuro.
- Buscador en la parte superior, sin botón de escáner y sin los filtros rápidos anteriores.
- Debajo del buscador, las 3 tarjetas de resumen: plantas vivas, stock crítico y lotes/SKUs.
- El botón "Ajustar" cambia su texto a "Añadir". El botón flotante "Nuevo Lote" se muestra como un botón "+" (revisa el diseño).
- La cantidad disponible de cada producto va como texto simple (cantidad + unidad), sin recuadro de color que parezca botón.
- Verifica que el botón flotante no tape el botón "Borrar" de la última tarjeta (añade espacio inferior a la lista).


=== MÓDULO 4: PANTALLA PUNTO DE VENTA (solo visual) ===

- Nueva paleta en claro y oscuro.
- Elimina el botón de escáner junto al buscador (ver Módulo 7).
- Todo lo demás se mantiene igual: filtros por categoría, tarjetas de producto con contador, y el botón "Ver Ticket y Cobrar".


=== MÓDULO 5: PANTALLA MI CUENTA (solo visual) ===

- Misma estructura: secciones "Preferencias" y "Negocio" con sus opciones actuales.
- Solo aplica la nueva paleta y compacta un poco los espaciados para aprovechar mejor el espacio.
- No agregues paneles ni opciones nuevas.


=== MÓDULO 6: RESTO DE PANTALLAS Y MODALES (solo paleta) ===

Aplica únicamente la nueva paleta, en modo claro y oscuro, a: Login, Ticket en curso, Cobro en efectivo, Venta exitosa, Escanear código (se elimina, ver Módulo 7), Catálogo de productos, Agregar lote, Ajuste manual de existencias, Borrar producto, Notificaciones de stock, Alertas de stock, Tema visual, Configuración financiera y Empleados. No cambies su estructura ni su comportamiento.


=== MÓDULO 7: ELIMINAR EL ESCÁNER QR ===

Esta funcionalidad ya no se usará. Elimínala por completo:
- Los botones de escaneo en Inventario y en Punto de Venta.
- La pantalla y la ruta "Escanear Código".
- El código, las dependencias y los permisos que solo existían para eso (cámara, librería de QR, etc.).
- Busca en todo el proyecto referencias huérfanas e imports rotos, y confirma que la app compila y navega sin errores.


=== MÓDULO 8: NUEVA PANTALLA "HISTORIAL DE VENTAS" ===

Sigue el diseño "Historial" del Prototipo v2, recordando la regla crítica sobre datos del Módulo 0: ningún valor del Figma se copia.

Estructura:
- Encabezado con el título "Historial de Ventas" y pestañas de periodo: "Hoy", "Semana Pasada", "Mes Pasado".
- Bloque de resumen del periodo seleccionado, con estos campos calculados a partir de las ventas reales: venta acumulada (con su moneda), variación respecto al periodo anterior, número de pedidos completados y ticket promedio.
- Sección "Detalle de operaciones" con un contador de ventas registradas y una lista de ventas. Cada elemento muestra: nombre del producto, unidades vendidas, monto, método de pago, usuario que registró la venta, hora y folio de la venta.
- Estado vacío cuando el periodo no tenga ventas, con un mensaje claro y breve.
- No agregues notas que prometan sincronización en tiempo real ni cortes de caja si la app no lo hace.
- Fuente de datos: las ventas que la app ya registra. Si no hay forma de consultarlas por periodo, indícalo en la entrega en lugar de inventar datos.
- Agrégala a la navegación. En el diseño aparece junto a las pestañas principales; revisa ahí cómo se llega a ella y mantén la navegación consistente. Si algo no es claro, déjalo accesible desde "Últimas ventas" en Inicio y avísame.


=== MÓDULO 9: SECCIÓN DE IA (SOLO ESPACIO) ===

En Inventario aparece un panel "Sugerencias IA" y un chip con el mismo nombre. Solo déjalos como componente visual (placeholder) con la nueva paleta.
- Sin llamadas a APIs, sin lógica de recomendaciones, sin estado y sin dependencias nuevas.
- Los botones del panel pueden verse, pero no deben ejecutar nada.
- No copies los textos de ejemplo de las sugerencias; usa un texto genérico de marcador.


=== MÓDULO 10: ENTREGA ===

Al terminar, entrégame:
- Lista de archivos modificados, creados y eliminados.
- Dependencias y permisos que quitaste por el QR.
- Cualquier diferencia entre el diseño y lo implementado, y los datos que faltaron para el Historial.