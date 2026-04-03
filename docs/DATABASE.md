# Base de Datos — Inventario

## Visión General

Sistema multi-tenant donde cada **equipo (team)** es un negocio independiente con su propio inventario, clientes, ventas y configuración. Los usuarios pueden pertenecer a múltiples equipos con diferentes roles.

### Principios de diseño

| Principio | Implementación |
|---|---|
| **Multi-tenant por equipo** | Todas las tablas de negocio tienen `teamId` como FK |
| **Features toggleables** | Tabla `team_settings` con flags para activar/desactivar módulos complejos |
| **Soft-delete** | Users y products usan `isActive` en vez de borrar registros |
| **Auditoría** | Movimientos de inventario guardan `stockBefore`/`stockAfter` |
| **Transaccional** | Movimientos de stock usan pessimistic locking |

---

## Diagrama ER Completo

```
┌─────────────────────┐
│       users          │
├─────────────────────┤         ┌──────────────────────────┐
│ id            UUID PK│         │         teams             │
│ email         UQ     │         ├──────────────────────────┤
│ password      HASH   │         │ id             UUID PK   │
│ firstName            │         │ name                     │
│ lastName             │         │ slug           UQ        │
│ phone                │         │ currency       COP|USD   │
│ isActive      BOOL   │         │ timezone                 │
│ createdAt            │         │ isActive       BOOL      │
│ updatedAt            │         │ createdAt                │
└────────┬────────────┘         │ updatedAt                │
         │                      └──────────┬───────────────┘
         │ N:N via team_members            │
         │                                 │ 1:1
┌────────▼─────────────────────┐ ┌────────▼───────────────────────┐
│      team_members            │ │       team_settings             │
├──────────────────────────────┤ ├─────────────────────────────────┤
│ id             UUID PK       │ │ id              UUID PK        │
│ userId         FK → users    │ │ teamId          FK → teams UQ  │
│ teamId         FK → teams    │ │                                 │
│ role           ENUM          │ │ enableLots      BOOL (false)   │
│   owner|admin|manager|staff  │ │ enableCredit    BOOL (false)   │
│ isActive       BOOL         │ │ enableSuppliers BOOL (false)   │
│ joinedAt       TIMESTAMP    │ │ enableReminders BOOL (false)   │
│ createdAt                    │ │ enableTax       BOOL (false)   │
│ updatedAt                    │ │ enableBarcode   BOOL (false)   │
└──────────────────────────────┘ │ defaultTaxRate  DECIMAL (19.00)│
                                 │ createdAt                      │
    UQ(userId, teamId)           │ updatedAt                      │
                                 └─────────────────────────────────┘

         Todo lo de abajo lleva teamId FK → teams
         ════════════════════════════════════════

┌──────────────────────┐       ┌───────────────────────────┐
│     categories       │       │        products            │
├──────────────────────┤       ├───────────────────────────┤
│ id          UUID PK  │  1:N  │ id             UUID PK   │
│ teamId      FK       │◄──────│ teamId         FK        │
│ name                 │       │ categoryId     FK        │
│ description          │       │ sku            VARCHAR   │
│ color       VARCHAR  │       │ barcode        VARCHAR   │
│ createdAt            │       │ name                     │
│ updatedAt            │       │ description              │
└──────────────────────┘       │ imageUrl       VARCHAR   │
                               │ price          DEC(12,2) │
  UQ(teamId, name)             │ cost           DEC(12,2) │
                               │ stock          INT       │
                               │ minStock       INT       │
                               │ trackLots      BOOL ◄─── toggle por producto
                               │ isActive       BOOL      │
                               │ createdAt                │
                               │ updatedAt                │
                               └────────┬──────────────────┘

                                  UQ(teamId, sku)

   ┌──────────────────┐    ┌──────────────────────────────┐
   │   product_lots   │    │    inventory_movements        │
   ├──────────────────┤    ├──────────────────────────────┤
   │ id        UUID PK│    │ id             UUID PK       │
   │ productId FK     │    │ teamId         FK            │
   │ teamId    FK     │    │ productId      FK            │
   │ lotNumber VARCHAR│    │ lotId          FK? (nullable)│
   │ expiresAt DATE   │    │ userId         FK            │
   │ quantity  INT    │    │ supplierId     FK? (nullable)│
   │ receivedAt DATE  │    │ type           ENUM          │
   │ createdAt        │    │   in|out|adjustment|sale|    │
   └──────────────────┘    │   purchase|return            │
                           │ quantity       INT           │
                           │ reason         VARCHAR       │
  Solo si team.enableLots  │ referenceType  VARCHAR?      │
  AND product.trackLots    │ referenceId    UUID?         │
                           │ stockBefore    INT           │
                           │ stockAfter     INT           │
                           │ createdAt                    │
                           └──────────────────────────────┘


┌───────────────────────┐      ┌──────────────────────────┐
│      customers        │      │       suppliers           │
├───────────────────────┤      ├──────────────────────────┤
│ id           UUID PK  │      │ id            UUID PK    │
│ teamId       FK       │      │ teamId        FK         │
│ name                  │      │ name                     │
│ email                 │      │ nit            VARCHAR   │
│ phone                 │      │ contactName    VARCHAR   │
│ documentType          │      │ email                    │
│   CC|NIT|CE|PASSPORT  │      │ phone                    │
│ documentNumber        │      │ address                  │
│ address               │      │ notes                    │
│ notes                 │      │ isActive       BOOL      │
│ createdAt             │      │ createdAt                │
│ updatedAt             │      │ updatedAt                │
│                       │      └────────────┬─────────────┘
└───────────┬───────────┘                   │
            │                    Solo si team.enableSuppliers
            │
            ▼
┌───────────────────────┐      ┌──────────────────────────┐
│        sales          │      │       purchases           │
├───────────────────────┤      ├──────────────────────────┤
│ id           UUID PK  │      │ id            UUID PK    │
│ teamId       FK       │      │ teamId        FK         │
│ customerId   FK?      │      │ supplierId    FK         │
│ userId       FK       │      │ userId        FK         │
│ saleNumber   VARCHAR  │      │ purchaseNumber           │
│ subtotal     DEC(12,2)│      │ subtotal      DEC(12,2) │
│ tax          DEC(12,2)│      │ tax           DEC(12,2) │
│ total        DEC(12,2)│      │ total         DEC(12,2) │
│ paymentMethod ENUM    │      │ status        ENUM       │
│  cash|card|transfer|  │      │  pending|partial|paid|   │
│  credit               │      │  cancelled               │
│ status       ENUM     │      │ createdAt                │
│  completed|cancelled| │      │ updatedAt                │
│  refunded             │      └──────────────────────────┘
│ creditInstallments INT│
│ creditPaidAmount  DEC │       Solo si team.enableSuppliers
│ creditInterestRate DEC│
│ creditFrequency   VARCHAR│   monthly|weekly|daily
│ creditNextPayment DATE│
│ notes                 │
│ createdAt             │       Solo si team.enableSuppliers
│ updatedAt             │
└──┬──────────┬─────────┘
   │          │
   │ 1:N      │ (si paymentMethod = 'credit')
   │          │
   │   ┌──────▼──────────────────┐
   │   │    credit_accounts      │
   │   ├─────────────────────────┤
   │   │ id           UUID PK   │
   │   │ teamId       FK        │
   │   │ saleId       FK        │
   │   │ customerId   FK        │
   │   │ totalAmount  DEC(12,2) │
   │   │ paidAmount   DEC(12,2) │
   │   │ interestRate DEC(5,2)  │
   │   │ interestType ENUM      │
   │   │  none|fixed|monthly    │
   │   │ installments INT       │
   │   │ startDate    DATE      │
   │   │ status       ENUM      │
   │   │  active|paid|defaulted │
   │   │ createdAt              │
   │   │ updatedAt              │
   │   └──────────┬─────────────┘
   │              │
   │              │ Solo si team.enableCredit
   │              │ 1:N
   │   ┌──────────▼─────────────┐
   │   │ credit_installments    │
   │   ├────────────────────────┤
   │   │ id             UUID PK │
   │   │ creditAccountId FK     │
   │   │ installmentNo  INT     │
   │   │ amount         DEC     │
   │   │ dueDate        DATE    │
   │   │ paidAmount     DEC     │
   │   │ paidAt         TIMESTAMP│
   │   │ status         ENUM    │
   │   │  pending|paid|overdue| │
   │   │  partial               │
   │   │ createdAt              │
   │   └──────────┬─────────────┘
   │              │
   │              │ 1:N (si team.enableReminders)
   │   ┌──────────▼─────────────┐
   │   │  payment_reminders     │
   │   ├────────────────────────┤
   │   │ id             UUID PK │
   │   │ teamId         FK      │
   │   │ installmentId  FK      │
   │   │ reminderDate   DATE    │
   │   │ channel        ENUM    │
   │   │  sms|whatsapp|email    │
   │   │ status         ENUM    │
   │   │  pending|sent|failed   │
   │   │ sentAt         TIMESTAMP│
   │   │ createdAt              │
   │   └────────────────────────┘
   │
   │ 1:N
┌──▼──────────────────┐
│     sale_items       │      ┌──────────────────────────┐
├─────────────────────┤      │    purchase_items         │
│ id         UUID PK  │      ├──────────────────────────┤
│ saleId     FK       │      │ id          UUID PK      │
│ productId  FK       │      │ purchaseId  FK           │
│ lotId      FK?      │      │ productId   FK           │
│ quantity   INT      │      │ lotId       FK?          │
│ unitPrice  DEC(12,2)│      │ quantity    INT          │
│ subtotal   DEC(12,2)│      │ unitCost    DEC(12,2)   │
│ createdAt           │      │ subtotal    DEC(12,2)   │
└─────────────────────┘      │ createdAt               │
                              └──────────────────────────┘

┌──────────────────────────┐
│       payments           │
├──────────────────────────┤
│ id             UUID PK   │
│ teamId         FK        │
│ creditAccountId FK?      │
│ installmentId  FK?       │
│ saleId         FK?       │
│ amount         DEC(12,2) │
│ method         ENUM      │
│   cash|card|transfer     │
│ reference      VARCHAR   │
│ notes          VARCHAR   │
│ receivedBy     FK(user)  │
│ paidAt         TIMESTAMP │
│ createdAt                │
└──────────────────────────┘
```

