# Auditoría: Mobile Flutter — Arquitectura + Providers + Routing
Fecha: 2026-03-28

---

## 🔴 CRÍTICO — DateTime.parse() sin try-catch en modelos

**Archivo**: `mobile/lib/shared/models/credit_model.dart:102-103`, `sale_model.dart:81`, `product_model.dart:54`
**Descripción**: Se usa `DateTime.parse()` directamente en `fromJson()`. Si el backend envía un formato de fecha inválido o null inesperado, la app crasha con `FormatException`.
**Impacto**: Crash al cargar cualquier lista de ventas, créditos o productos.
**Recomendación**: Reemplazar por `DateTime.tryParse(val) ?? DateTime.now()` o envolver en try-catch. Idealmente crear helper:
```dart
static DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  try { return DateTime.parse(v as String); } catch (_) { return null; }
}
```

---

## 🔴 CRÍTICO — Unsafe cast `response.data as List` en repositorios

**Archivo**: `mobile/lib/features/sales/data/sales_repository.dart:35`, `credits_repository.dart:57-59`, `auth_repository.dart:69`
**Descripción**: `(response.data as List)` sin validación previa. Si el backend retorna un objeto (ej. `{error: "..."}`) en lugar de una lista, la app crasha con `TypeError`.
**Impacto**: Crash al cargar ventas, créditos, o listas de teams.
**Recomendación**:
```dart
final list = response.data;
if (list is! List) throw ApiException('Respuesta inesperada del servidor');
```

---

## 🔴 CRÍTICO — AuthInterceptor: race condition en manejo de 401

**Archivo**: `mobile/lib/core/network/api_interceptor.dart:27-29`
**Descripción**: El token se borra pero el estado de sesión no se limpia de forma síncrona antes de que el error llegue al handler. Puede haber requests concurrentes que no detectan el 401 limpiamente.
**Impacto**: Pantallas en estado inconsistente tras expiración de sesión. Usuario puede quedar "logueado" visualmente pero sin token.
**Recomendación**: Usar un `Completer` para serializar el logout: todas las requests en vuelo deben esperar el logout antes de redirigir.

---

## 🔴 CRÍTICO — Pending sales perdidas en crash de dispositivo

**Archivo**: `mobile/lib/features/sales/data/pending_sales_service.dart:27-38`
**Descripción**: Las ventas pendientes se guardan en `SharedPreferences` sin backup ni UUID de deduplicación. Un crash del dispositivo puede corromper las ventas pendientes.
**Impacto**: Pérdida de datos de ventas offline. Sin forma de recuperación.
**Recomendación**: Usar SQLite (via `sqflite`) para persistir ventas offline. Agregar UUID único por venta pendiente para evitar duplicados al re-sincronizar.

---

## 🟠 ALTO — Memory leak: cacheFor en providers autoDispose con múltiples teams

**Archivo**: `mobile/lib/features/dashboard/presentation/screens/dashboard_screen.dart:24-25`
**Descripción**: Providers con `autoDispose.family` + `ref.cacheFor(5.minutes)` mantienen datos en memoria para cada `teamId` distinto. Si el usuario cambia de team varias veces, los datos de todos los teams quedan en memoria.
**Impacto**: Consumo creciente de RAM. En dispositivos de gama baja, el SO puede matar la app.
**Recomendación**: Al hacer logout o cambiar de team, invalidar explícitamente todos los providers con familia:
```dart
ref.invalidate(dashboardAnalyticsProvider);
ref.invalidate(salesProvider);
// etc.
```

---

## 🟠 ALTO — GoRouter force unwrap sin validación de parámetros

**Archivo**: `mobile/lib/core/router/app_router.dart:120, 150, 170, 209, 230, 275`
**Descripción**: `state.pathParameters['id']!` usa `!` sin null check. Si alguien navega a `/products//edit`, `id` es null → crash.
**Impacto**: Crash al navegar a rutas con parámetros mal formados.
**Recomendación**: Siempre validar:
```dart
final id = state.pathParameters['id'];
if (id == null || id.isEmpty) return const ErrorScreen();
```

