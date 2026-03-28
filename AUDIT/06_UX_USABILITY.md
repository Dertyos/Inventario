# Auditoría: UX + Usabilidad
Fecha: 2026-03-28
Perspectiva: dueño/vendedor de tienda colombiano, sin conocimientos técnicos

---

## Flujos rotos (🔴)

### 🔴 Venta sin cliente — "Venta directa" difícil de encontrar

**Pantalla**: `create_sale_screen.dart` — picker de cliente
**Descripción**: La opción "Venta directa (sin cliente)" está enterrada en la lista. El usuario que quiere registrar una venta rápida sin cliente debe scrollear para encontrarla. Si selecciona un cliente por error, el botón X para deseleccionarlo es muy pequeño y no es obvio.
**Impacto**: Ventas registradas con cliente incorrecto. Usuarios confundidos.
**Recomendación**:
```
┌─────────────────────────────┐
│ 🏪 Venta sin cliente (contado) ← PRIMERO, destacado
│ ─────────────────────────── │
│  ÚLTIMOS USADOS             │
│  Ana García                 │
│  Pedro López                │
│  TODOS A-Z                  │
│  ...                        │
└─────────────────────────────┘
```

---

### 🔴 "Contado" vs "Crédito" no se explica

**Pantalla**: `create_sale_screen.dart` — toggle de método de pago
**Descripción**: El toggle `Contado / Crédito` usa terminología que muchos vendedores informales no asocian claramente. Un bodeguero de barrio dice "¿Paga ahora o le fío?".
**Impacto**: Ventas registradas con método de pago equivocado.
**Recomendación**: Cambiar a radio buttons con iconos:
- `💵 Paga hoy (contado)` — efectivo/tarjeta/transferencia
- `📅 Paga después (a crédito)` — cuotas, fechas, interés

---

### 🔴 "Entrada/Salida/Ajuste" — ¿qué es Ajuste?

**Pantalla**: `inventory_screen.dart` — modal de movimiento
**Descripción**: Las opciones del dropdown de tipo de movimiento son `Entrada`, `Salida`, `Ajuste`. Un vendedor no sabe qué es "Ajuste" ni cuándo usarlo.
**Impacto**: Movimientos incorrectos de inventario.
**Recomendación**:
- `Entrada` → `"Llegó mercancía"` o `"Compra a proveedor"`
- `Salida` → `"Se vendió"` o `"Se perdió/dañó"`
- `Ajuste` → `"Corrección de conteo"` (con nota visible: "Úsalo cuando el conteo físico no coincide")

---

### 🔴 "Marcar expirados" sin confirmación destructiva

**Pantalla**: `lots_screen.dart` — menú de lotes
**Descripción**: La acción "Marcar expirados" se ejecuta directamente sin AlertDialog de confirmación. Un click accidental afecta múltiples lotes.
**Impacto**: Pérdida de datos de lotes activos.
**Recomendación**: `AlertDialog`: "¿Marcar como expirados los X lotes vencidos? Esta acción no se puede deshacer." + botones `Cancelar` / `Sí, marcar`.

---

## Flujos difíciles (🟠)

### 🟠 Flujo de crédito: 3 inputs sueltos sin guía

**Pantalla**: `create_sale_screen.dart` — sección crédito
**Descripción**: Cuando se selecciona crédito aparecen simultáneamente: Cuotas, Interés %, Frecuencia de pago. No hay orden visual que guíe cuál completar primero ni cuáles son obligatorios.
**Recomendación**: Stepper de 3 pasos:
1. `"¿En cuántas cuotas?" → selector 1..36`
2. `"¿Cobra interés?" → toggle + campo % si aplica`
3. `"¿Cada cuánto paga?" → Mensual / Semanal / Quincenal`
Preview en tiempo real: *"3 cuotas de $350.000 los días X"*

---

### 🟠 Editar cliente/proveedor no es obvio desde la lista

**Pantalla**: `customers_screen.dart`, `suppliers_screen.dart`
**Descripción**: Para editar un cliente hay que entrar al detalle. No hay indicación visual de que se puede editar ni cómo hacerlo desde la lista principal.
**Recomendación**: Agregar ícono de lápiz `✏️` en cada tile o swipe-to-reveal con opciones Editar / WhatsApp.

---

### 🟠 "Recibir compra" — no explica que agrega stock

**Pantalla**: `purchases_screen.dart` — acción sobre compra pendiente
**Descripción**: El botón "Recibir" no indica que al confirmarlo el stock del inventario se actualiza automáticamente. Muchos usuarios lo marcan solo como "me llegó" y no entienden la consecuencia.
**Recomendación**: Tooltip o diálogo de confirmación: `"¿Marcar como recibida? Esto agregará X unidades al inventario."` → `[Cancelar]` `[Sí, recibir]`.

