# Plan de Correcciones UI — Inventario Mobile

Correcciones basadas en la auditoría de código fuente. Ordenadas por severidad descendente.

---

## Fixes Críticos 🔴

### Fix 1 — Speed Dial FAB (reemplaza los 3 FABs apilados)

#### [MODIFY] [dashboard_screen.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/features/dashboard/presentation/screens/dashboard_screen.dart)

Reemplazar el `Column` de 3 FABs estáticos por un Speed Dial expandible:
- Estado: `isOpen` bool en el widget
- FAB principal: ícono `add` → al abrir muestra 2 FABs pequeños con label (Scanner, Voz)
- Usar `AnimatedOpacity` + `AnimatedSlide` para aparecer/desaparecer los mini FABs
- Fondo oscuro semi-transparente (`ModalBarrier`) al abrir para dar foco

---

### Fix 2 — Settings con secciones visuales

#### [MODIFY] [settings_screen.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/features/settings/presentation/screens/settings_screen.dart)

Agrupar los 10 tiles en 3 secciones con headers:
- **Negocio**: Equipo y miembros, Configuración del equipo
- **Operaciones**: Clientes, Proveedores, Créditos, Compras, Lotes, Recordatorios
- **Análisis & Más**: Reportes, Notificaciones, Registrar con voz
- Agregar un widget `_SectionHeader` con padding y `textStyle: labelLarge`
- Corregir `'Mas'` → `'Más'` en el AppBar
- Corregir `'Cerrar sesion'` → `'Cerrar sesión'`
- Agregar leading colorizado a `_SettingsTile` (Container 36×36 con `surfaceContainerHighest`)

---

## Fixes Moderados 🟡

### Fix 3 — Hardcoded colors → AppColors tokens

#### [MODIFY] [sales_screen.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/features/sales/presentation/screens/sales_screen.dart)
#### [MODIFY] [inventory_screen.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/features/inventory/presentation/screens/inventory_screen.dart)

Reemplazar todos los `Colors.orange`, `Colors.green`, `Colors.red` por `AppColors.warning`, `AppColors.success`, `AppColors.danger`.

---

### Fix 4 — Usar StatusBadge en SalesScreen

#### [MODIFY] [sales_screen.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/features/sales/presentation/screens/sales_screen.dart)

Reemplazar los dos `Container` inline de badges (Cancelada, crédito) por `StatusBadge.danger()` y `StatusBadge.warning()` del widget compartido.

---

### Fix 5 — Inconsistencia de card border-radius (light vs dark)

#### [MODIFY] [app_theme.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/core/theme/app_theme.dart)

Unificar `cardTheme.shape` en light y dark: ambos a `borderRadius: 18`.

---

### Fix 6 — Padding inconsistente en Dashboard

#### [MODIFY] [dashboard_screen.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/features/dashboard/presentation/screens/dashboard_screen.dart)

Cambiar `horizontal: AppSpacing.md + 4` → `horizontal: AppSpacing.md` para consistencia con las demás pantallas.

---

### Fix 7 — `_SettingsTile` leading colorizado

#### [MODIFY] [settings_screen.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/features/settings/presentation/screens/settings_screen.dart)

Actualizar `_SettingsTile.build()` para envolver el `Icon` en un `Container(36×36)` con `borderRadius: 8` y color `surfaceContainerHighest`.

---

### Fix 8 — Fix navegación Clientes: `go` → `push`

#### [MODIFY] [settings_screen.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/features/settings/presentation/screens/settings_screen.dart)

Cambiar `context.go('/customers')` → `context.push('/customers')` para preservar el back stack desde Settings.

---

### Fix 9 — Tildes faltantes en Reports

#### [MODIFY] [sales_report_screen.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/features/reports/presentation/screens/sales_report_screen.dart)

Corregir literales:
- `'7 dias'` → `'7 días'`
- `'30 dias'` → `'30 días'`
- `'Ventas por dia'` → `'Ventas por día'`
- `'Metodos de pago'` → `'Métodos de pago'`
- `'Top productos'` → sin cambio (correcto)

---

## Fixes Menores 🟢

### Fix 10 — Micro-animaciones con `flutter_animate`

#### [MODIFY] [stat_card.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/shared/widgets/stat_card.dart)
#### [MODIFY] [empty_state.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/shared/widgets/empty_state.dart)

Agregar entrada animada con `flutter_animate`:
- `StatCard`: `.animate().fadeIn(duration: 300ms).slideY(begin: 0.05)`
- `EmptyState`: `.animate().fadeIn(duration: 400ms).scale(begin: Offset(0.95,0.95))`

---

### Fix 11 — Semantics labels en botones de CreateSaleScreen

#### [MODIFY] [create_sale_screen.dart](file:///Users/juliansalcedo/Desktop/code/inventario/mobile/lib/features/sales/presentation/screens/create_sale_screen.dart)

Agregar `tooltip` o `Semantics(label: ...)` a los `IconButton`s de agregar/quitar cantidad en el carrito.

---

## Verificación

### Compilación
```bash
cd /Users/juliansalcedo/Desktop/code/inventario/mobile
flutter analyze
flutter build apk --debug
```

### Tests existentes
```bash
cd /Users/juliansalcedo/Desktop/code/inventario/mobile
flutter test
```
> Solo existe `test/widget_test.dart` (smoke test del widget raíz). No hay tests unitarios de UI.

### Verificación manual (orden sugerido)
1. **Speed Dial**: Abrir la app → Dashboard → Tocar el FAB principal → Verificar que se expande mostrando Scanner y Voz con labels. Tocar fuera → cierra.
2. **Settings sections**: Ir a tab "Más" → Verificar 3 secciones con headers visibles y leading colorizado en cada tile.
3. **Tildes**: Revisar AppBar de Settings ("Más"), diálogo de logout ("Cerrar sesión"), pantalla de Reportes.
4. **Colores**: Ir a Inventario → tab Movimientos → verificar que + y - siguen el color semántico correcto. Ir a Ventas → verificar badge de "Cancelada".
5. **Micro-animaciones**: Ir a Dashboard → tirar refresh → verificar que las StatCards aparecen con fadeIn.
6. **Navegación Clientes**: Ir a Más → Clientes → presionar back → debe volver a Más (no a Dashboard).
