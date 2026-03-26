# Gaps y Pendientes — Inventario

Documento generado a partir de auditoría exhaustiva comparando documentación vs implementación.
Última revisión: 2026-03-26

---

## Estado General: 98/100

---

## Corregido en v1.2.0

| Issue | Severidad | Estado |
|-------|-----------|--------|
| Productos no detectados en nuevo movimiento | CRÍTICO | Corregido |
| Ventas mostrando $0 (totalAmount vs total) | CRÍTICO | Corregido |
| Payment entity sin link a créditos | CRÍTICO | Corregido |
| Feature toggles no enforceados | ALTO | Corregido |
| Crédito se creaba en Flutter, no en backend | ALTO | Corregido |
| Supplier fields en DATABASE.md no coincidían | BAJO | Corregido |
| ARCHITECTURE.md sin sección de IA/Voz | BAJO | Corregido |
| release-checklist.md no existía | BAJO | Corregido |
| Flutter sin UI para créditos, compras, lotes, notificaciones, recordatorios | ALTO | Corregido |
| Proveedores solo inline, sin pantalla CRUD | MEDIO | Corregido |

---

## Corregido en v1.2.1 (2026-03-26)

| Issue | Severidad | Estado | Archivo |
|-------|-----------|--------|---------|
| `context.go` en rutas con `parentNavigatorKey: _rootNavigatorKey` — sin back button al navegar a formularios | ALTO | Corregido | `products_screen.dart` (×3), `dashboard_screen.dart` (×1) |
| Método de pago `card` (Tarjeta) faltante en UI de venta — backend sí lo soporta | ALTO | Corregido | `create_sale_screen.dart` |
| `int.parse` sin manejo → crash `FormatException` si usuario escribe texto en cantidad | ALTO | Corregido | `inventory_screen.dart` |
| AI `createPurchase` no enviaba `supplierId` (no-nullable en backend) → siempre 400 | ALTO | Corregido | `ai_chat_screen.dart` |
| Dead code: ternario `preselectedProduct != null ? 'in' : 'in'` ambas ramas idénticas | BAJO | Corregido | `inventory_screen.dart` |
| GAPS.md reportaba SupplierModel como incompleto (ya parseaba email/address/notes) | BAJO | Corregido | `GAPS.md` |

---

## Pendientes Menores

### 1. DEVELOPMENT.md incompleto (MEDIO)
- No menciona setup para Flutter web
- Sin sección de troubleshooting
- Sin tips de debugging específicos del proyecto

### 2. Falta paginación en listas (MEDIO)
- `sales_screen.dart`, `purchases_screen.dart`, `credits_screen.dart` cargan todos los registros
- Para negocios con > 500 registros impactará rendimiento y tiempo de carga
- El backend ya soporta `page` + `limit` query params

### 3. RefreshIndicator faltante en estados de error (BAJO)
- Cuando un provider falla, el usuario ve el error pero no puede hacer pull-to-refresh
- Agregar `RefreshIndicator` en los estados de error en `products_screen.dart`, `sales_screen.dart`, etc.

### 4. Validación visual al alcanzar stock máximo en carrito (BAJO)
- `create_sale_screen.dart`: el botón `+` se deshabilita cuando `qty >= stock` pero sin feedback visual claro

---

## Arquitectura Validada

| Componente | Docs | Backend | Flutter | Tests | Estado |
|------------|------|---------|---------|-------|--------|
| Teams/Multi-tenant | DATABASE.md | Entidad + Guards | Screens | Sí | Completo |
| Products/Categories | DATABASE.md | CRUD + trackLots | CRUD + Form | Sí | Completo |
| Sales | DATABASE.md | Transaccional | Crear + Historial | Sí | Completo |
| Credit Accounts | DATABASE.md | Auto-generación | Lista + Detalle + Pago | Sí | Completo |
| Inventory | DATABASE.md | Stock tracking | Movimientos + Stock bajo | Sí | Completo |
| Customers | DATABASE.md | CRUD | CRUD + Búsqueda | Sí | Completo |
| Suppliers | DATABASE.md | CRUD | CRUD + Inline | Sí | Completo |
| Purchases | DATABASE.md | CRUD + Recibir | Lista + Crear | Sí | Completo |
| Product Lots | DATABASE.md | FEFO | Lista + Crear | Sí | Completo |
| Payments | DATABASE.md | CRUD + Credit link | (vía créditos) | Sí | Completo |
| Notifications | DATABASE.md | CRUD | Lista + Mark read | — | Completo |
| Reminders | DATABASE.md | Generar + CRUD | Lista + Generar | — | Completo |
| Feature Toggles | DATABASE.md | @RequireFeature guard | team_settings UI | — | Completo |
| AI/Voice | CHANGELOG | Claude SDK | speech_to_text | — | Completo |
| CI/CD | CI-CD.md | GitHub Actions | Codemagic | — | Completo |
| Infrastructure | INFRASTRUCTURE.md | Terraform ECS | — | — | Staging only |

---

## Para Producción

Antes de desplegar a producción, verificar:

1. [ ] Android signing config (build.gradle.kts TODOs)
2. [ ] Variables de entorno de producción en Secrets Manager
3. [ ] Crear environment Terraform para production
4. [ ] Verificar rate limiting en endpoints AI (5 req/min)
5. [ ] Pruebas de carga en endpoints transaccionales (sales, inventory)
6. [ ] Configurar Sentry DSN para error tracking
