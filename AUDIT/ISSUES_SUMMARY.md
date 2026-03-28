# Resumen Consolidado de Auditoría
Fecha: 2026-03-28
App: Inventario (NestJS backend + Flutter mobile)

---

## Totales por severidad

| Severidad | Auth/Seg | Ventas/Créditos | Inventario/Compras | IA/Dashboard | Mobile | **TOTAL** |
|-----------|----------|-----------------|--------------------|--------------|--------|-----------|
| 🔴 CRÍTICO | 2 | 4 | 3 | 3 | 4 | **16** |
| 🟠 ALTO | 4 | 6 | 7 | 7 | 5 | **29** |
| 🟡 MEDIO | 5 | 6 | 5 | 7 | 7 | **30** |
| 🟢 BAJO | 3 | 2 | 1 | 3 | 5 | **14** |
| **Total** | **14** | **18** | **16** | **20** | **21** | **89** |

---

## 🔴 TODOS LOS CRÍTICOS (16)

### Pérdida/corrupción de datos
1. **CreditAccount creado fuera de transacción** — venta con crédito sin cuotas → `02_SALES_CUSTOMERS_CREDITS.md`
2. **Cancel de compra no revierte stock** — inventario irreal → `03_PURCHASES_SUPPLIERS_INVENTORY.md`
3. **Pending sales en SharedPreferences** — pérdida en crash → `05_MOBILE_FLUTTER.md`
4. **Redondeo de cuotas pierde centavos** — discrepancias contables → `02_SALES_CUSTOMERS_CREDITS.md`
5. **Crédito duplicado (Sale + CreditAccount)** — dos fuentes de verdad → `02_SALES_CUSTOMERS_CREDITS.md`

### Seguridad
6. **JWT 30 días sin refresh token** — sesiones robadas son válidas 30 días → `01_AUTH_TEAMS_SECURITY.md`
7. **Sin consentimiento en social auth** — GDPR / Ley 1581 → `01_AUTH_TEAMS_SECURITY.md`
8. **Export sin rate limiting** — DoS, exposición masiva de datos → `04_AI_REMINDERS_DASHBOARD.md`
9. **Analytics cache sin teamId** — datos de un team visibles para otro → `04_AI_REMINDERS_DASHBOARD.md`
10. **IDOR: GET /users/:id sin restricción** — cualquier usuario ve datos de otros → `01_AUTH_TEAMS_SECURITY.md` *(fue clasificado 🟠 pero es potencialmente crítico)*

### Crashes móvil
11. **DateTime.parse() sin try-catch** — crash al cargar listas → `05_MOBILE_FLUTTER.md`
12. **Unsafe cast `response.data as List`** — crash en listados → `05_MOBILE_FLUTTER.md`
13. **AuthInterceptor race condition** — estado inconsistente tras 401 → `05_MOBILE_FLUTTER.md`

### Validación de negocio rota
14. **creditPaidAmount sin límite superior** — saldos negativos → `02_SALES_CUSTOMERS_CREDITS.md`
15. **IA crea ventas con precio negativo** — pérdida contable → `04_AI_REMINDERS_DASHBOARD.md`
16. **Lotes sin validación de team/producto** — desincronización stock → `03_PURCHASES_SUPPLIERS_INVENTORY.md`

---

## Plan de acción por sprint

### Sprint 1 — Urgente (bloqueantes para producción confiable)

**Backend:**
- [ ] `sales.service.ts` — mover `creditsService.create()` dentro de la transacción
- [ ] `purchases.service.ts` — revertir stock al cancelar compra RECEIVED
- [ ] `sales/dto` — agregar validación `creditPaidAmount <= subtotal`
- [ ] `credits.service.ts` — corregir redondeo bancario en cuotas
- [ ] `export.controller.ts` — agregar `@Throttle()` en endpoints de export
- [ ] `analytics.controller.ts` — corregir clave de caché para incluir `teamId`
- [ ] `ai.service.ts` — validar `unit_price >= 0` en parseTransaction
- [ ] `reminders` — agregar constraint UNIQUE para evitar duplicados

