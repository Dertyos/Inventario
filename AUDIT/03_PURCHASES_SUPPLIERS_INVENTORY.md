# Auditoría: Compras + Proveedores + Inventario + Productos + Lotes
Fecha: 2026-03-28

---

## 🔴 CRÍTICO — Cancel de compra no revierte stock

**Archivo**: `backend/src/purchases/purchases.service.ts:174-183`
**Descripción**: El método `cancel()` NO revierte el stock cuando se cancela una compra ya en estado `RECEIVED`. El stock fue sumado al recibir, pero cancelar no lo resta.
**Impacto**: Stock irreal. Se puede vender inventario que en realidad no existe porque la compra fue cancelada. Reportes de inventario incorrectos.
**Recomendación**: En `cancel()`, si `purchase.status === RECEIVED`, restar el stock de cada item:
```typescript
if (purchase.status === PurchaseStatus.RECEIVED) {
  for (const item of purchase.items) {
    await manager.decrement(Product, { id: item.productId }, 'stock', item.quantity);
  }
}
```
Usar transacción y crear `InventoryMovement` de tipo `RETURN` para trazabilidad.

---

## 🔴 CRÍTICO — SKU duplicado permitido en UPDATE de producto

**Archivo**: `backend/src/products/products.service.ts:101-109`
**Descripción**: El método `update()` permite cambiar el SKU a uno ya existente en el team. La constraint `UNIQUE(teamId, sku)` en DB lanzará un error de DB genérico en lugar de un error de aplicación claro.
**Impacto**: Error 500 genérico al usuario. Posible duplicidad de SKU si la constraint falla o no existe.
**Recomendación**: Antes de guardar:
```typescript
if (dto.sku && dto.sku !== product.sku) {
  const dup = await repo.findOne({ where: { teamId, sku: dto.sku } });
  if (dup) throw new ConflictException('SKU ya existe en este equipo');
}
```

---

## 🔴 CRÍTICO — Lotes sin validación de pertenencia al producto/team

**Archivo**: `backend/src/lots/lots.service.ts:25-33`
**Descripción**: `create()` no valida que:
1. El producto exista en el team
2. El producto tenga `trackLots === true`
3. `sum(lot.quantity)` ≤ `product.stock`
**Impacto**: Se pueden crear lotes para productos inexistentes o de otro team. Stock de lotes y stock de producto quedan desincronizados.
**Recomendación**: Agregar las 3 validaciones antes de crear el lote. Ver recomendación detallada en resultado del agente.

---

## 🟠 ALTO — Recepciones parciales de compra no soportadas

**Archivo**: `backend/src/purchases/purchases.service.ts:109-172`
**Descripción**: `receive()` asume que toda la cantidad ordenada se recibe de una sola vez. No hay control de recepciones parciales ni registro de discrepancias (ordenó 100, recibió 80).
**Impacto**: No se puede registrar realidad operativa. Inventario puede ser incorrecto si hay entregas parciales.
**Recomendación**: Implementar endpoint `/purchases/:id/receive-item/:itemId?quantity=X` para recepciones por ítem con validación de cantidad.

---

## 🟠 ALTO — Costo de producto sobrescrito con último costo (no costo promedio)

**Archivo**: `backend/src/purchases/purchases.service.ts:140-143`
**Descripción**:
```typescript
product.cost = Number(item.unitCost); // línea 142
```
Al recibir una compra, el costo del producto se reemplaza con el costo de la última compra. No hay costo promedio ponderado ni FIFO.
**Impacto**: Cálculo de margen de ganancia incorrecto en reportes. Si el último precio fue una oferta, todos los reportes quedan con ese precio.
**Recomendación**: Costo promedio ponderado:
```typescript
const newCost = ((product.stock * product.cost) + (item.quantity * item.unitCost))
               / (product.stock + item.quantity);
product.cost = Math.round(newCost * 100) / 100;
```

---

## 🟠 ALTO — Ajuste manual de stock sin permisos por tipo de movimiento

**Archivo**: `backend/src/inventory/inventory.service.ts:21-82`
**Descripción**: `MovementType.ADJUSTMENT` permite cambiar stock a cualquier valor sin permisos específicos por tipo ni aprobador para cambios grandes. No hay límites ni alertas para ajustes anómalos.
**Impacto**: Posible fraude interno. Un empleado puede ajustar stock a conveniencia.
**Recomendación**: Requerir permiso `inventory.adjustment` separado de `inventory.move`. Para ajustes > 20% del stock, requerir aprobación de ADMIN. Loguear con detalle quién hizo el ajuste.

---

## 🟠 ALTO — Mobile: crear compra sin validar que productos existen

**Archivo**: `mobile/lib/features/purchases/presentation/screens/create_purchase_screen.dart:301-372`
**Descripción**: `_submit()` no valida que los productos del carrito sigan existiendo (pueden haber sido eliminados). El error del servidor se muestra genérico.
**Impacto**: UX pobre. Usuario no sabe qué producto causó el error.
**Recomendación**: Validar `unitCost > 0` en UI. Mostrar mensaje específico si el servidor rechaza un producto.

