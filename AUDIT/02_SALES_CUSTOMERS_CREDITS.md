# Auditoría: Ventas + Clientes + Créditos + Pagos
Fecha: 2026-03-28

---

## 🔴 CRÍTICO — CreditAccount creado fuera de la transacción de venta

**Archivo**: `backend/src/sales/sales.service.ts:148-168`
**Descripción**: Cuando `paymentMethod === CREDIT`, la venta se guarda en transacción y se confirma. La creación de `CreditAccount` ocurre DESPUÉS del commit, de forma no transaccional. Si falla la creación del crédito, la venta quedó guardada sin cuenta de crédito asociada.
**Impacto**: Inconsistencia grave — venta registrada como crédito sin cuotas para cobrar. El cliente "debe" dinero sin registro.
**Recomendación**: Mover `creditsService.create()` DENTRO de la transacción, antes del `commitTransaction()`. Si falla, el rollback deshace la venta completa.

---

## 🔴 CRÍTICO — creditPaidAmount sin límite superior en DTO

**Archivo**: `backend/src/sales/dto/create-sale.dto.ts:76-82`
**Descripción**:
```typescript
@IsNumber() @Min(0) @IsOptional()
creditPaidAmount?: number;
```
Sin `@Max(total)`. Se puede enviar `creditPaidAmount: 9999999` en una venta de $100K, generando `creditBalance < 0` (saldo negativo absurdo).
**Impacto**: Créditos en estado inconsistente, reportes de saldo incorrectos.
**Recomendación**: Agregar validador cruzado `creditPaidAmount <= subtotal`, o calcular el pago inicial de crédito en el backend a partir del subtotal.

---

## 🔴 CRÍTICO — Redondeo incorrecto en cálculo de cuotas

**Archivo**: `backend/src/credits/credits.service.ts:210-246`
**Descripción**: `baseAmount = Math.floor(total / n * 100) / 100`. Con 3 cuotas de $1,050,000.55: base = $350,000.18, suma 3×base = $1,050,000.54. La diferencia ($0.01) se suma a la última cuota, pero la acumulación en muchos créditos genera discrepancias contables.
**Impacto**: Pequeñas discrepancias contables acumulables. En finanzas, cualquier centavo importa para cuadrar libros.
**Recomendación**: Usar redondeo bancario (round-half-up). Verificar `sum(cuotas) === totalConInterés` exactamente. Considerar usar `Decimal.js` en lugar de `number`.

---

## 🔴 CRÍTICO — Crédito duplicado en entidad Sale (dos fuentes de verdad)

**Archivo**: `backend/src/sales/entities/sale.entity.ts` + `backend/src/credits/entities/credit-account.entity.ts`
**Descripción**: `Sale` guarda `creditInstallments`, `creditPaidAmount`, `creditInterestRate`, `creditFrequency` Y existe `CreditAccount` con los mismos campos. Son dos fuentes de verdad. Un update en `CreditAccount` no actualiza `Sale`.
**Impacto**: Inconsistencia de datos entre sale y creditAccount. UI puede mostrar balances distintos dependiendo de qué entidad lee.
**Recomendación**: Eliminar campos de crédito de `Sale`. Reemplazar con relación `@OneToOne(() => CreditAccount)`. CreditAccount es la única fuente de verdad.

---

## 🟠 ALTO — Race condition en descuento de stock al crear venta

**Archivo**: `backend/src/sales/sales.service.ts:68-87`
**Descripción**: Se usa `pessimistic_write` lock en la lectura del producto. Pero la validación `if (product.stock < item.quantity)` y el save posterior pueden ser interrumpidos entre transacciones concurrentes, permitiendo sobreventa.
**Impacto**: Se puede vender más stock del disponible en escenarios de alta concurrencia.
**Recomendación**: Usar `UPDATE products SET stock = stock - :qty WHERE id = :id AND stock >= :qty` en una sola operación atómica. Si `affected = 0`, rechazar la venta.

---

## 🟠 ALTO — customerId no se valida que pertenezca al team

**Archivo**: `backend/src/sales/sales.service.ts:109`
**Descripción**:
```typescript
customerId: createSaleDto.customerId || null,
```
No hay validación de que el customer exista y pertenezca al `teamId` actual. Se puede vincular una venta a un cliente de otro team.
**Impacto**: Data leak entre teams. IDOR potencial.
**Recomendación**: Antes de guardar:
```typescript
if (dto.customerId) {
  const customer = await manager.findOne(Customer, {
    where: { id: dto.customerId, teamId }
  });
  if (!customer) throw new BadRequestException('Cliente no encontrado');
}
```

---

## 🟠 ALTO — Estado DEFAULTED nunca se asigna automáticamente

**Archivo**: `backend/src/credits/credits.service.ts`
**Descripción**: El enum `CreditStatus` tiene `DEFAULTED` pero no hay job ni lógica que lo asigne. Créditos con cuotas vencidas hace meses siguen en `ACTIVE`.
**Impacto**: Dashboard muestra créditos "activos" que son irrecuperables. No hay métrica de mora real.
**Recomendación**: Job diario (NestJS `@Cron`):
```typescript
@Cron('0 0 * * *')
async markDefaultedCredits() {
  const cutoff = new Date();
  cutoff.setMonth(cutoff.getMonth() - 2);
  // creditos donde TODAS las cuotas pendientes tienen dueDate < cutoff
  // → status = DEFAULTED
}
```

---

## 🟠 ALTO — payInstallment no crea registro de Payment