**Mobile:**
- [ ] Todos los modelos — reemplazar `DateTime.parse()` por `DateTime.tryParse()` + fallback
- [ ] Repositorios — validar `response.data is List` antes de cast
- [ ] `api_interceptor.dart` — corregir race condition en manejo de 401

### Sprint 2 — Alto impacto

**Backend:**
- [ ] `sales.service.ts` — validar `customerId` pertenece al team
- [ ] `products.service.ts` — validar SKU duplicado en update
- [ ] `credits.service.ts` — job diario para marcar créditos DEFAULTED
- [ ] `credits.service.ts` — crear Payment record en `payInstallment()`
- [ ] `sales.service.ts` — cancelar CreditAccount al cancelar venta
- [ ] `email.service.ts` — implementar email queue con retry
- [ ] `users.controller.ts` — restringir GET /users/:id a solo self o admin

**Mobile:**
- [ ] `sync_service.dart` — logging de errores + notificación al usuario
- [ ] `create_sale_screen.dart` — validar suma de métodos de pago = total
- [ ] Mensajes de error — mapear excepciones a mensajes legibles en español
- [ ] `dashboard_screen.dart` — invalidar providers tras crear venta/compra

### Sprint 3 — Mejoras importantes

**Backend:**
- [ ] `sale.entity.ts` — eliminar campos de crédito, usar solo CreditAccount como fuente
- [ ] Migraciones — índices en `sales(team_id, created_at)`, `credit_accounts(team_id, status)`, `credit_installments(due_date, status)`
- [ ] `export.service.ts` — streamear CSV en lugar de cargar todo en memoria
- [ ] `audit.entity.ts` — agregar campos `changesBefore` + `changesAfter`
- [ ] `purchases.service.ts` — implementar recepciones parciales
- [ ] `purchases.service.ts` — costo promedio ponderado al recibir
- [ ] `auth.controller.ts` — agregar `@Throttle()` a `/auth/register`
- [ ] `teams.service.ts` — agregar sufijo random al slug

**Mobile:**
- [ ] `pending_sales_service.dart` — migrar de SharedPreferences a SQLite
- [ ] `create_sale_screen.dart` — feedback de stock disponible en UI
- [ ] `reminders_screen.dart` — mostrar warning cuando `channel=whatsapp` pero sin teléfono
- [ ] `app_router.dart` — validar parámetros de ruta antes de fuerza unwrap
- [ ] Integrar Sentry/Firebase Crashlytics para crash reporting

### Sprint 4 — Deuda técnica y UX

- [ ] `auth.service.ts` — consentimiento en social auth (Google/Apple)
- [ ] JWT refresh token implementation
- [ ] Certificate Pinning en Android e iOS
- [ ] `ai.service.ts` — búsqueda fuzzy de cliente/proveedor
- [ ] `reminders.service.ts` — soporte de timezone en generación
- [ ] Paginación en todos los listados grandes (ventas, créditos, compras)
- [ ] `inventory.service.ts` — permisos por tipo de movimiento + aprobación para ajustes grandes
- [ ] `lots.service.ts` — campo `isPerishable` en productos
- [ ] i18n básico para mensajes de error en mobile
- [ ] Timeout Dio: reducir a 15-20s con feedback visual

---

## Áreas más problemáticas

1. **Créditos/Pagos** — lógica de negocio incompleta: sin transacciones, sin audit trail de pagos, sin cancelación automática
2. **Inventario** — cancel de compra sin reversión, costo incorrecto, lotes desconectados del stock
3. **Mobile models** — fromJson frágil: crashes en fechas y casts sin validación
4. **Seguridad** — JWT largo sin refresh, analytics cache compartida entre teams

## Áreas bien implementadas ✅

- Multi-tenant: `teamId` filtrado en todos los servicios
- Guards: `JwtAuthGuard` + `TeamRolesGuard` en todos los controllers
- Storage seguro en mobile: `flutter_secure_storage` con encriptación
- RBAC: permisos por acción implementados en UI y backend
- Validaciones de DTOs (excepto los casos señalados)
- Código generalmente limpio y bien estructurado
