# Auditoría: IA + Recordatorios + Dashboard + Analytics + Export + Email
Fecha: 2026-03-28

---

## 🔴 CRÍTICO — Export sin rate limiting (DoS)

**Archivo**: `backend/src/export/export.controller.ts:24-72`
**Descripción**: Los endpoints `/export/sales`, `/export/products`, `/export/inventory` no tienen `@Throttle()`. Un usuario puede exportar millones de registros repetidamente sin restricción.
**Impacto**: DoS contra la API, consumo extremo de CPU/memoria, posible caída del servidor. Exposición masiva de datos sensibles.
**Recomendación**: Agregar `@Throttle({ default: { limit: 10, ttl: 3600000 } })`. Implementar streaming del CSV en lugar de cargar todo en memoria.

---

## 🔴 CRÍTICO — IA no valida unit_price negativo

**Archivo**: `backend/src/ai/ai.service.ts:468-470`
**Descripción**: La cantidad se clampea a `Math.max(1, Math.min(qty, 10000))`, pero `unit_price` no tiene validación. Si Claude retorna `unit_price: -500`, la transacción se crea con monto negativo.
**Impacto**: Ventas con precios negativos registradas en el sistema. Pérdida contable.
**Recomendación**: Agregar `unit_price = Math.max(0, unit_price)` o lanzar error si `unit_price < 0`.

---

## 🔴 CRÍTICO — tool_use input sin validación de esquema

**Archivo**: `backend/src/ai/ai.service.ts:374-382`
**Descripción**: Si Claude retorna un bloque `tool_use` con campos faltantes o tipos incorrectos en `toolBlock.input`, el código lanza un error no manejado en lugar de un error descriptivo.
**Impacto**: La IA falla silenciosamente con errores genéricos. Usuario no sabe qué salió mal.
**Recomendación**: Validar `toolBlock.input` con un type guard o Zod antes de usarlo:
```typescript
const result = ParseTransactionSchema.safeParse(toolBlock.input);
if (!result.success) throw new BadRequestException('IA devolvió formato inesperado');
```

---

## 🟠 ALTO — Recordatorios con timezone UTC incorrecto

**Archivo**: `backend/src/reminders/reminders.service.ts:46-48`
**Descripción**: Las fechas se comparan como ISO strings (`split('T')[0]`), siempre en UTC. Si el servidor está en UTC y el cliente en UTC-5 (Colombia), un recordatorio del "28 de marzo" puede generarse el 27 de marzo.
**Impacto**: Recordatorios enviados un día antes o después de lo esperado.
**Recomendación**: Aceptar `tzOffset` en el endpoint de generación y ajustar las fechas de comparación al timezone local del team.

---

## 🟠 ALTO — Analytics cache no incluye teamId en clave

**Archivo**: `backend/src/analytics/analytics.controller.ts:24-34`
**Descripción**: `@CacheTTL(300000)` aplica a TODA la ruta. Si dos teams llaman al endpoint, el segundo puede recibir datos del primero cacheados. La clave de caché no incluye `teamId` ni `tzOffset`.
**Impacto**: Datos analíticos de un team visibles para otro. CRÍTICO para multi-tenant.
**Recomendación**: Remover `@CacheInterceptor` global. Implementar caché manual con clave `analytics:${teamId}:${tzOffset}:${period}`.

---

## 🟠 ALTO — IA no busca cliente/proveedor existente antes de crear transacción

**Archivo**: `backend/src/ai/ai.service.ts:411-417`
**Descripción**: Si el usuario dice "Venta a Pedro por 1000", la IA retorna `customerOrSupplier: "Pedro"` como texto. No hay búsqueda fuzzy para resolverlo a un `customerId`. La venta se crea sin customer vinculado.
**Impacto**: Ventas registradas sin cliente asociado. No aparecen en historial del cliente. Créditos no pueden vincularse.
**Recomendación**: En `parseTransaction`, hacer búsqueda fuzzy del nombre en la lista de clientes/proveedores y retornar el ID encontrado o `null`. Mostrar al usuario "¿Te refieres a Pedro García?"

---

## 🟠 ALTO — Recordatorios duplicados por race condition

**Archivo**: `backend/src/reminders/reminders.service.ts:81-91`
**Descripción**: El check de duplicado usa `findOne()` sin transacción ni lock. Dos jobs concurrentes pasan el check y ambos crean el mismo recordatorio.
**Impacto**: Cliente recibe 2 recordatorios del mismo pago.
**Recomendación**: Agregar constraint `UNIQUE(teamId, installmentId, type, scheduledDate)` en DB + `INSERT ... ON CONFLICT DO NOTHING`.

---

## 🟠 ALTO — Export carga todos los registros en memoria

**Archivo**: `backend/src/export/export.service.ts:19-49`
**Descripción**: `exportSales()` usa `.getMany()` para cargar TODOS los registros antes de generar el CSV. Con 100K ventas = 50MB+ en RAM por request.
**Impacto**: OOM (Out of Memory), timeout del request, caída del servidor.
**Recomendación**: Streamear el CSV línea por línea usando `QueryBuilder.stream()` + `Transform stream` de Node.js.

---

## 🟠 ALTO — Email sin retry ni queue

**Archivo**: `backend/src/email/email.service.ts:79-100`
**Descripción**: Si `resend.emails.send()` falla (Resend caído, timeout), solo se loguea el error. No hay retry, no hay almacenamiento del intento fallido.
**Impacto**: Usuario no recibe email de verificación. No puede activar cuenta. Pérdida silenciosa.
**Recomendación**: Crear tabla `email_queue` con `status`, `attempts`, `nextRetryAt`. Job diario reintenta emails fallidos con backoff exponencial.