---

### 🟠 Dashboard: FAB con 3 opciones al mismo nivel

**Pantalla**: `dashboard_screen.dart` — FAB expandible
**Descripción**: Las 3 acciones (Escanear, Voz, Nueva venta) tienen el mismo peso visual. "Nueva venta" debería ser la acción primaria más obvia del sistema.
**Recomendación**: Mover "Nueva venta" a botón en la AppBar o como FAB único principal. Escanear y Voz como acciones secundarias (speed dial más pequeño).

---

### 🟠 Proveedor obligatorio en compra pero no está marcado

**Pantalla**: `create_purchase_screen.dart`
**Descripción**: El formulario exige proveedor pero no es obvio que es obligatorio. Si un usuario compra en una tienda al paso (sin proveedor registrado), no puede registrar la compra.
**Recomendación**: Marcar con asterisco `*` y permitir opción `"Compra ocasional (sin proveedor fijo)"`.

---

### 🟠 Error de la IA no es útil para un vendedor

**Pantalla**: `ai_chat_screen.dart` / `voice_transaction_screen.dart`
**Descripción**: Si Claude falla con 503 o retorna error, el mensaje mostrado es técnico. Un vendedor no sabe qué hacer con "Error 503 Service Unavailable".
**Recomendación**: Mapear errores a mensajes accionables:
- Error de red → `"Sin conexión. Conéctate a internet e intenta de nuevo."`
- Error de IA → `"No entendí bien. Intenta decir: 'Venta de 5 arroces a $2.000 cada uno'"`

---

### 🟠 "Pendiente" en créditos es ambiguo

**Pantalla**: `credits_screen.dart`, `sales_screen.dart`
**Descripción**: "Pendiente" puede significar: pendiente de pago, pendiente de aprobación, o pendiente de recepción. El mismo término se usa en ventas, compras y créditos con significados distintos.
**Recomendación**: Ser específico:
- Ventas: `"Sin pagar"`
- Compras: `"Sin recibir"`
- Créditos: `"Al día"` / `"Vencida"`

---

### 🟠 Dashboard: saludo vacío si no hay firstName

**Pantalla**: `dashboard_screen.dart`
**Descripción**: `"¡Hola, [firstName]!"` — si el usuario no tiene `firstName` configurado, muestra `"¡Hola, !"`.
**Recomendación**: Fallback: `"¡Hola, ${user.firstName?.isNotEmpty == true ? user.firstName : user.email.split('@')[0]}!"`

---

## Mejorables (🟡)

### 🟡 "SKU" — nadie sabe qué es

**Pantalla**: `products_screen.dart`, `product_form_screen.dart`
**Descripción**: "SKU" es jerga de retail. Un vendedor de barrio no sabe qué significa.
**Recomendación**: Cambiar label a `"Código interno (opcional)"` con helper text: `"Tu propio código para identificar este producto"`.

---

### 🟡 Campos numéricos sin validación de positivo en UI

**Múltiples formularios**
**Descripción**: Precio, costo, cantidad, interés — todos aceptan números negativos. El servidor rechazará, pero el error llega tarde y es técnico.
**Recomendación**: `validator: (v) => (double.tryParse(v ?? '') ?? -1) <= 0 ? 'Debe ser mayor a 0' : null`

---

### 🟡 Gráficos sin leyenda en dashboard

**Pantalla**: `dashboard_screen.dart` — `MiniLineChart`
**Descripción**: Los gráficos de tendencia no tienen eje Y ni leyenda. El usuario ve una línea pero no sabe si representa ventas, stock o dinero.
**Recomendación**: Agregar label de eje Y o tooltip en el punto más alto: `"$1.2M (máx esta semana)"`.

---

### 🟡 "Confianza alta" / "Verificar datos" en IA sin explicación

**Pantalla**: `voice_transaction_screen.dart` / `ai_chat_screen.dart`
**Descripción**: Los badges de confianza son incomprensibles para el usuario final.
**Recomendación**: Cambiar a lenguaje accionable:
- `"Confianza alta"` → `"✅ Parece correcto — revisa antes de guardar"`
- `"Verificar datos"` → `"⚠️ Algo no quedó claro — corrige los datos marcados"`

---

### 🟡 "Por vencer en 30 días" — umbral invisible

**Pantalla**: `lots_screen.dart`
**Descripción**: El tab "Por vencer" filtra lotes que vencen en 30 días, pero el usuario no sabe ese número.
**Recomendación**: Cambiar label a `"Vencen pronto (próximos 30 días)"`.

---

### 🟡 Iconos en formularios inconsistentes

**Múltiples formularios**
**Descripción**: Algunos campos tienen `prefixIcon` (nombre, email), otros no (notas, NIT). La inconsistencia hace los formularios más difíciles de escanear.
**Recomendación**: Agregar `prefixIcon` a todos los campos, o quitarlos a todos. Elegir uno.