---

## 🟠 ALTO — Mobile: InventoryScreen permite OUT sin validar stock suficiente

**Archivo**: `mobile/lib/features/inventory/presentation/screens/inventory_screen.dart:332-395`
**Descripción**: El diálogo de movimiento tipo `out` no verifica que `qty <= product.stock` antes de enviar. El servidor rechaza pero la UI muestra error genérico.
**Impacto**: UX confusa. Usuario no entiende por qué falla.
**Recomendación**:
```dart
if (type == 'out' && qty > product.stock) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Stock insuficiente. Disponible: ${product.stock}'))
  );
  return;
}
```

---

## 🟠 ALTO — Mobile: productos sin indicador visual de stock bajo en lista

**Archivo**: `mobile/lib/features/products/presentation/screens/products_screen.dart:165-209`
**Descripción**: El badge de stock bajo existe pero no muestra el mínimo configurado. Usuario ve "stock bajo" sin contexto.
**Impacto**: Alertas de stock bajo se ignoran fácilmente.
**Recomendación**: Mostrar `"⚠️ Stock: X / mín: Y"` en lugar de solo un badge de color.

---

## 🟡 MEDIO — receivedAt no actualiza en re-recepciones

**Archivo**: `backend/src/purchases/entities/purchase.entity.ts:67-68`
**Descripción**: `receivedAt` es solo fecha (sin hora). Si se cancela y re-recibe, queda con la primera fecha.
**Impacto**: Reportes de fecha de recepción incorrectos.
**Recomendación**: Cambiar a `DATETIME` y actualizar en cada recepción.

---

## 🟡 MEDIO — Productos sin categoría generan inconsistencia en reportes

**Archivo**: `backend/src/products/entities/product.entity.ts:60-64`
**Descripción**: `categoryId` es nullable. Reportes por categoría quedan incompletos con productos "sin categoría" no agrupados.
**Impacto**: Reportes por categoría incorrectos.
**Recomendación**: Crear categoría "Sin categoría" por defecto en cada team, o hacer `categoryId` requerido.

---

## 🟡 MEDIO — getExpiringLots no distingue "sin fecha" vs "no perecedero"

**Archivo**: `backend/src/lots/lots.service.ts:114-134`
**Descripción**: Lotes sin `expirationDate` se excluyen del cálculo de vencimiento. No hay forma de saber si un lote no tiene fecha porque es "no perecedero" o porque nadie la registró.
**Impacto**: Lotes con fecha pendiente de captura se ignoran silenciosamente.
**Recomendación**: Agregar campo `isPerishable: boolean` en el producto. Si `isPerishable = true` y el lote no tiene fecha, mostrar warning.

---

## 🟡 MEDIO — Mobile: LotsScreen sin validación de consistencia stock ↔ lotes

**Archivo**: `mobile/lib/features/lots/presentation/screens/lots_screen.dart:98-134`
**Descripción**: La pantalla muestra lotes sin verificar que `sum(lot.quantity)` === `product.stock`. Si hay inconsistencia, el usuario no lo sabrá.
**Impacto**: Usuario confundido al ver totales diferentes.
**Recomendación**: Mostrar banner si `totalLots ≠ productStock`.

---

## 🟡 MEDIO — Mobile: PurchasesScreen usa timezone local para agrupar fechas

**Archivo**: `mobile/lib/features/purchases/presentation/screens/purchases_screen.dart:39-44`
**Descripción**: `dateFormat.format(purchase.createdAt)` usa timezone del dispositivo. Si el usuario viaja, la agrupación por fecha cambia.
**Impacto**: Compras del "mismo día" agrupadas en días distintos según ubicación.
**Recomendación**: Usar `purchase.createdAt.toLocal()` de forma consistente, o usar UTC en todos los reportes.

---

## 🟢 BAJO — Supplier NIT nullable con constraint UNIQUE

**Archivo**: `backend/src/suppliers/entities/supplier.entity.ts:29-30`
**Descripción**: `nit` es nullable con `@Unique(['teamId', 'nit'])`. En PostgreSQL múltiples NULL no violan UNIQUE — comportamiento correcto pero no documentado.
**Recomendación**: Agregar comentario en el código explicando este comportamiento intencional.

---

## Resumen

| Severidad | Cantidad |
|-----------|----------|
| 🔴 CRÍTICO | 3 |
| 🟠 ALTO | 7 |
| 🟡 MEDIO | 5 |
| 🟢 BAJO | 1 |
| **TOTAL** | **16** |

**Top 3:**
1. Cancel de compra no revierte stock — inventario irreal
2. SKU duplicado sin validación en update — error genérico 500
3. Lotes sin validación de team/producto — desincronización