---

## Feature Toggles (team_settings)

Cada equipo puede activar/desactivar módulos según sus necesidades. Un negocio pequeño puede empezar solo con productos y ventas, y luego ir activando funciones avanzadas.

| Feature Flag | Default | Qué habilita | Para quién |
|---|---|---|---|
| `enableLots` | `false` | Lotes y fechas de vencimiento en productos | Farmacias, alimentos, cosméticos |
| `enableCredit` | `false` | Ventas a crédito, cuotas, intereses | Tiendas con clientes frecuentes |
| `enableSuppliers` | `false` | Módulo de proveedores y compras | Negocios que quieren trackear compras |
| `enableReminders` | `false` | Recordatorios de pago por SMS/WhatsApp/email | Negocios con ventas a crédito |
| `enableTax` | `false` | Cálculo automático de impuestos (IVA) | Negocios formalizados |
| `enableBarcode` | `false` | Escaneo de código de barras en la app | Tiendas con muchos productos |

### Ejemplo: Tienda de barrio vs Distribuidora

```
Tienda de barrio (plan básico):
  enableLots      = false   ← no maneja lotes
  enableCredit    = true    ← "fía" a clientes
  enableSuppliers = false   ← no trackea proveedores
  enableReminders = false   ← cobra personalmente
  enableTax       = false   ← régimen simplificado
  enableBarcode   = false   ← pocos productos

Distribuidora farmacéutica (plan pro):
  enableLots      = true    ← INVIMA requiere trazabilidad
  enableCredit    = true    ← vende a crédito a farmacias
  enableSuppliers = true    ← múltiples proveedores
  enableReminders = true    ← notifica cobros automáticamente
  enableTax       = true    ← régimen común, factura con IVA
  enableBarcode   = true    ← miles de productos
```

