# Roadmap del Producto — Inventario

Plan de desarrollo y lanzamiento comercial.
Ultima actualizacion: 2026-04-03

---

## Estado Actual: v1.3.0 (98% funcional)

El producto base esta completo. Falta el sistema de monetizacion y pulir detalles para lanzamiento comercial.

---

## Fase 1: Producto Listo para Vender (Semana 1-2)

### 1.1 Sistema de Billing con Stripe (CRITICO)

**Backend — Modulo `billing/`**

| Tarea | Prioridad | Estimacion |
|-------|-----------|------------|
| Entidad `Subscription` (team_id, stripe_customer_id, plan, status, periodo) | CRITICA | 2h |
| Entidad `UsageRecord` (team_id, periodo, contadores de ventas/productos/AI) | CRITICA | 1h |
| Migracion para crear tablas `subscriptions` y `usage_records` | CRITICA | 30min |
| `BillingService` — crear customer en Stripe, crear checkout session, manejar portal | CRITICA | 4h |
| `StripeWebhookController` — procesar eventos de Stripe (payment_succeeded, subscription_updated, etc.) | CRITICA | 3h |
| `PlanLimitGuard` — middleware que valida uso vs limites del plan en cada request | CRITICA | 3h |
| Decorator `@RequirePlan('emprendedor')` para endpoints premium | ALTA | 1h |
| Constantes de planes con limites (FREE: 50 productos, 30 ventas/mes, etc.) | CRITICA | 30min |
| Tests unitarios del modulo billing | ALTA | 3h |
| Variables de entorno: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_PRICE_* | CRITICA | 30min |

**Mobile — Pantallas de Billing**

| Tarea | Prioridad | Estimacion |
|-------|-----------|------------|
| `SubscriptionScreen` — carrusel de planes con precios y features | CRITICA | 4h |
| Banner de limite alcanzado (ej: "50 productos alcanzados, mejora tu plan") | CRITICA | 2h |
| Badge de plan actual en Settings | ALTA | 1h |
| Modelo `Subscription` y provider de Riverpod | ALTA | 1h |
| Abrir Stripe Checkout en WebView o navegador externo | ALTA | 2h |
| Abrir Stripe Customer Portal para gestionar suscripcion | MEDIA | 1h |

### 1.2 Onboarding para Nuevos Usuarios (ALTO)

| Tarea | Prioridad | Estimacion |
|-------|-----------|------------|
| 3 pantallas de onboarding (bienvenida, demo IA, planes) | ALTA | 3h |
| Flag `hasCompletedOnboarding` en SharedPreferences | ALTA | 30min |
| Datos demo precargados (5 productos de ejemplo) al crear equipo | MEDIA | 2h |

### 1.3 Landing Page (ALTO)

| Tarea | Prioridad | Estimacion |
|-------|-----------|------------|
| Pagina web publica en inventario.app (Framer o Carrd) | ALTA | 4h |
| Video demo de 60 segundos | ALTA | 2h |
| Seccion de precios con tabla de planes | ALTA | 1h |
| Link a Play Store / descarga directa APK | ALTA | 30min |

### 1.4 Play Store Listing (ALTO)

| Tarea | Prioridad | Estimacion |
|-------|-----------|------------|
| Screenshots de cada pantalla principal (6-8 screenshots) | ALTA | 2h |
| Titulo y descripcion optimizada para ASO | ALTA | 1h |
| Icono y feature graphic | ALTA | 2h |
| Privacy Policy (requerido por Google) | CRITICA | 1h |
| Publicar en track interno para pruebas | ALTA | 1h |
| Publicar en produccion | ALTA | 30min |

---

## Fase 2: Validacion y Primeros Usuarios (Semana 3-4)

### 2.1 Marketing Organico

| Tarea | Canal | Frecuencia |
|-------|-------|------------|
| Videos cortos demo de la app | TikTok, Instagram Reels | 3-5/semana |
| Publicar en grupos de emprendedores | Facebook Groups | 2-3/semana |
| Publicar en comunidades tech | Reddit, foros | 1-2/semana |
| Visitar tiendas locales para ofrecer beta gratis | Presencial | 5-10 tiendas |

### 2.2 Feedback y Ajustes Rapidos

| Tarea | Prioridad |
|-------|-----------|
| Recoger feedback de beta testers (formulario in-app o WhatsApp) | ALTA |
| Corregir bugs reportados en < 48h | CRITICA |
| Ajustar UX segun feedback (terminologia, flujos confusos) | ALTA |
| Pedir reviews en Play Store a usuarios satisfechos | MEDIA |

---

## Fase 3: Primeras Ventas (Semana 5-8)