**Archivo**: `backend/src/credits/credits.service.ts:138-193`
**Descripción**: `POST /credits/:id/installments/:id/pay` actualiza la cuota pero NO crea un registro en la tabla `payments`. Los pagos de crédito no tienen audit trail.
**Impacto**: No hay historial de quién pagó, cuándo, con qué método. Vulnerable a fraude interno.
**Recomendación**: Dentro del método, crear Payment después de actualizar cuota:
```typescript
await paymentsRepo.save({
  teamId, creditAccountId, installmentId,
  amount: paymentAmount, method: dto.method,
  paidAt: new Date()
});
```

---

## 🟠 ALTO — Cancel de venta no cancela CreditAccount asociado

**Archivo**: `backend/src/sales/sales.service.ts:244-303`
**Descripción**: Al cancelar una venta, se restaura stock. Pero si hay `CreditAccount` vinculada, queda en `ACTIVE`. El cliente debe seguir pagando un crédito por una compra cancelada.
**Impacto**: Conflicto legal y operativo grave.
**Recomendación**: En `cancel()`:
```typescript
const credit = await creditsRepo.findOne({ where: { saleId: sale.id } });
if (credit) {
  credit.status = CreditStatus.CANCELLED;
  await creditsRepo.save(credit);
}
```

---

## 🟡 MEDIO — Stock no se valida en UI antes de crear venta

**Archivo**: `mobile/lib/features/sales/presentation/screens/create_sale_screen.dart:649-651`
**Descripción**: El botón `+` del carrito se deshabilita cuando `qty >= stock`, pero sin tooltip que explique por qué. El usuario no sabe que no puede agregar más.
**Impacto**: UX confusa. Usuario frustrado al ver botón deshabilitado sin razón visible.
**Recomendación**: Mostrar badge "Stock: X disponible" y tooltip en botón deshabilitado.

---

## 🟡 MEDIO — Offline sale sin conflict resolution

**Archivo**: `mobile/lib/features/sales/data/sales_repository.dart:43-60`
**Descripción**: Venta guardada offline se intenta sincronizar después. No hay validación de que el stock siga disponible ni mecanismo de retry con backoff.
**Impacto**: Sincronización de ventas offline puede fallar silenciosamente o sobrevender.
**Recomendación**: Implementar queue de sincronización con reintentos, validar stock al momento de sincronizar, notificar al usuario si la sync falla permanentemente.

---

## 🟡 MEDIO — creditBalance calculado en cliente, no en servidor

**Archivo**: `mobile/lib/shared/models/sale_model.dart:40-48`
**Descripción**: El getter `creditBalance` calcula el saldo en el modelo Flutter usando campos locales. Si el backend actualiza el interés o aplica un descuento, el balance mostrado en mobile no refleja la realidad hasta el próximo fetch.
**Impacto**: Saldo incorrecto mostrado al usuario.
**Recomendación**: El backend debe retornar `remainingBalance` como campo calculado en el response de CreditAccount. No calcular en cliente.

---

## 🟡 MEDIO — Delete de cliente sin verificar creditAccounts

**Archivo**: `backend/src/customers/customers.service.ts:90-98`
**Descripción**: Verifica `customer.sales.length > 0` pero no verifica `creditAccounts`. Un cliente con crédito activo sin venta directa podría eliminarse.
**Impacto**: CreditAccount queda huérfano.
**Recomendación**: Agregar check de creditAccounts antes de eliminar.

---

## 🟡 MEDIO — Sin índices de BD para queries de reportes

**Archivo**: Queries en `sales.service.ts`, `credits.service.ts`
**Descripción**: Queries por `customerId`, `createdAt`, `status`, `dueDate` sin índices documentados.
**Impacto**: Performance degradada a escala (>10K registros).
**Recomendación**:
```sql
CREATE INDEX idx_sales_team_created ON sales(team_id, created_at DESC);
CREATE INDEX idx_credits_team_status ON credit_accounts(team_id, status);
CREATE INDEX idx_installments_due_date ON credit_installments(due_date, status);
```

---

## 🟡 MEDIO — Paginación ausente en listados de ventas/créditos

**Archivo**: `backend/src/sales/sales.service.ts` — `findAll()`
**Descripción**: Los endpoints de listado no tienen paginación. Retornan TODOS los registros. Con 10K+ ventas el response puede superar 10MB.
**Impacto**: Timeouts, alto uso de memoria, APK lenta.
**Recomendación**: Implementar cursor-based pagination o `?page=1&limit=20` en todos los listados.

---

## 🟢 BAJO — Payments controller sin @RequirePermission explícito

**Archivo**: `backend/src/payments/payments.controller.ts:25-31`
**Descripción**: Solo tiene `@UseGuards(JwtAuthGuard, TeamRolesGuard)` sin declarar permiso específico requerido.
**Recomendación**: Agregar `@RequirePermission('payments.create')`.

---

## 🟢 BAJO — SaleModel.customerName puede ser null aunque customerId exista

**Archivo**: `mobile/lib/shared/models/sale_model.dart:69`
**Descripción**: `customer?['name'] as String?` retorna null si customer existe pero no tiene nombre.
**Recomendación**: Documentar el comportamiento esperado. Usar `'Sin nombre'` como fallback en UI.

---

## Resumen

| Severidad | Cantidad |
|-----------|----------|
| 🔴 CRÍTICO | 4 |
| 🟠 ALTO | 6 |
| 🟡 MEDIO | 6 |
| 🟢 BAJO | 2 |
| **TOTAL** | **18** |

**Top 3:**
1. CreditAccount creado fuera de transacción — pérdida de datos
2. creditPaidAmount sin límite — saldos negativos
3. Cancel de venta no cancela crédito — conflicto legal
