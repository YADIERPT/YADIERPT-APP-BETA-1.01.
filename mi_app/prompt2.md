=== MÓDULO 0: CONTEXTO Y REGLAS GENERALES ===

Continúas trabajando en el proyecto "Planteapp" (punto de venta e inventario para un vivero). Esta es una segunda ronda de correcciones sobre lo ya implementado. Explora el código actual antes de cambiar nada y no reestructures el proyecto.

Referencia de diseño (Figma, página "Prototipo v2"): Son las capturas que te anexé en el chat.

REGLA CRÍTICA SOBRE DATOS
Todos los números, montos, nombres de productos, cantidades, horas, folios y usuarios del Figma y de las capturas son solo ejemplos. No los copies ni los dejes fijos en el código. Usa siempre los datos reales de la app.

ALCANCE
Solo hacer los cambios descritos en los módulos de abajo. No agregues funciones nuevas ni modifiques la lógica de negocio existente (ventas, inventario, cobro). Trabaja módulo por módulo.


=== MÓDULO 1: TEMA CLARO / OSCURO (ERROR) ===

Problema: la app siempre abre en modo oscuro, y para cambiar a modo claro hay que hacerlo pantalla por pantalla.

Comportamiento esperado:
- Existe UNA sola configuración global de tema con tres opciones: Claro, Oscuro y Automático (sigue el sistema). Se aplica a toda la app al instante, sin volver a entrar a cada pantalla.
- La opción elegida se guarda y se carga al abrir la app, antes de mostrar la primera pantalla (sin parpadeo ni cambio de tema al iniciar).
- Valor inicial cuando no hay preferencia guardada: Automático.
- Para lograrlo: busca y elimina cualquier estado de tema local por pantalla, colores escritos directamente en los componentes, o temas que se sobrescriban en pantallas individuales. Todas las pantallas, modales y la barra inferior deben leer sus colores de los tokens del tema global (paleta clara y oscura ya definidas en el proyecto).
- Verifica que, al cambiar el tema en "Tema Visual", cambien al mismo tiempo Inicio, Ventas, Inventario, Mi Cuenta, Historial, el ticket y todos los modales abiertos o por abrir.


=== MÓDULO 2: INVENTARIO Y BOTÓN DE NUEVO PRODUCTO ===

- El botón flotante "+" y cualquier texto, etiqueta de accesibilidad o título que diga "Nuevo Lote" o "Añadir nuevo lote" debe decir "Nuevo producto" / "Añadir nuevo producto". Mantén el ícono "+".
- Color: el botón flotante debe usar el color de acento amarillo/ámbar de la paleta (el mismo del botón flotante del diseño "Inventario" del Prototipo v2), con el ícono "+" en color oscuro. Actualmente está en verde y no es el correcto. Usa los tokens de ambos modos (claro y oscuro).
- Los botones "Añadir" de cada tarjeta deben seguir el diseño: fondo verde primario con texto blanco (hoy se ven en beige/gris). El botón "Borrar" se mantiene rojo.
- Verifica contra el Figma que el buscador y las tres tarjetas de resumen aparezcan en la parte superior de la pantalla. Si faltan, colócalos como en el diseño.
- No cambies el resto del texto de la pantalla.


=== MÓDULO 3: FORMULARIO "NUEVO PRODUCTO" ===

Pantalla actual: "Agregar Nuevo Lote". Cambios:
- Título: "Agregar Nuevo Producto". Botón de guardar: "Guardar Producto" (hoy dice "Guardar Lote").
- Elimina el campo "Precio de Venta ($)". Se queda únicamente el precio de venta, con la etiqueta "Costo ($)".
- Campos finales, en este orden: foto ("Toca para añadir una foto"), "Nombre de la planta / producto", "Costo ($)", "Cantidad inicial", "Notas / cuidados".
- Ordena el formulario en una sola columna, cada campo a ancho completo. Hoy están en dos columnas y las etiquetas aparecen cortadas ("Cost...", "Cantidad I...", "Notas / C..."). Todas las etiquetas deben verse completas.
- Si el campo de precio de venta se guardaba en la base de datos o en el modelo, quítalo del formulario y del guardado, sin romper los datos existentes; avísame en la entrega si había lógica que dependía de él.


=== MÓDULO 4: TICKET EN CURSO (BOTÓN "AÑADIR ÍTEM") ===

