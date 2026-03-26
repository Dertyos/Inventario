# 📱 UI Audit — Inventario Mobile App
> Basado en lectura directa del código fuente · Marzo 2026

---

## 1. Tech Stack & Dependencias UI

| Categoría | Librería |
|---|---|
| UI framework | Flutter 3 + Material 3 (`useMaterial3: true`) |
| Tipografía | `google_fonts: ^8.0.2` → **Inter** (weights 400–700) |
| Animaciones | `flutter_animate: ^4.5.2`, `shimmer: ^3.0.0` |
| Gráficas | `fl_chart: ^1.2.0` |
| SVG / Imágenes | `flutter_svg: ^2.0.17`, `cached_network_image: ^3.4.1` |
| Estado | `flutter_riverpod: ^3.1.0` |
| Routing | `go_router: ^17.1.0` |
| Voz | `speech_to_text: ^7.0.0` |
| Scanner | `mobile_scanner: ^7.0.0` |
| Sharing | `share_plus: ^10.0.0` |

> **Nota:** `flutter_animate` y `shimmer` están instalados pero **se usan muy poco**. No se encontró ningún uso de `flutter_animate` en las pantallas auditadas.

---

## 2. Sistema de Diseño (`core/theme/app_theme.dart`)

### Paleta de colores

| Token | Hex | Uso |
|---|---|---|
| `_primarySeed` | `#4F6BF6` | Color primario (azul índigo) |
| `_secondarySeed` | `#2ECC71` | Color secundario (verde éxito) |
| `_tertiarySeed` | `#FF9F43` | Color terciario (naranja advertencia) |
| `_errorSeed` | `#EB4D4B` | Color de error (rojo) |
| `AppColors.success` | `#2ECC71` | Badges, estados positivos |
| `AppColors.warning` | `#FF9F43` | Stock bajo, créditos pendientes |
| `AppColors.danger` | `#EB4D4B` | Error, cancelaciones |
| `AppColors.info` | `#4F6BF6` | Información (= primario) |

> ⚠️ **Problema WCAG**: `#4F6BF6` sobre blanco tiene ratio ~4.6:1 — pasa AA solo. Para texto pequeño se recomienda >4.5:1 (justo al límite).

### Tipografía
- **Fuente**: Inter (Google Fonts) en todos los niveles del `TextTheme`.
- Pesos: `w400` (body), `w500`(labels/titles), `w600` (headlines), `w700` (displays).
- **Gap**: No se usa ningún `displayLarge/Medium` en las pantallas actuales — las pantallas usan `headlineLarge` para revenue y `titleLarge` para greetings.

### Espaciado (`AppSpacing`)
```
xs=4 · sm=8 · md=16 · lg=24 · xl=32 · xxl=48
```
El padding estándar entre secciones del dashboard es `AppSpacing.lg` (24px) — **correcto**.

### Dimensiones
```
touchTarget=48  buttonHeight=52  avatarSm=36  avatarMd=40  avatarLg=44
radiusXs=6  radiusSm=8  radiusMd=12  radiusLg=16  radiusXl=20  radiusFull=24
```

### Cards
- Elevación 0 + borde gris sutil (`Colors.grey.shade200 @ 70%`) en light.
- `border-radius: 18px` (light) / `16px` (dark) — ⚠️ **inconsistente** entre temas.
- `clipBehavior: Clip.antiAlias` — correcto.

### Animaciones
- `AppAnimations.fast=150ms`, `normal=300ms`, `slow=500ms`, curve `easeInOut`.
- Solo `_WaterDropNavBar` y el `AnimatedSwitcher` del shell usan estas curvas.

---

## 3. Navegación (`shared/widgets/app_shell.dart`)

### Bottom Navigation
- **5 tabs**: Inicio, Productos, Ventas, Inventario, Más.
- Implementación custom: `_WaterDropNavBar` con "pill" deslizante animado (lead + follow controllers, 260ms/360ms).
- Transición de página: `AnimatedSwitcher` con `FadeTransition` + `SlideTransition` (offset 0.03 vertical, 180ms). ✅ Bien.
- El tab **Más** lleva a `SettingsScreen` que lista 10+ items sin agrupación.

### Issues de navegación encontrados
| Issue | Archivo | Severidad |
|---|---|---|
| AppBar de Settings dice `'Mas'` (sin tilde) | `settings_screen.dart:178` | 🟢 Menor |
| Dialog de logout dice `'Cerrar sesion?'` (sin tilde) | `settings_screen.dart:351` | 🟢 Menor |
| `SettingsScreen` tiene 10 opciones sin secciones/headers | `settings_screen.dart:274-341` | 🟡 Moderado |
| Clientes en Settings usa `context.go()` (rompe back stack) en lugar de `push()` | `settings_screen.dart:292` | 🟡 Moderado |