---

## Fases de Implementación

### Fase 1 — Equipos y Multi-tenant ✅ (actual)
> Base para todo lo demás. Sin esto, no hay separación de datos.

**Tablas nuevas:**
- `teams` — el negocio/organización
- `team_members` — relación usuario↔equipo con roles
- `team_settings` — feature toggles

**Cambios a tablas existentes:**
- `categories` → agregar `teamId`, `color`
- `products` → agregar `teamId`, `barcode`, `imageUrl`, `trackLots`
- `inventory_movements` → agregar `teamId`, `referenceType`, `referenceId`

**Roles de equipo:**
| Rol | Permisos |
|---|---|
| `owner` | Todo. Puede eliminar el equipo. |
| `admin` | Todo excepto eliminar equipo. Gestiona miembros. |
| `manager` | CRUD productos, categorías, ventas. Ve reportes. |
| `staff` | Registra ventas y movimientos. Ve productos. Solo lectura en config. |

---

### Fase 2 — Clientes y Ventas ✅
> El core comercial. Registrar quién compra qué.

**Tablas nuevas:**
- `customers` — datos del cliente con tipo de documento (CC, NIT, CE, PASSPORT)
- `sales` — encabezado de venta con consecutivo auto-generado (V-0001)
- `sale_items` — líneas de la venta con precio unitario y subtotal
- `payments` — pagos recibidos (cash, card, transfer)