---

## 🟠 ALTO — sync_service swallows errores silenciosamente

**Archivo**: `mobile/lib/features/sales/data/sync_service.dart:40, 61`
**Descripción**: `catch (_) { }` — errores de sincronización se descartan sin notificar al usuario ni logguear.
**Impacto**: Ventas offline pueden nunca sincronizarse sin que el usuario lo sepa.
**Recomendación**: Loguear errores. Si 3 reintentos fallan, notificar al usuario con opción de "Revisar ventas pendientes".

---

## 🟠 ALTO — CreateSaleScreen: múltiples métodos de pago sin validación de total

**Archivo**: `mobile/lib/features/sales/presentation/screens/create_sale_screen.dart:38-58`
**Descripción**: El usuario puede ingresar pagos en efectivo + tarjeta + transferencia que sumen más que el total. No hay validación de que `sum(payments) >= total`.
**Impacto**: Venta creada con "vuelto" negativo. Inconsistencia contable.
**Recomendación**: Calcular en tiempo real `balance = total - sum(payments)` y mostrarlo. Deshabilitar "Crear venta" si `balance < 0`.

---

## 🟠 ALTO — authRepository.getTeams() cast inseguro

**Archivo**: `mobile/lib/features/auth/data/auth_repository.dart:69`
**Descripción**: `.cast<Map<String, dynamic>>()` sobre el response sin validar que sea efectivamente una lista de mapas.
**Impacto**: Crash al cargar la pantalla de selección de teams.
**Recomendación**: Validar tipo antes del cast.

---

## 🟡 MEDIO — pendingSalesCount no se invalida al crear venta

**Archivo**: `mobile/lib/features/sales/presentation/screens/create_sale_screen.dart:394`
**Descripción**: Después de crear venta exitosamente, solo se invalida `salesProvider`. El counter de ventas pendientes en el dashboard no se actualiza.
**Impacto**: Dashboard muestra badge de ventas pendientes desfasado.
**Recomendación**: Invalidar también `dashboardProvider(teamId)` después de crear venta.

---

## 🟡 MEDIO — Mensajes de error crudos mostrados al usuario

**Archivo**: `mobile/lib/features/sales/presentation/screens/create_sale_screen.dart:404`
**Descripción**: `ScaffoldMessenger.showSnackBar(Text(e.toString()))` muestra errores técnicos como "Exception: DioException [type: BadResponse]..." al usuario.
**Impacto**: UX terrible. Usuario no entiende qué falló.
**Recomendación**: Mapear excepciones a mensajes legibles:
```dart
String _friendlyError(Object e) {
  if (e is ApiException) return e.message;
  if (e is DioException && e.type == DioExceptionType.connectionError)
    return 'Sin conexión. Verifica tu internet.';
  return 'Ocurrió un error. Intenta de nuevo.';
}
```

---

## 🟡 MEDIO — Timeout de Dio demasiado largo (60s)

**Archivo**: `mobile/lib/core/config/app_config.dart:17-18`
**Descripción**: Timeout de 60s es excesivo para mobile. Con 3 reintentos (4s + 8s + 16s = 28s), puede tardar 88s antes de mostrar error.
**Impacto**: UX bloqueante. Usuario espera hasta 1.5 minutos sin feedback.
**Recomendación**: Reducir timeout a 15-20s. Mostrar indicador de progreso si >3s.

---

## 🟡 MEDIO — OfflineBanner existe pero botones siguen habilitados offline

**Archivo**: `mobile/lib/features/dashboard/presentation/screens/dashboard_screen.dart`
**Descripción**: El banner de offline se muestra pero los botones de acción siguen habilitados. El usuario puede intentar crear ventas sin conexión que no sincronizarán correctamente.
**Impacto**: Confusión sobre estado offline. Operaciones quedan en limbo.
**Recomendación**: Deshabilitar botones de acciones que requieren red cuando está offline, o mostrar modal explicativo.