---

## 4. Dashboard (`features/dashboard/presentation/screens/dashboard_screen.dart`)

### Estructura
```
AppBar (saludo + nombre del negocio)
  OfflineBanner (condicional)
  RefreshIndicator
    ListView
      HeroMetricCard (ingresos del día + mini sparkline)
      GridView 2×2 (StatCards)
      LowStockSection (condicional, max 3)
      RecentSalesSection (lista)
  FAB Column (3 botones apilados)
```

### 3 FABs apilados — Problema Crítico 🔴
```dart
// dashboard_screen.dart:268-294
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    FloatingActionButton.small(heroTag: 'scanner', ...),     // Scanner QR
    SizedBox(height: AppSpacing.sm),
    FloatingActionButton.small(heroTag: 'voice', ...),        // Voz
    SizedBox(height: AppSpacing.sm),
    FloatingActionButton.extended(heroTag: 'sale', ...),      // Nueva venta
  ],
)
```
**UX**: Los 3 FABs compiten con el contenido, cubren items de la lista y confunden el CTA principal. El patrón "Speed Dial" o FAB expandible resuelve esto.

### Hero Metric Card — Bien ✅
- Muestra revenue del día con `MiniLineChart` sparkline de 7 días.
- `headlineLarge` + `letterSpacing: -1` — tipografía moderna correcta.

### Stats Grid — Bien ✅
- 2×2, `StatCard` con `childAspectRatio: 1.0`.
- Colores semánticos por tarjeta.
- `onTap` → navegación correcta.

### Padding inconsistente 🟡
```dart
// dashboard_screen.dart:97 — padding: horizontal: md+4 = 20px
padding: EdgeInsets.symmetric(horizontal: AppSpacing.md + 4, ...)
// vs. products_screen.dart:138 — padding: all(md) = 16px
padding: EdgeInsets.all(AppSpacing.md)
```

---

## 5. Pantalla de Productos (`features/products/presentation/screens/products_screen.dart`)

### Estructura
```
AppBar (Productos + acción Scanner)
  AppSearchField
  FilterChips (categorías, scroll horizontal)
  ListView.builder
    Card > ListTile
      Leading: Container 44×44 con inicial del nombre
      Title: nombre
      Subtitle: precio + StatusBadge(stock)
      Trailing: chevron_right
  FAB (add) — condicionado por permiso
```

### Issues
| Issue | Línea | Severidad |
|---|---|---|
| Avatar usa solo la primera letra del nombre — no hay imagen | L.153 | 🟢 Menor |
| Sin animación en transición de filtro de categorías | — | 🟢 Menor |
| `AppSearchField` no tiene control de estado externo (no reactivo) | `app_search_field.dart` | 🟡 Moderado |
| No hay búsqueda por precio ni filtro de rango de stock | — | 🟡 Moderado |

---

## 6. Pantalla de Ventas (`features/sales/presentation/screens/sales_screen.dart`)

### Estructura
```
AppBar (Ventas)
  ListView.builder (agrupado por fecha)
    Cada grupo:
      Header: fecha + total del día
      Cards: ListTile con icon, monto, estado, cliente, hora
  FAB extended (Nueva venta)
```

### Badges inline hardcoded 🟡
```dart
// sales_screen.dart:127-147 — Container hardcoded en lugar de StatusBadge
Container(
  decoration: BoxDecoration(color: colorScheme.errorContainer, ...),
  child: Text('Cancelada', style: ...labelSmall?.copyWith(color: onErrorContainer)),
)
```
Existe el widget `StatusBadge` pero no se usa aquí. Duplicación de código.

### Colors.orange hardcodeado 🟡
```dart
// sales_screen.dart:98,112,157,158,170,171,203,204
Colors.orange.withValues(alpha: 0.15) // en lugar de AppColors.warning
Colors.green.withValues(alpha: 0.15)  // en lugar de AppColors.success
```

---

## 7. Crear Venta (`features/sales/presentation/screens/create_sale_screen.dart`) — 809 líneas

### Estructura
```
AppBar (Nueva venta)
  Column:
    [1] Customer picker (InputDecorator + BottomSheet)
    [2] Expanded: ProductList (ListView.builder, dense)
    [3] Cart panel (Container con rounded top corners):
        Drag handle
        Cart items (ConstrainedBox maxHeight:180)
        SegmentedButton: Contado | Crédito
        if Contado: Row(Efectivo, Tarjeta, Transferencia) + mensaje vuelto
        if Crédito: Cuotas, Interés, Frecuencia, Fecha, Abono
        Footer: Total + FilledButton "Cobrar"
```

