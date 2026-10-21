=== MÓDULO 0: CONTEXTO Y REGLAS GENERALES ===

Continúas trabajando en el proyecto "Planteapp" (punto de venta e inventario para un vivero). Esta es una cuarta ronda de correcciones sobre lo ya implementado. Explora el código actual antes de modificar y no reestructures el proyecto.

Paneles a modificar: Anexados en el chat en forma de captura.

REGLA CRÍTICA SOBRE DATOS
Todos los números, montos, nombres de productos, cantidades, folios y usuarios del Figma y de las capturas son solo ejemplos. No los copies ni los dejes fijos. Usa siempre los datos reales de la app.

ALCANCE
Solo los cambios descritos en los módulos de abajo. No modifiques la lógica de negocio existente (registro de ventas, inventario, historial) más allá de lo indicado. Respeta los tokens de color y el tema claro/oscuro ya implementados. Trabaja módulo por módulo.


=== MÓDULO 1: DESBORDES (OVERFLOW) ===

Siguen apareciendo franjas amarillas/negras de "OVERFLOWED" en varias pantallas. Corrígelas todas ajustando el diseño (espacio flexible, ajuste de línea, scroll cuando haga falta), nunca recortando contenido ni ocultando el aviso.
- Login: la casilla "Recordar datos en este dispositivo" se desborda por la derecha. Debe caber completa, con el texto ajustándose a otra línea si hace falta. El subtítulo "Terminal de Punto de Venta • Iniciar Sesión" se parte en dos líneas alineado a la izquierda: céntralo, como en el Figma (pantalla "Login Terminal").
- Ticket en Curso: el campo "Monto recibido" y la franja "Cambio a entregar" se desbordan cuando el número es largo (ver Módulo 5, que además limita la entrada). Ambos textos deben ajustarse al ancho disponible (por ejemplo reduciendo el tamaño de letra automáticamente o con puntos suspensivos) y nunca salirse de la pantalla.
- Inventario: la lista debe tener un margen inferior suficiente para que el botón flotante "+" no tape los botones "Añadir" y "Borrar" de la última tarjeta al hacer scroll.
- Recorre el resto de pantallas y modales, en claro y oscuro y con un ancho de ~360 px, y corrige cualquier otro desborde que encuentres.


=== MÓDULO 2: FLECHA DE REGRESO EN LOS ENCABEZADOS ===

En el Figma, los encabezados de las pantallas principales tienen una flecha "<" en la esquina superior izquierda, antes del logo de la hojita. Falta en Inicio, Punto de Venta, Inventario y Mi Cuenta (y en las demás pantallas principales que la tengan en el Figma). Historial y Ticket en Curso ya la tienen.
- Agrégala con el mismo estilo del Figma, en claro y oscuro, con un área táctil cómoda y sin desplazar ni romper el resto del encabezado.
- Comportamiento:
  • En Ventas, Inventario y Mi Cuenta: vuelve a la pantalla anterior (donde estaba el usuario antes). Si no hay pantalla anterior, vuelve a Inicio.
  • En Inicio: cierra la sesión y regresa a la pantalla de Login para poder entrar con otra cuenta. Antes de cerrar, muestra un diálogo de confirmación breve ("¿Cerrar sesión?" con botones "Cancelar" y "Salir") para evitar salidas accidentales.
  • El gesto/botón "atrás" del sistema debe comportarse igual que la flecha.
- Si hay un ticket en curso con artículos, no pierdas esos datos al volver a pantallas anteriores (conserva el comportamiento actual).


=== MÓDULO 3: EDITAR EL NOMBRE DE UN PRODUCTO (INVENTARIO) ===

Objetivo: que el cliente pueda corregir un error de ortografía en el nombre de un producto ya agregado.
- En cada tarjeta de producto de Inventario, junto al nombre, agrega un pequeño ícono de lápiz.
- Al tocarlo se abre un diálogo o panel inferior sencillo titulado "Editar nombre" con un campo de texto que muestra el nombre actual, y los botones "Cancelar" y "Guardar".
- Validaciones: quitar espacios sobrantes al inicio y al final; no permitir vacío; límite razonable de longitud (define una constante, por ejemplo 40 caracteres); si ya existe otro producto con el mismo nombre, mostrar un aviso y no guardar.
- Al guardar, el nuevo nombre se actualiza de inmediato en Inventario, Punto de Venta, el catálogo del ticket y los modales. Las ventas ya registradas en el Historial no deben modificarse (conservan el nombre con el que se vendieron).
- Solo se cambia el nombre: no toques precio, existencias ni umbral desde este diálogo.
- Debe verse bien en claro y oscuro y sin desbordes.


=== MÓDULO 4: CAMPOS NUMÉRICOS: SIN LETRAS NI NEGATIVOS (MÓVIL, WEB Y ESCRITORIO) ===

