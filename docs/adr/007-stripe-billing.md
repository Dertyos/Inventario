# ADR-007: Stripe como Pasarela de Pagos y Billing

**Estado**: Aceptado
**Fecha**: 2026-04-03
**Contexto**: Seleccionar pasarela de pagos para monetizar la app con suscripciones recurrentes.

## Decision

Usar **Stripe Billing** como pasarela principal de pagos para suscripciones.

## Modelo de Negocio

Freemium con 4 planes de suscripcion mensual/anual:

| Plan | Precio/mes (COP) | Precio/mes (USD) |
|------|-------------------|-------------------|
| Gratis | $0 | $0 |
| Emprendedor | $49.900 | ~$12 |
| Negocio | $99.900 | ~$24 |
| Empresa | $199.900 | ~$49 |

Descuento anual: 2 meses gratis (pago de 10 meses por 12).

## Alternativas Consideradas

### 1. Wompi (Bancolombia)
- **Pro**: PSE, Nequi, Daviplata — metodos populares en Colombia
- **Pro**: Comision competitiva (2.9% + $900 COP)
- **Contra**: Solo Colombia — no escala internacionalmente
- **Contra**: Suscripciones recurrentes basicas, sin Customer Portal
- **Contra**: Documentacion y SDK menos maduros que Stripe

### 2. ePayco
- **Pro**: Popular en startups colombianas
- **Pro**: PSE y tarjetas colombianas
- **Contra**: Comision mas alta (3.49% + $900 COP)
- **Contra**: Solo Colombia
- **Contra**: SDK menos mantenido

### 3. Gumroad
- **Pro**: Setup rapido para venta de productos digitales
- **Contra**: 10% de comision (vs 2.9% de Stripe)
- **Contra**: No soporta suscripciones recurrentes nativas
- **Contra**: No acepta PSE, Nequi, Daviplata
- **Contra**: Cobra en USD (friccion para usuarios colombianos)
- **Contra**: Pensado para venta unica, no SaaS

### 4. Stripe (elegido)
- **Pro**: Stripe Billing maneja suscripciones nativamente (cobros, reintentos, facturas)
- **Pro**: Customer Portal gratuito — usuarios manejan su suscripcion sin desarrollo extra
- **Pro**: Webhooks robustos y bien documentados
- **Pro**: SDK Node.js excelente (compatible con NestJS)
- **Pro**: Cuenta desde Colombia soportada (desde 2023)
- **Pro**: Cobra en COP o USD — flexible
- **Pro**: Si la app escala fuera de Colombia, ya esta listo
- **Pro**: Comision competitiva (2.9% + $900 COP)
- **Contra**: No soporta PSE, Nequi, Daviplata (solo tarjetas)
- **Contra**: Algunos usuarios colombianos no tienen tarjeta de credito

## Plan de Mitigacion

**Fase 1 (MVP)**: Solo Stripe — la mayoria de usuarios que pagan suscripciones de apps ya tienen tarjeta.
**Fase 2 (si hay demanda)**: Agregar Wompi como complemento para PSE y Nequi, expandiendo metodos de pago.

## Implementacion Tecnica

### Backend
- Nuevo modulo `billing/` en NestJS
- Entidades: `Subscription`, `UsageRecord`
- Controller: checkout, portal, webhook, usage
- Guard: `PlanLimitGuard` valida limites por plan
- Decorator: `@RequirePlan()` para endpoints premium

### Mobile
- Pantalla de planes con carrusel
- Banner de limite alcanzado
- WebView para Stripe Checkout y Customer Portal
- Provider de suscripcion en Riverpod

### Variables de Entorno
```
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_EMPRENDEDOR_MONTHLY=price_...
STRIPE_PRICE_EMPRENDEDOR_YEARLY=price_...
STRIPE_PRICE_NEGOCIO_MONTHLY=price_...
STRIPE_PRICE_NEGOCIO_YEARLY=price_...
STRIPE_PRICE_EMPRESA_MONTHLY=price_...
STRIPE_PRICE_EMPRESA_YEARLY=price_...
```

## Consecuencias

- (+) Suscripciones recurrentes manejadas automaticamente por Stripe
- (+) Customer Portal reduce desarrollo de UI de gestion de suscripcion
- (+) Escalable globalmente sin cambios
- (+) Comisiones competitivas
- (-) No cubre PSE/Nequi (mitigado con Wompi en fase 2)
- (-) Dependencia de un proveedor externo para revenue
- (-) Requiere webhook endpoint seguro y verificacion de firmas