### Fortalezas ✅
- Lógica de pago mixto (efectivo + tarjeta + transferencia) con indicador de vuelto.
- Crédito completo con cuotas, interés, frecuencia y fecha de próximo pago.
- Offline fallback: guarda en local y notifica.
- Confirmación antes de guardar.

### Issues 🔴🟡
| Issue | Línea | Severidad |
|---|---|---|
| Screen de 809 líneas — todo en un solo `State` | — | 🟡 Moderado |
| `ConstrainedBox(maxHeight: 180)` para el carrito — muy poco espacio | L.472 | 🟡 Moderado |
| Carrito con `ListView.builder` dentro de `Column` sin separación visual clara | — | 🟡 Moderado |
| Sin animación de entrada del item al agregar al carrito | — | 🟢 Menor |
| `colors: Colors.black.withValues()` hardcodeado en sombra del carrito | L.429 | 🟢 Menor |

---

## 8. Inventario (`features/inventory/presentation/screens/inventory_screen.dart`) — 652 líneas

### Estructura
```
AppBar (Inventario + TabBar: Movimientos | Stock bajo)
  TabBarView:
    _MovementsTab: ListView con Cards
    _LowStockTab: ListView con Cards + LinearProgressIndicator
  FAB: (añadir movimiento)
```

### Fortalezas ✅
- `LinearProgressIndicator` en `LowStockTab` para visualizar stock/mínimo — buen touch visual.
- `SegmentedButton` para tipo de movimiento (Entrada/Salida/Ajuste).
- Creación inline de proveedor desde el mismo flow.

### Issues 🟡🟢
| Issue | Línea | Severidad |
|---|---|---|
| `Colors.green/red` hardcodeados en vez de `AppColors.success/danger` | L.513-520, 540 | 🟡 Moderado |
| `Colors.orange` hardcodeado en LowStockTab | L.617-628 | 🟡 Moderado |
| Modal con lógica profunda (3 niveles de BottomSheet) | L.111-390 | 🟡 Moderado |

---

## 9. Settings / Más (`features/settings/presentation/screens/settings_screen.dart`) — 420 líneas

### Estructura
```
AppBar ('Mas') — sin tilde
  ListView:
    UserCard (avatar, nombre, email)
    TeamCard (tienda, moneda, # equipos — tap para switcher)
    [10 _SettingsTile items sin separación]:
      Equipo y miembros
      Configuración del equipo
      Clientes
      Proveedores
      Créditos
      Compras
      Lotes
      Notificaciones
      Recordatorios de pago
      Reportes
      Registrar con voz
    OutlinedButton cerrar sesión
    Versión de la app
```

### Issues 🔴🟡
| Issue | Línea | Severidad |
|---|---|---|
| 10 tiles sin headers/secciones — difícil de escanear | L.274-341 | 🔴 Crítico |
| Título `'Mas'` sin tilde ni ñ | L.178 | 🟢 Menor |
| `'Cerrar sesion?'` sin tilde (2x) | L.351, 368 | 🟢 Menor |
| `_SettingsTile` no tiene leading colorizado (solo Icon sin container) | L.410 | 🟡 Moderado |
| Reportes y Créditos enterrados en la lista — funciones de alto valor poco visibles | — | 🔴 Crítico |

---

## 10. Reportes (`features/reports/presentation/screens/sales_report_screen.dart`) — 689 líneas

### Estructura
```
AppBar (Reportes + PopupMenu: Exportar CSV | WhatsApp)
  Period chips row (7 días, 30 días, Este mes)
  RefreshIndicator > _ReportBody:
    HeroCard (total revenue + % cambio)
    LineChart (ventas por día, fl_chart)
    BarChart (top 5 productos)
    PaymentMethodsBar (barra segmentada + leyenda)
```

### Fortalezas ✅
- Exportación CSV + compartir por WhatsApp — features diferenciadores.
- `fl_chart` con tooltips y gradiente bajo la línea.
- `AnimatedContainer` en los chips de período.
- Comparación con período anterior (% change).

### Issues 🟡
| Issue | Línea | Severidad |
|---|---|---|
| Periodos fijos (7d, 30d, mes actual) — no hay rango custom | L.15-43 | 🟡 Moderado |
| `'7 dias'`, `'30 dias'` sin tilde | L.117, 125 | 🟢 Menor |
| `'Ventas por dia'`, `'Top productos'`, `'Metodos de pago'` sin tildes | L.364, 378, 392 | 🟢 Menor |
| Chart sin loading state propio — solo el spinner general del provider | — | 🟢 Menor |