Hoy, en la versión de escritorio/web, los campos numéricos permiten escribir letras y números negativos. Corrige esto para todas las plataformas.
- Aplica a TODOS los campos numéricos de la app: "Monto recibido", precio de venta, cantidad inicial, cantidad en el ajuste manual (si se puede teclear), umbral de stock crítico, IVA/tipo de cambio en Configuración Financiera y cualquier otro que encuentres.
- Debe bloquearse AL ESCRIBIR (no solo al validar al final): solo se aceptan dígitos y, en campos con decimales, un único punto o coma decimal con máximo 2 decimales. No deben poder escribirse letras, signo menos, signo más, ni notación científica (por ejemplo "e").
- Esto también aplica al pegar texto: lo no permitido se descarta.
- En móvil, muestra el teclado numérico adecuado (con decimales o solo enteros según el campo).
- Define los límites máximos como constantes en un solo lugar para poder ajustarlos fácilmente: monto monetario máximo 99,999.99; cantidades de unidades y umbral de stock máximo 9,999 (enteros). Si el usuario intenta pasar del máximo, no se acepta el dígito extra.
- No modifiques el campo de usuario/PIN del Login.


=== MÓDULO 5: TICKET EN CURSO: MONTO RECIBIDO ===

Problema: se puede escribir un monto absurdamente largo (por ejemplo muchos dígitos repetidos) y la app lo acepta, y se desborda la pantalla.
- Aplica las reglas del Módulo 4 al campo "Monto recibido": solo números, máximo dos decimales y el tope monetario definido (99,999.99).
- El cambio a entregar se calcula con ese monto limitado y se muestra con 2 decimales, sin desbordar.
- Mantén el flujo existente: el botón "Procesar Cobro" solo se habilita cuando el monto recibido es mayor o igual al total.


=== MÓDULO 6: PRODUCTO SIN UNIDADES EN VENTAS ===

Problema: al tocar un producto sin unidades disponibles en Punto de Venta, no pasa nada y el usuario no entiende por qué.
- Cuando el usuario intente agregar a la venta un producto con 0 unidades disponibles, no se agrega y se muestra un mensaje claro y breve: "Este producto no tiene unidades disponibles." Usa un aviso emergente (snackbar o diálogo pequeño) en el color de advertencia/error del tema, que se cierre solo en unos segundos o con un botón "Entendido".
- Aplica lo mismo en el "Modal Catálogo de Productos" que se abre con "Añadir ítem" desde el ticket.
- Hazlo visible desde la tarjeta: los productos sin unidades muestran una insignia "Sin unidades" (en color de error del tema) en lugar de la cantidad normal, y se ven un poco atenuados. La tarjeta sigue pudiendo tocarse para mostrar el aviso.
- Si ya existe un límite al aumentar la cantidad de un artículo con el botón "+" del ticket (más unidades que las disponibles), usa el mismo estilo de aviso con el texto "Solo hay [n] unidades disponibles." usando el dato real. Si no existe ese límite, no lo agregues.


=== MÓDULO 7: MODO OSCURO MÁS ATRACTIVO ===

Comentario recibido: los paneles en modo oscuro se sienten planos, muy apagados y poco intuitivos. El cliente pidió que la base sea verde y negro, y eso se mantiene, pero hay que sumar más colores de acento y más jerarquía visual. Este módulo es solo visual y solo del modo oscuro. No cambies el modo claro.

Agrega estos tokens de acento al tema oscuro (además de los que ya existen):
- Verde brillante para elementos activos y positivos: #71B675
- Ámbar (ya existe): #E5B655 → advertencias, "Reponer", cambio a entregar
- Coral: #E8836B → variaciones negativas, errores, "Sin unidades", acciones destructivas
- Turquesa: #4FC3B8 → datos informativos (por ejemplo ticket promedio)

Aplícalos así:
- Inicio: la tarjeta de ventas del día con un degradado sutil de verde oscuro a la superficie de tarjeta y borde fino claro. En la gráfica, la barra seleccionada en verde brillante y las demás en gris oscuro; la etiqueta flotante legible. En las tres métricas, cada número con su color (ventas en verde, ticket promedio en turquesa, stock bajo en ámbar). Tarjeta de alerta de stock con un fondo teñido de ámbar tenue. Los íconos de "Últimas ventas" dentro de círculos con un fondo verde tenue.
- Historial: la tarjeta de resumen con el mismo degradado. Variación positiva en verde y negativa en coral (con su flecha). Pestañas: la activa como una píldora rellena de verde con texto contrastante (hoy solo cambia el color del texto y se lee poco). El chip "Efectivo" con un fondo verde tenue. Los montos de cada venta en verde.
- Punto de Venta: chip de categoría activo relleno en verde; cada tarjeta con borde fino y mayor contraste respecto al fondo; cantidades normales en gris claro, pocas unidades en ámbar, sin unidades en coral.
- Inventario y Mi Cuenta: íconos de cada opción dentro de círculos con fondo tenue del color que corresponda (verde, ámbar, turquesa) en lugar de todos grises.
- Mantén contraste legible (texto claro sobre fondo oscuro) y no uses más de tres colores de acento en una misma pantalla.
- Guarda todos los colores como tokens del tema, sin colores sueltos en los componentes.


=== MÓDULO 8: ÍCONO DE INVENTARIO EN LA BARRA INFERIOR ===

El ícono de Inventario en la barra inferior se ve como un cubo dentro de esquinas de escáner. Eso se parece al escáner QR que ya se eliminó. Reemplázalo por un cubo isométrico simple en contorno (sin esquinas ni marcos).


=== MÓDULO 9: ENTREGA ===

Al terminar entrégame:
- Lista de archivos modificados.
- Dónde quedaron definidas las constantes de límites (montos, unidades, longitud de nombre).
- Qué campos numéricos encontraste y cuáles quedaron filtrados.
- Cualquier diferencia entre el diseño y lo implementado, o algo que no pudiste hacer.