**Endpoints:**
- `POST/GET/PATCH/DELETE /teams/:teamId/customers` — CRUD clientes
- `POST /teams/:teamId/sales` — registrar venta (descuenta stock transaccionalmente)
- `GET /teams/:teamId/sales` — historial con filtros (fecha, cliente, estado)
- `PATCH /teams/:teamId/sales/:id/cancel` — cancelar venta (restaura stock)
- `POST/GET /teams/:teamId/payments` — registrar y consultar pagos

**Flujo de venta:**
1. Se valida stock de cada producto (con pessimistic locking)
2. Se descuenta stock y se crean movimientos tipo `SALE`
3. Se genera consecutivo auto-incremental (V-0001, V-0002...)
4. Al cancelar, se restaura stock con movimientos tipo `RETURN`

---

### Fase 3 — Créditos y Cuotas ✅ (requiere `enableCredit`)
> Para negocios que "fían" o venden a plazos.

**Tablas nuevas:**
- `credit_accounts` — la cuenta de crédito con tipo de interés
- `credit_installments` — cada cuota con fecha de vencimiento y tracking de pago

**Endpoints:**
- `POST /teams/:teamId/credits` — crear cuenta de crédito con cuotas
- `GET /teams/:teamId/credits` — listar créditos (filtro por cliente, estado)
- `GET /teams/:teamId/credits/overdue` — cuotas vencidas pendientes
- `POST /teams/:teamId/credits/:id/installments/:installmentId/pay` — pagar cuota

**Lógica:**
1. Al crear venta con `paymentMethod: 'credit'`, se genera `credit_account`
2. Se calculan cuotas según `interestRate` e `installments`
3. Cada pago actualiza `paidAmount` en la cuota y en la cuenta
4. Cuotas vencidas cambian a estado `overdue` (job periódico)

---

### Fase 4 — Lotes y Vencimientos ✅ (requiere `enableLots`)
> Trazabilidad para productos perecederos o regulados.

**Tablas nuevas:**
- `product_lots` — lote con número, fecha de vencimiento, cantidad, estado (active/expired/depleted)

**Endpoints:**
- `POST /teams/:teamId/lots` — crear lote
- `GET /teams/:teamId/lots` — listar lotes (filtro por producto, estado)
- `GET /teams/:teamId/lots/expiring?days=30` — lotes próximos a vencer
- `POST /teams/:teamId/lots/mark-expired` — marcar lotes expirados

**Lógica:**
- Solo aplica si `product.trackLots = true` Y `team_settings.enableLots = true`
- Al vender, se descuenta del lote más antiguo primero (FEFO: First Expired, First Out)
- Alerta cuando un lote está próximo a vencer (configurable por días)
- Los lotes se marcan automáticamente como `depleted` al agotarse o `expired` al vencer

---

### Fase 5 — Proveedores y Compras ✅ (requiere `enableSuppliers`)
> Trackear de dónde viene la mercancía.

**Tablas nuevas:**
- `suppliers` — datos del proveedor con NIT único por equipo
- `purchases` — orden de compra con consecutivo auto-generado (C-0001)
- `purchase_items` — líneas de la compra

**Endpoints:**
- `POST/GET/PATCH /teams/:teamId/suppliers` — CRUD proveedores
- `POST /teams/:teamId/purchases` — crear orden de compra
- `GET /teams/:teamId/purchases` — listar (filtro por proveedor, estado)
- `PATCH /teams/:teamId/purchases/:id/receive` — recibir compra (suma stock transaccionalmente)
- `PATCH /teams/:teamId/purchases/:id/cancel` — cancelar compra pendiente

**Lógica:**
- Al recibir compra: se suma stock con pessimistic locking y se crean movimientos tipo `PURCHASE`
- Se actualiza el `cost` del producto automáticamente al último costo de compra
- Solo compras en estado `pending` pueden ser recibidas o canceladas

---

### Fase 6 — Recordatorios y Notificaciones ✅ (requiere `enableReminders`)
> Cobro automático de cuotas.