---

## 11. Widgets Compartidos (`shared/widgets/`)

| Widget | Archivo | Uso | Issues |
|---|---|---|---|
| `AppShell` | `app_shell.dart` | Shell principal + WaterDrop nav | ✅ Ninguno |
| `StatCard` | `stat_card.dart` | Cards de métricas 2×2 | ✅ Ninguno |
| `EmptyState` | `empty_state.dart` | Estados vacíos en todas las listas | Solo icono genérico, sin ilustraciones |
| `StatusBadge` | `status_badge.dart` | Badges de estado | ✅ Bien — usa color+texto (WCAG) |
| `AppSearchField` | `app_search_field.dart` | Búsqueda en listas | No controlado externamente, no soporta filtros avanzados |
| `OfflineBanner` | `offline_banner.dart` | Banner offline/sync | ✅ Bien |
| `AppListTile` | `app_list_tile.dart` | ListTile custom | No auditado en detalle |
| `MiniLineChart` | `mini_line_chart.dart` | Sparkline en dashboard | ✅ Bien |
| `AppModal` | `app_modal.dart` | Modal genérico | No auditado en detalle |

---

## 12. Assets

```yaml
# pubspec.yaml:86-88
flutter:
  assets:
    - assets/images/
    - assets/icons/
```

> 🔴 **Carpetas vacías** — No hay ninguna imagen ni ícono personalizado en el proyecto. Todos los avatars usan la inicial del nombre con un `Container` colorizado.

---

## 13. Resumen de Issues por Severidad

### 🔴 Crítico (bloqueante de UX)
1. **3 FABs apilados** en Dashboard — confunde el CTA principal y tapa contenido.
2. **Settings sin secciones** — 10 tiles planos sin headers, funciones clave (Reportes, Créditos) enterradas.
3. **Assets vacíos** — Sin ilustraciones: EmptyStates genéricos, avatars solo con letra.

### 🟡 Moderado (degradación de experiencia)
4. **`Colors.orange`/`green`/`red` hardcoded** en Ventas e Inventario — en lugar de `AppColors.*`.
5. **`StatusBadge` no usado** en `sales_screen.dart` — lógica de badge duplicada inline.
6. **Inconsistencia de card border-radius** — 18px light vs 16px dark, padding `md+4` vs `md`.
7. **Create Sale pantalla de 809 líneas** — todo en un solo `State`, carrito con altura limitada 180px.
8. **Settings `_SettingsTile`** sin leading colorizado/iconos diferenciados.
9. **Clientes usa `context.go()` en vez de `context.push()`** en Settings.
10. **`AppSearchField`** sin control externo ni filtros avanzados.

### 🟢 Menor (polish)
11. Tildes faltantes: `'Mas'`, `'Cerrar sesion'`, `'7 dias'`, `'30 dias'`, `'Ventas por dia'`, `'Metodos de pago'`, `'Top productos'`.
12. `card border-radius` 18px light vs 16px dark.
13. `flutter_animate` instalado pero sin usar — oportunidad de micro-animaciones.
14. Sin `Semantics` label en `IconButton`s de la pantalla de nueva venta.

---

## 14. Comparación con Tendencias 2026 (SaaS/B2B Mobile)

| Tendencia 2026 | Estado actual | Brecha |
|---|---|---|
| Speed Dial / FAB expandible | 3 FABs estáticos apilados | 🔴 |
| Onboarding contextual (coachmarks) | No existe | 🔴 |
| Dashboard drill-down interactivo | Cards static, no clickeable en el hero | 🟡 |
| Período custom en reportes | Solo 3 opciones fijas | 🟡 |
| Ilustraciones contextuales (empty states) | Solo iconos genéricos | 🔴 |
| Micro-animaciones con propósito | `flutter_animate` instalado, sin uso | 🟡 |
| Dark mode token-based | ✅ Implementado | ✅ |
| Tipografía moderna (Inter) | ✅ Inter en todo el app | ✅ |
| Bottom navigation con animación | ✅ WaterDrop pill | ✅ |
| Voice input | ✅ speech_to_text integrado | ✅ |
| Barcode scanner | ✅ mobile_scanner integrado | ✅ |
| Offline-first | ✅ Banner + queue local | ✅ |
| Export / Share CSV, WhatsApp | ✅ Implementado en Reportes | ✅ |