---

## 🟡 MEDIO — Empty catch en auth_provider swallows error de permisos

**Archivo**: `mobile/lib/shared/providers/auth_provider.dart:102`
**Descripción**: `catch (_) { return const []; }` al cargar permisos. Si falla la carga de permisos, el usuario queda sin permisos sin saber por qué (UI puede estar bloqueada sin explicación).
**Impacto**: Funcionalidades deshabilitadas silenciosamente.
**Recomendación**: Loguear el error. Mostrar banner "No se pudieron cargar tus permisos" con opción de retry.

---

## 🟡 MEDIO — CacheFor de 5 min puede mostrar datos obsoletos

**Archivo**: `mobile/lib/features/dashboard/presentation/screens/dashboard_screen.dart:25`
**Descripción**: El caché de 5 minutos puede ser demasiado corto en conexiones lentas y demasiado largo para negocios con alta actividad. No hay indicador de "datos de hace X minutos".
**Impacto**: Usuario toma decisiones de stock basadas en datos de hace 5 min.
**Recomendación**: Mostrar timestamp de última actualización. Permitir pull-to-refresh en dashboard.

---

## 🟢 BAJO — Color WhatsApp hardcodeado (#25D366)

**Archivo**: `mobile/lib/features/dashboard/presentation/screens/dashboard_screen.dart:244`, líneas similares en reminders_screen.dart
**Descripción**: Color `Color(0xFF25D366)` hardcodeado en múltiples lugares en lugar de una constante central.
**Recomendación**: Definir `const kWhatsAppGreen = Color(0xFF25D366)` en `app_theme.dart`.

---

## 🟢 BAJO — Formularios sin validación de valores negativos en precios

**Archivo**: `mobile/lib/features/sales/presentation/screens/create_sale_screen.dart`
**Descripción**: El diálogo de edición de precio no valida que el valor sea >= 0. Un usuario puede ingresar `-500`.
**Recomendación**: Agregar `if (value < 0) return;` antes de actualizar precio.

---

## 🟢 BAJO — Sin logging de errores en producción

**Archivo**: Todo el proyecto mobile
**Descripción**: No hay integración con Sentry, Firebase Crashlytics, ni ninguna herramienta de crash reporting.
**Impacto**: Los crashes en producción son invisibles. Debug imposible sin acceso al dispositivo.
**Recomendación**: Integrar `sentry_flutter` o `firebase_crashlytics`. Configurar en `main.dart`.

---

## 🟢 BAJO — Sin i18n: mensajes hardcodeados en español

**Archivo**: Todo el proyecto mobile
**Descripción**: Todos los mensajes de error, labels y textos están hardcodeados en español. Si la app se expande a otros mercados, requiere refactor masivo.
**Recomendación**: Crear `lib/l10n/` con archivos de traducción. Usar `flutter_localizations`.

---

## ✅ Fortalezas detectadas

- Clean architecture: Repository → Provider → Screen bien separados
- `flutter_secure_storage` con `encryptedSharedPreferences` para tokens
- Riverpod `.family` con teamId para aislamiento multi-tenant
- RBAC implementado en UI: botones con `permissionProvider`
- Offline support con queue de ventas pendientes
- Pull-to-refresh implementado en la mayoría de listas
- `autoDispose` correctamente para recursos pesados

---

## Resumen

| Severidad | Cantidad |
|-----------|----------|
| 🔴 CRÍTICO | 4 |
| 🟠 ALTO | 5 |
| 🟡 MEDIO | 7 |
| 🟢 BAJO | 5 |
| **TOTAL** | **21** |

**Top 5 más urgentes:**
1. `DateTime.parse()` sin try-catch → crash al cargar datos
2. Unsafe cast `response.data as List` → crash en listados
3. AuthInterceptor race condition → estado inconsistente
4. Pending sales en SharedPreferences → pérdida de datos
5. Mensajes de error crudos → UX terrible
