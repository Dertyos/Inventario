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
   │ quantity  INT    │    │ type           ENUM          │
   │ receivedAt DATE  │    │   in|out|adjustment|sale|    │
   │ createdAt        │    │   purchase|return            │
   └──────────────────┘    │ quantity       INT           │
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
│ email                 │      │ email                    │
│ phone                 │      │ phone                    │
│ documentType          │      │ documentType             │
│   CC|NIT|CE|PASSPORT  │      │ documentNumber           │
│ documentNumber        │      │ address                  │
│ address               │      │ notes                    │
│ notes                 │      │ createdAt                │
│ createdAt             │      │ updatedAt                │
│ updatedAt             │      └────────────┬─────────────┘
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

### Fase 2 — Clientes y Ventas
> El core comercial. Registrar quién compra qué.

**Tablas nuevas:**
- `customers` — datos del cliente
- `sales` — encabezado de venta
- `sale_items` — líneas de la venta
- `payments` — pagos recibidos

**Endpoints:**
- `POST /teams/:teamId/customers` — crear cliente
- `POST /teams/:teamId/sales` — registrar venta (descuenta stock automáticamente)
- `GET /teams/:teamId/sales` — historial con filtros (fecha, cliente, estado)
- `POST /teams/:teamId/payments` — registrar pago

---

### Fase 3 — Créditos y Cuotas (requiere `enableCredit`)
> Para negocios que "fían" o venden a plazos.

**Tablas nuevas:**
- `credit_accounts` — la cuenta de crédito
- `credit_installments` — cada cuota generada

**Lógica:**
1. Al crear venta con `paymentMethod: 'credit'`, se genera `credit_account`
2. Se calculan cuotas según `interestRate` e `installments`
3. Cada pago actualiza `paidAmount` en la cuota y en la cuenta
4. Cuotas vencidas cambian a estado `overdue` (job periódico)

---

### Fase 4 — Lotes y Vencimientos (requiere `enableLots`)
> Trazabilidad para productos perecederos o regulados.

**Tablas nuevas:**
- `product_lots` — lote con número, fecha de vencimiento, cantidad

**Lógica:**
- Solo aplica si `product.trackLots = true` Y `team_settings.enableLots = true`
- Al hacer entrada de inventario, se asocia al lote
- Al vender, se descuenta del lote más antiguo primero (FEFO: First Expired, First Out)
- Alerta cuando un lote está próximo a vencer

---

### Fase 5 — Proveedores y Compras (requiere `enableSuppliers`)
> Trackear de dónde viene la mercancía.

**Tablas nuevas:**
- `suppliers` — datos del proveedor
- `purchases` — orden de compra
- `purchase_items` — líneas de la compra

**Lógica:**
- Al registrar compra, se genera movimiento de inventario tipo `purchase`
- Se actualiza el `cost` del producto automáticamente (último costo o promedio)

---

### Fase 6 — Recordatorios y Notificaciones (requiere `enableReminders`)
> Cobro automático de cuotas.

**Tablas nuevas:**
- `payment_reminders` — recordatorio programado
- `notifications` — notificaciones internas del sistema

**Lógica:**
- Job periódico revisa cuotas próximas a vencer
- Genera recordatorios 3 días antes, el día, y 1 día después
- Canales: SMS, WhatsApp (API), email, push notification (app Flutter)

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