**Tablas nuevas:**
- `payment_reminders` — recordatorio programado con canal y estado
- `notifications` — notificaciones internas del sistema con metadata JSON

**Endpoints:**
- `POST /teams/:teamId/reminders/generate` — generar recordatorios para cuotas próximas
- `GET /teams/:teamId/reminders` — listar recordatorios (filtro por cliente, estado)
- `GET /teams/:teamId/notifications` — listar notificaciones (filtro unread)
- `PATCH /teams/:teamId/notifications/:id/read` — marcar como leída
- `POST /teams/:teamId/notifications/read-all` — marcar todas como leídas

**Lógica:**
- Genera recordatorios automáticos: 3 días antes, el día, y 1 día después del vencimiento
- Tipos: `before_due`, `on_due`, `after_due`
- Canales preparados: SMS, WhatsApp, email, push, internal
- Cada recordatorio genera también una notificación interna
- Mensajes en español con formato de moneda COP

---

## Fase 7 — Billing y Suscripciones ⏳ (pendiente)
> Monetización del producto. Ver [MONETIZATION.md](MONETIZATION.md) y [ADR-007](adr/007-stripe-billing.md).

**Tablas nuevas:**
- `subscriptions` — suscripción del equipo vinculada a Stripe
- `usage_records` — tracking de uso mensual por equipo

```
┌──────────────────────────────┐      ┌──────────────────────────────┐
│       subscriptions          │      │       usage_records          │
├──────────────────────────────┤      ├──────────────────────────────┤
│ id                 UUID PK   │      │ id                 UUID PK   │
│ teamId             FK → teams│      │ teamId             FK → teams│
│ stripeCustomerId   VARCHAR   │      │ periodStart        DATE      │
│ stripeSubscriptionId VARCHAR │      │ salesCount         INT (0)   │
│ plan               ENUM     │      │ productsCount      INT (0)   │
│   free|emprendedor|negocio|  │      │ aiCommandsCount    INT (0)   │
│   empresa                    │      │ creditsCount       INT (0)   │
│ status             ENUM     │      │ createdAt                    │
│   active|past_due|canceled|  │      │ updatedAt                    │
│   trialing                   │      └──────────────────────────────┘
│ currentPeriodStart TIMESTAMP │
│ currentPeriodEnd   TIMESTAMP │        UQ(teamId, periodStart)
│ cancelAtPeriodEnd  BOOL     │
│ createdAt                    │
│ updatedAt                    │
└──────────────────────────────┘

  UQ(teamId) — un equipo = una suscripción
```

**Endpoints:**
- `POST /billing/checkout` — crear sesión de Stripe Checkout
- `POST /billing/portal` — abrir Customer Portal de Stripe
- `GET /billing/subscription` — estado de la suscripción del equipo
- `GET /billing/usage` — uso actual vs límites del plan
- `POST /billing/webhooks/stripe` — webhook de Stripe (sin auth JWT, verificación por firma)

**Lógica:**
- Al registrar un equipo, se crea automáticamente una `subscription` con plan `free`
- El `PlanLimitGuard` consulta `subscriptions` + `usage_records` en cada request de creación
- Los webhooks de Stripe actualizan `status`, `plan` y períodos automáticamente
- Los `usage_records` se reinician al inicio de cada período de facturación

---

## Convenciones Técnicas

| Convención | Detalle |
|---|---|
| **PKs** | UUID v4 en todas las tablas |
| **Timestamps** | `createdAt` y `updatedAt` en todas las tablas |
| **Soft delete** | `isActive: boolean` en users, products, team_members |
| **Hard delete** | categories (con validación de no tener productos) |
| **Moneda** | `DECIMAL(12,2)` para todos los campos monetarios |
| **Enums** | TypeORM enums mapeados a PostgreSQL enums |
| **Índices** | `teamId` + campos frecuentes en WHERE (sku, email, saleNumber) |
| **Constraints** | Unique compuestos `(teamId, sku)`, `(teamId, saleNumber)`, etc. |
| **Locking** | `SELECT ... FOR UPDATE` en movimientos de inventario |

---

## Variables de Entorno (referencia)

```env
# Base de datos
DATABASE_URL=postgresql://inventario:inventario@localhost:5432/inventario

# Autenticación
JWT_SECRET=tu-secret-seguro-aqui
JWT_EXPIRATION=3600

# App
NODE_ENV=development
PORT=3000
```
