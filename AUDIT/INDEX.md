# Auditoría Inventario App — Índice
Fecha: 2026-03-28
Estado: EN PROGRESO

## Estructura de archivos de auditoría

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| `INDEX.md` | Este índice | ✅ |
| `01_AUTH_TEAMS_SECURITY.md` | Auth, equipos, seguridad JWT, guards | ✅ 14 hallazgos |
| `02_SALES_CUSTOMERS_CREDITS.md` | Ventas, clientes, créditos, cuotas, pagos | ✅ 18 hallazgos |
| `03_PURCHASES_SUPPLIERS_INVENTORY.md` | Compras, proveedores, inventario, productos, lotes | ✅ 16 hallazgos |
| `04_AI_REMINDERS_DASHBOARD.md` | IA, recordatorios, scanner, dashboard, analytics | ✅ 20 hallazgos |
| `05_MOBILE_FLUTTER.md` | Providers, navegación, estado, UX, errores UI | ✅ 21 hallazgos |
| `06_UX_USABILITY.md` | Usabilidad, flujos, terminología, accesibilidad | ✅ 30 hallazgos |
| `ISSUES_SUMMARY.md` | Resumen consolidado + plan de 4 sprints | ✅ 89 técnicos + 30 UX |

## Metodología

1. Cada agente audita su dominio de forma independiente
2. Documenta hallazgos en su archivo correspondiente
3. Al final se consolida en `ISSUES_SUMMARY.md`

## Dominios auditados

### Backend (NestJS + TypeORM)
- `src/auth/` — JWT, Google OAuth, guards
- `src/teams/` + `src/users/` — multi-tenant, roles
- `src/sales/` + `src/customers/` + `src/credits/` + `src/payments/`
- `src/purchases/` + `src/suppliers/`
- `src/inventory/` + `src/products/` + `src/lots/` + `src/categories/`
- `src/ai/` + `src/reminders/` + `src/analytics/` + `src/export/`
- `src/audit/` + `src/email/`

### Mobile (Flutter + Riverpod)
- Features: auth, dashboard, sales, purchases, customers, suppliers
- Features: inventory, products, lots, credits, reminders, scanner, ai_chat
- Features: settings, reports, notifications
- Shared: providers, models, widgets, router

## Prioridades de severidad
- 🔴 **CRÍTICO** — pérdida de datos, fallo de seguridad, crash
- 🟠 **ALTO** — funcionalidad rota, inconsistencia datos
- 🟡 **MEDIO** — comportamiento incorrecto, UX mala
- 🟢 **BAJO** — mejora, deuda técnica
