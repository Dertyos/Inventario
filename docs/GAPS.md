# Gaps y Pendientes — Inventario

Documento generado a partir de auditoría exhaustiva comparando documentación vs implementación.
Última revisión: 2026-03-25

---

## Estado General: 95/100

El proyecto está en excelente estado. Backend completo, Flutter con UI para todos los módulos, CI/CD funcional, documentación actualizada.

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

## Pendientes Menores

### 1. SupplierModel incompleto (ALTO)
- **Problema**: Flutter `SupplierModel` no parsea `email`, `address`, `notes` del backend
- **Archivo**: `mobile/lib/shared/models/supplier_model.dart`
- **Impacto**: Si la API devuelve estos campos, se pierden silenciosamente

### 2. Navegación inconsistente en Flutter (ALTO)
- **Problema**: Mezcla de patrones de navegación entre pantallas
  - `sales_screen.dart` usa `context.go('/sales/new')`
  - `purchases_screen.dart` usa `context.push('/purchases/new')`
  - `credits_screen.dart` usa `Navigator.of(context).push(MaterialPageRoute(...))`
- **Estándar**: Debería ser `context.push()` para todas las pantallas modales
- **Impacto**: UX inconsistente, posibles memory leaks

### 3. TODO obsoleto en ai_chat_screen.dart (BAJO)
- **Línea 142**: `// TODO: Purchase flow when implemented`
- **Estado**: Compras YA están implementadas, el TODO es obsoleto

### 4. DEVELOPMENT.md incompleto (MEDIO)
- No menciona setup para Flutter web
- Sin sección de troubleshooting
- Sin tips de debugging específicos del proyecto

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