Problema: en el encabezado del ticket apareció un botón rojo "Vaciar" que no debería estar. Debe existir el botón "Añadir ítem".
- Quita el botón "Vaciar" del encabezado.
- Agrega, como en el diseño, una fila "Artículos" con un contador de unidades, y a la derecha el botón "Añadir ítem" (relleno verde primario, texto blanco, ícono de carrito con "+").
- Al tocar "Añadir ítem" se abre el "Modal Catálogo de Productos" para seleccionar otro producto y agregarlo al ticket actual (si ya hay un modal de catálogo en el proyecto, reutilízalo; no crees uno nuevo).
- Corrige el desborde del encabezado: el título "Ticket en Curso" se solapa con otros elementos. Sigue el diseño: flecha de regreso, ícono, título y debajo el subtítulo de turno/caja.


=== MÓDULO 5: INICIO (BOTÓN "VER HISTORIAL") ===

- Dentro de la tarjeta de ventas del día (la de la gráfica), agrega un botón de texto "Ver historial" con una flecha ">" en la parte inferior derecha de la tarjeta. Lleva a la pantalla Historial de Ventas, igual que el toque en la gráfica (que debe seguir funcionando). Conserva también el enlace "Ver historial" de la sección "Últimas ventas".
- Corrige el selector "Hoy / Semana / Mes": hoy se desborda por la derecha y el chip "Mes" queda cortado. Los tres chips deben caber dentro de la tarjeta (con espacio flexible o un contenedor que se ajuste), sin salirse.
- En la franja de métricas (ventas, ticket promedio, stock bajo) aparece un botón "Reponer" que no está en el diseño. Las métricas son solo de lectura: quítalo de esa franja. "Reponer" solo debe aparecer en la alerta de stock bajo.


=== MÓDULO 6: HISTORIAL DE VENTAS (DESBORDES) ===

Hay varios desbordes visibles (franjas amarillas/negras con el texto "OVERFLOWED"). Corrígelos sin cambiar la información que se muestra:
- Pestañas de periodo: "Semana Pasada" se parte en dos líneas. Todas las pestañas deben quedar en una línea y repartirse el ancho por igual.
- Chip de variación respecto al periodo anterior y contador de ventas registradas: no deben cortarse; ajusta su tamaño o permite que bajen a otra línea.
- Cada venta en la lista: el monto no puede truncarse (debe verse completo, con sus decimales). El texto del cajero, la hora y el folio no pueden pegarse ni cortarse (hoy se ve "Administrador21:47 hrs"). Ponlos en dos líneas o con separadores claros, y permite que el texto se ajuste.
- Verifica en un ancho de pantalla pequeño (alrededor de 360 px) que no quede ningún desborde.


=== MÓDULO 7: BARRA DE NAVEGACIÓN INFERIOR ===

- El ícono de "Inventario" debe ser un CUBO (cubo isométrico en contorno, como en el Prototipo v2). Hoy se ve una caja de archivo con tapa. Usa el equivalente del cubo en la librería de íconos del proyecto, y no mezcles estilos de ícono.
- Mantén el mismo ícono en estado activo e inactivo (cambia solo el color) y en ambos modos de tema.
- Verifica que los cuatro íconos tengan el mismo tamaño y grosor de línea, y que los textos estén centrados bajo cada uno.


=== MÓDULO 8: ALINEACIÓN Y DESBORDES EN GENERAL ===

Recorre todas las pantallas y modales y corrige:
- Textos o elementos que no estén centrados donde el diseño los centra (títulos de encabezado, botones, mensajes de estado vacío).
- Cualquier aviso de desborde. No lo "escondas" recortando contenido: ajusta el diseño (espacio flexible, ajuste de línea, scroll cuando sea necesario).
- Textos truncados que deberían leerse completos. Por ejemplo, el buscador de Punto de Venta muestra el texto cortado ("Buscar planta, variedad o preci..."); acórtalo a "Buscar planta o variedad..." para que quepa. En las tarjetas de producto, permite dos líneas para el nombre en lugar de cortarlo.
- Márgenes y espaciados consistentes entre pantallas.


=== MÓDULO 9: ENTREGA ===

Al terminar entrégame:
- Lista de archivos modificados.
- Cómo quedó el manejo del tema (dónde se guarda y cómo se carga).
- Si encontraste lógica que dependía del campo "Costo" o del botón "Vaciar".
- Cualquier diferencia entre el diseño y lo implementado.