### 3.1 Publicidad Pagada

| Tarea | Presupuesto | Plataforma |
|-------|-------------|------------|
| Campana Facebook/Instagram Ads (5-7 dias) | $80.000-$160.000 COP | Meta Ads |
| Target: Colombia, 25-55 anos, emprendimiento/inventario | — | — |
| Creative: video demo 15-30s | — | — |
| Google Ads keywords de intencion alta (opcional) | $80.000-$160.000 COP | Google Ads |

### 3.2 Email Marketing

| Tarea | Prioridad |
|-------|-----------|
| Enviar oferta 50% descuento primer mes a beta testers | ALTA |
| Secuencia de onboarding por email (dia 1, 3, 7) | MEDIA |
| Pedir testimonios a usuarios activos | MEDIA |

---

## Fase 4: Escalar (Mes 3+)

### 4.1 Features Premium

| Feature | Plan | Estimacion |
|---------|------|------------|
| DIAN facturacion electronica (via Alegra REST) | Empresa | 2-3 semanas |
| Programa de referidos ("Invita amigo = 1 mes gratis") | Todos | 1 semana |
| Dashboard analytics completo en mobile (endpoints ya existen) | Negocio+ | 1 semana |
| Paginacion en listas (backend ya lo soporta) | Todos | 3 dias |
| Dark mode completo | Todos | 2 dias |

### 4.2 Expansion

| Tarea | Timeline |
|-------|----------|
| iOS App Store (ya se compila, falta publicar) | Mes 3 |
| Wompi como pasarela complementaria (PSE, Nequi) | Mes 4 |
| Expansion LATAM (Mexico, Peru, Ecuador) | Mes 6+ |
| Version web (Flutter web o Next.js) | Mes 6+ |

---

## Fase 5: Crecimiento Sostenido (Mes 6-12)

| Tarea | Tipo |
|-------|------|
| Contenido educativo (blog/YouTube sobre gestion de inventario) | SEO |
| Alianzas con contadores y asesores de pymes | Partnership |
| WhatsApp Business como canal de soporte | Retencion |
| Integracion con pasarelas de pago locales (Nequi, Daviplata) | Producto |
| Multi-idioma (espanol generico + ingles) para LATAM | Producto |

---

## Bugs Criticos a Resolver Antes de Lanzamiento

Extraidos de la auditoria (`AUDIT/ISSUES_SUMMARY.md`):

### Sprint 0 — Bloqueantes de Produccion

| Bug | Archivo | Severidad |
|-----|---------|-----------|
| CreditAccount creado fuera de transaccion | `sales.service.ts` | CRITICO |
| Cancel de compra no revierte stock | `purchases.service.ts` | CRITICO |
| creditPaidAmount sin limite superior | `sales/dto` | CRITICO |
| Export sin rate limiting | `export.controller.ts` | CRITICO |
| Analytics cache sin teamId | `analytics.controller.ts` | CRITICO |
| IA permite precio negativo | `ai.service.ts` | CRITICO |
| DateTime.parse() sin try-catch en modelos Flutter | Todos los modelos | CRITICO |
| Unsafe cast `response.data as List` | Repositorios Flutter | CRITICO |

### Sprint 0 — UX Critica

| Mejora | Archivo | Esfuerzo |
|--------|---------|----------|
| Renombrar "Contado" a "Paga hoy" / "Credito" a "Paga despues" | `create_sale_screen.dart` | 1h |
| "Venta sin cliente" como primera opcion en picker | `create_sale_screen.dart` | 30min |
| Renombrar "SKU" a "Codigo interno (opcional)" | Multiples archivos | 15min |
| Settings con secciones (Negocio, Operaciones, Analisis) | `settings_screen.dart` | 2h |
| Speed Dial FAB en dashboard (reemplazar 3 FABs apilados) | `dashboard_screen.dart` | 3h |

---

## Metricas de Exito

| Metrica | Meta Mes 1 | Meta Mes 3 | Meta Mes 6 | Meta Mes 12 |
|---------|-----------|-----------|-----------|------------|
| Descargas | 200 | 1.000 | 3.000 | 8.000 |
| Usuarios activos gratis | 50 | 300 | 800 | 2.000 |
| Conversion a pago | 3-5% | 5-8% | 8-10% | 10-12% |
| Suscriptores pagos | 2-5 | 15-40 | 60-100 | 200-300 |
| MRR (COP) | $100K-250K | $750K-2M | $3M-5M | $10M-15M |
| Churn mensual | <15% | <10% | <8% | <5% |
| Rating Play Store | 4.0+ | 4.3+ | 4.5+ | 4.5+ |