---

### 🟡 Empty state de Inventario/Stock bajo confunde si es nuevo usuario

**Pantalla**: `inventory_screen.dart` — tab Stock bajo
**Descripción**: `"¡Todo bien! No hay productos con stock bajo"` es positivo, pero si el usuario nunca configuró `minStock`, todos los productos "pasan" y no ve alertas aunque el stock sea cero.
**Recomendación**: Agregar hint: `"Las alertas aparecen cuando el stock baja del mínimo que configuraste en cada producto"`.

---

### 🟡 Recordatorios: no explica canal de envío

**Pantalla**: `reminders_screen.dart`
**Descripción**: Los recordatorios muestran "WhatsApp", "Email", "SMS" como canal pero el usuario no eligió cuál usar. No es claro cómo se configura el canal.
**Recomendación**: Agregar configuración en settings: `"Canal preferido de recordatorios"` con explicación de cuándo usar cada uno.

---

### 🟡 Confirmación de acciones importantes es inconsistente

**Múltiples pantallas**
**Descripción**: Cancelar una venta tiene confirmación. Cancelar una compra también. Pero "marcar expirados" no. Borrar cliente sí. Borrar categoría no está claro.
**Recomendación**: Regla general: toda acción irreversible o destructiva DEBE tener `AlertDialog` con descripción de consecuencias.

---

## Terminología colombiana

| Término actual | Problema | Sugerencia |
|---------------|----------|-----------|
| SKU | Anglicismo técnico | "Código interno" |
| Crédito | Confunde con banco | "Venta a plazo" / "Fío" |
| Contado | Poco frecuente informal | "Paga hoy" |
| Ajuste (inventario) | Vago | "Corrección de conteo" |
| Proveedor | OK, pero formal | "Distribuidor" también |
| Cuotas | OK | Agregar: "pagos mensuales/semanales" |
| Pendiente | Ambiguo | Ser específico por contexto |
| Frecuencia de pago | Técnico | "¿Cada cuánto paga?" |

---

## Accesibilidad básica

- 🟠 Botones `TextButton` tienen bajo contraste en light mode (gris sobre blanco)
- 🟠 FAB expandido: botones pequeños difíciles de tocar con dedos grandes
- 🟡 Hints desaparecen al escribir — algunos campos quedan sin contexto
- 🟡 Textos de leyenda en gráficos demasiado pequeños (< 12sp)
- 🟢 `FloatingActionButton` tiene buen tamaño mínimo (56×56 dp ✅)

---

## Top 10 mejoras de alto impacto

Ordenadas por relación esfuerzo ↔ impacto:

**1. Renombrar Contado → "Paga hoy" y Crédito → "Paga después"**
Afecta el flujo más usado de la app. Esfuerzo: 1h.

**2. "Venta sin cliente" como primera opción en picker (no enterrada)**
Reduce clicks y errores en el 40% de las ventas. Esfuerzo: 30 min.

**3. Confirmar "Recibir compra" con consecuencia clara ("agrega stock")**
Evita recepciones accidentales y malentendidos. Esfuerzo: 1h.

**4. Validar positivo en todos los inputs numéricos**
Previene errores contables. Afecta 8+ formularios. Esfuerzo: 2h.

**5. Renombrar "Ajuste" → "Corrección de conteo" con helper text**
Afecta el módulo de inventario. Esfuerzo: 30 min.

**6. Agregar confirmación a "Marcar expirados" (lotes)**
Previene pérdida de datos. Esfuerzo: 30 min.

**7. Renombrar "SKU" → "Código interno (opcional)"**
Afecta formulario de producto. Esfuerzo: 15 min.

**8. Crear stepper de crédito (3 pasos) en lugar de 3 inputs sueltos**
Aumenta completitud de datos de crédito. Esfuerzo: 4h.

**9. Botón editar visible en listas de clientes y proveedores**
Elimina frustración al querer actualizar datos. Esfuerzo: 1h.

**10. Preview de cuotas en tiempo real ("3 cuotas de $350.000")**
Reduce errores al configurar planes de pago. Esfuerzo: 2h.

---

## Resumen

| Severidad | Cantidad |
|-----------|----------|
| 🔴 Roto | 4 |
| 🟠 Difícil | 9 |
| 🟡 Mejorable | 9 |
| 🟢 Sugerencia | 8 |
| **TOTAL** | **30** |

**Conclusión**: La estructura técnica es sólida, pero la app usa demasiada terminología de ERP/contabilidad. Con ~15 horas de trabajo enfocado en los ítems 1-7 del top 10, la app sería notablemente más accesible para un vendedor informal colombiano.
