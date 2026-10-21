=== MÓDULO 0: CONTEXTO Y REGLAS GENERALES ===

Continúas trabajando en el proyecto "Planteapp" (punto de venta e inventario para un vivero). Esta es una tercera ronda de correcciones. Hay DOS cambios pendientes que no se implementaron antes. Explora el código actual antes de modificar y no reestructures el proyecto.

Referencia de diseño (Figma, página "Prototipo v2"): Capturas anexadas.
Pantallas de referencia:
- Modal de ajuste con umbral de stock crítico: "Existencia" (node-id=225-324)
- Ticket en curso, estado inicial: node-id=227-745
- Ticket en curso, con monto recibido y cambio: node-id=227-928
- Modal de venta exitosa: "venta" (node-id=226-642)
Ignora la página "Page 1".

REGLA CRÍTICA SOBRE DATOS
Todos los números, montos, nombres de productos, cantidades, horas y porcentajes del Figma son solo ejemplos. No los copies ni los dejes fijos. Usa siempre los datos reales de la app (por ejemplo, el IVA debe salir de la configuración financiera, no del "16%" que aparece en el diseño).

ALCANCE
Solo los dos cambios de abajo. No modifiques la lógica de negocio existente (registro de ventas, inventario, historial) más allá de lo que se indica. Respeta los tokens de color y el tema claro/oscuro ya implementados.


=== MÓDULO 1: UMBRAL DE STOCK CRÍTICO POR PRODUCTO ===

Contexto: en Inventario, al tocar "Añadir" en la tarjeta de un producto se abre el modal de ajuste manual de existencias. Hoy solo permite cambiar la cantidad. Debe permitir también definir a partir de cuántas unidades ese producto se considera en stock crítico.

Diseño del modal (seguir "Existencia" del Figma):
- Etiqueta pequeña superior en verde: "Ajuste Manual". Debajo, el nombre del producto seleccionado en grande. Botón de cerrar (X) arriba a la derecha.
- Bloque de cantidad: botones "−" y "+", la cantidad actual al centro y debajo el texto "unidades en inventario".
- NUEVO bloque "Umbral de Stock Crítico": tarjeta con un ícono de advertencia en amarillo, el título "Umbral de Stock Crítico", el subtítulo "Alertar cuando queden existencias" y, a la derecha, un selector numérico compacto con "−", el valor y "+".
- Botón principal "Confirmar Existencias" (verde primario, con ícono de check) que guarda ambos valores.

Comportamiento:
- El umbral es POR PRODUCTO. Al abrir el modal se muestra el valor actual del producto seleccionado. Si el producto aún no tiene uno propio, usa el valor por defecto que la app ya utilice para marcar stock crítico y no inventes otro.
- El valor mínimo es 0 y debe ser un número entero. No permitas valores negativos ni vacíos.
- Al confirmar, se guardan la cantidad y el umbral del producto, y se cierra el modal.
- El umbral por producto debe ser el que determine: la etiqueta "Stock Bajo" / "Óptimo" de las tarjetas, el contador "Stock crítico" del resumen de Inventario, el contador y la alerta de stock bajo en Inicio, y las notificaciones/alertas de stock. Revisa dónde se calcula hoy el stock crítico y sustituye cualquier umbral fijo global por el del producto.
- No rompas los productos existentes: los que no tengan umbral guardado siguen funcionando con el valor por defecto.
- Verifica que el modal funcione en modo claro y oscuro, y que ningún texto se desborde (el subtítulo puede ocupar dos líneas).


=== MÓDULO 2: VENTA SOLO EN EFECTIVO ===

Este negocio solo cobra en efectivo. Elimina cualquier opción de tarjeta.
- Quita el selector "Efectivo / Tarjeta" de la pantalla del ticket, y cualquier lógica, estado o texto que dependa de elegir el método de pago.
- Toda venta se registra como pago en efectivo. Mantén el dato de método de pago en las ventas guardadas (con el valor efectivo) para no romper el Historial de Ventas, que muestra el método de pago.
- No toques la configuración financiera (IVA y tipos de cambio).


=== MÓDULO 3: FLUJO DE COBRO DEL TICKET (3 ETAPAS) ===

Reemplaza el flujo actual (botón "Completar Cobro" y línea "Total a cobrar") por el flujo del Prototipo v2.

Estructura de la pantalla (como el Figma):
- Encabezado: flecha de regreso, ícono, "Ticket en Curso" y debajo el turno/caja con los datos reales de la app (sin que el texto se parta en dos líneas).
- Fila "Artículos" con el contador de unidades y a la derecha el botón "Añadir ítem". Corrige el desborde actual: el botón se sale por el borde derecho (aparece la franja de OVERFLOWED). Debe caber completo en pantallas de ~360 px.
- Cada artículo en una tarjeta: imagen, nombre, nota de cuidado y precio arriba, y debajo una fila "Cantidad" con el selector "−" / valor / "+". Así los nombres ya no se cortan.
- Panel inferior con: "Subtotal", "IVA" con su porcentaje real, el campo "$ Monto recibido" y el botón "Procesar Cobro de [total]". Quita la línea separada "Total a cobrar": el total ahora va en el texto del botón.

Etapa 1 (inicial):
- El campo "Monto recibido" está vacío (muestra su texto de ayuda) y el botón "Procesar Cobro de [total]" aparece deshabilitado (gris).

Etapa 2 (monto capturado):
- Al escribir un monto, el botón se habilita (verde primario) solo cuando el monto es mayor o igual al total. Si es menor, el botón sigue deshabilitado y no aparece el cambio.
- Cuando el monto alcanza el total, aparece entre el campo y el botón una franja amarilla/ámbar "Cambio a entregar" con un ícono de "$" a la izquierda y el cambio calculado alineado a la derecha.
- Si cambian los artículos o las cantidades, recalcula el total, el cambio y el estado del botón al instante.

Etapa 3 (venta exitosa):
- Al tocar "Procesar Cobro de [total]" se registra la venta con la lógica que ya existe y se muestra un modal centrado sobre la pantalla oscurecida:
  • Ícono de check verde y el título "¡Venta Exitosa!".
  • Texto: "El ticket ha sido procesado con pago en efectivo."
  • "Monto recibido: [monto]".
  • "Cambio a devolver: [cambio]" en el color amarillo/ámbar de acento.
  • Dos botones: "Cerrar" (texto simple) e "Imprimir" (verde primario, con ícono de impresora).
- "Cerrar" cierra el modal, limpia el ticket y regresa a Ventas. "Imprimir" usa la función de impresión que ya exista; si no existe ninguna, deja el botón visible sin acción y avísame en la entrega.
- El modal y las tres etapas deben verse bien en modo claro y oscuro usando los tokens del tema.


=== MÓDULO 4: ENTREGA ===

Al terminar entrégame:
- Lista de archivos modificados.
- Dónde se calcula ahora el stock crítico y cómo quedó el umbral por producto (modelo/campo donde se guarda).
- Qué lógica o estado del método de pago eliminaste.
- Si faltó algo por la falta de una función existente (por ejemplo, impresión).
- Cualquier diferencia entre el diseño y lo implementado.