---

## 🟠 ALTO — Dashboard mobile no invalida caché al crear venta

**Archivo**: `mobile/lib/features/dashboard/presentation/screens/dashboard_screen.dart:23-35`
**Descripción**: El provider cachea analytics por 5 min. Si el usuario crea una venta y vuelve al dashboard, sigue viendo "Hoy: $0".
**Impacto**: Dashboard muestra datos obsoletos después de acciones del usuario.
**Recomendación**: En `create_sale_screen.dart`, después de crear la venta exitosamente:
```dart
ref.invalidate(dashboardAnalyticsProvider(teamId));
```

---

## 🟡 MEDIO — Audit log solo registra estado "después", no "antes"

**Archivo**: `backend/src/audit/entities/audit-log.entity.ts:29`
**Descripción**: El campo `changes` almacena el body del request (valores nuevos). No hay registro de los valores anteriores.
**Impacto**: No se puede auditar "quién cambió el precio de $100 a $200". Trazabilidad incompleta para compliance.
**Recomendación**: Cambiar estructura:
```typescript
changes: {
  before: { price: 100, name: 'Producto X' },
  after:  { price: 200, name: 'Producto X' }
}
```

---

## 🟡 MEDIO — Recordatorio WhatsApp sin teléfono → sin feedback al usuario

**Archivo**: `mobile/lib/features/reminders/presentation/screens/reminders_screen.dart:303-332`
**Descripción**: Si `channel == 'whatsapp'` pero `customerPhone == null`, no aparece el botón de WhatsApp sin ninguna explicación. El usuario no sabe por qué no puede enviar.
**Impacto**: Recordatorios WhatsApp inutilizables sin feedback.
**Recomendación**: Mostrar mensaje "Teléfono no registrado — edita el cliente para habilitarlo" en lugar de silencio.

---

## 🟡 MEDIO — IA mobile no diferencia error de red vs error de Claude

**Archivo**: `mobile/lib/features/ai_chat/presentation/screens/ai_chat_screen.dart:138-159`
**Descripción**: Red caída y error de Claude API caen en el mismo `catch(e)` con mensaje genérico.
**Impacto**: Usuario no sabe si es su WiFi o el servidor.
**Recomendación**: Distinguir `DioException` (red) vs `ApiException` (servidor) y mostrar mensajes diferentes.

---

## 🟡 MEDIO — Scanner no valida barcode antes de buscar

**Archivo**: `mobile/lib/features/scanner/presentation/screens/barcode_scanner_screen.dart:49-76`
**Descripción**: Si el barcode detectado es vacío o tiene < 8 caracteres, igual hace request al servidor.
**Impacto**: Requests inútiles al servidor, posible confusión del usuario.
**Recomendación**: Validar `barcodeValue.length >= 8 && barcodeValue.isNotEmpty` antes de buscar.

---

## 🟡 MEDIO — Analytics puede tener N+1 queries en categorías

**Archivo**: `backend/src/analytics/analytics.service.ts:388`
**Descripción**: `groupBy('category.name')` sin alias explícito. En algunos joins puede agrupar incorrectamente.
**Impacto**: Datos analíticos por categoría incorrectos.
**Recomendación**: Usar `groupBy('category.id')` + `addGroupBy('category.name')`.

---

## 🟡 MEDIO — Dashboard analytics lento: sin índices para queries de período

**Archivo**: `backend/src/analytics/analytics.service.ts`
**Descripción**: Las queries de resumen filtran por `createdAt BETWEEN :start AND :end` sin índices en `createdAt`.
**Impacto**: Dashboard lento a medida que crecen los datos (>10K registros).
**Recomendación**: Agregar índice `CREATE INDEX idx_sales_created ON sales(team_id, created_at DESC)`.

---

## 🟡 MEDIO — Recordatorio para cuota ya pagada

**Archivo**: `backend/src/reminders/reminders.service.ts:51-65`
**Descripción**: Si la cuota se paga entre el select y la creación del recordatorio, se genera recordatorio innecesario.
**Impacto**: Cliente recibe recordatorio de pago ya efectuado.
**Recomendación**: Re-verificar `installment.status == PENDING` dentro del insert, no solo en el select.

---

## 🟢 BAJO — Modelo de IA hardcodeado en código

**Archivo**: `backend/src/ai/ai.service.ts:310`
**Descripción**: `DEFAULT_MODEL = 'claude-haiku-4-5-20251001'` hardcodeado. Si Anthropic depreca el modelo, requiere redeploy.
**Recomendación**: Mover a variable de entorno `ANTHROPIC_MODEL`.

---

## 🟢 BAJO — Audit log sin índices

**Archivo**: `backend/src/audit/audit.service.ts:25-37`
**Descripción**: Queries por `teamId` y `entityType` sin índices definidos.
**Recomendación**: `CREATE INDEX idx_audit_team ON audit_logs(team_id); CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);`

---

## 🟢 BAJO — Prompts de IA sin comentarios explicativos

**Archivo**: `backend/src/ai/ai.service.ts:754-810`
**Descripción**: System prompts muy largos con jerga colombiana ("luca", "barra") sin comentarios explicando las reglas.
**Recomendación**: Documentar cada sección del prompt con comentarios de código.

---

## Resumen

| Severidad | Cantidad |
|-----------|----------|
| 🔴 CRÍTICO | 3 |
| 🟠 ALTO | 7 |
| 🟡 MEDIO | 7 |
| 🟢 BAJO | 3 |
| **TOTAL** | **20** |

**Top 3:**
1. Export sin rate limiting — vulnerabilidad DoS
2. Analytics cache sin teamId — datos de un team visibles para otro
3. IA crea transacciones con precio negativo
