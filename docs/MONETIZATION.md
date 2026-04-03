# Estrategia de Monetización — Inventario

Documento de referencia para la estrategia comercial, modelo de negocio y plan de ventas.
Última actualización: 2026-04-03

---

## Modelo de Negocio: SaaS Freemium con Suscripción Mensual

La app es **gratuita para descargar y usar** con funcionalidades limitadas. La monetización se logra con planes de suscripción que desbloquean capacidad y features premium.

### ¿Por qué Freemium?

1. **Reduce fricción**: El usuario prueba sin pagar → construye confianza → paga cuando ve valor
2. **Validado**: Es el modelo dominante en apps de gestión (Alegra, Siigo, Loyverse, Square)
3. **Genera base de usuarios**: Cada usuario gratis es un potencial cliente pagado y un canal de referidos
4. **SEO/ASO orgánico**: Más descargas = mejor ranking en Play Store/App Store

---

## Planes y Precios

| Característica | Gratis | Emprendedor | Negocio | Empresa |
|----------------|--------|-------------|---------|---------|
| **Precio/mes (COP)** | $0 | $49.900 | $99.900 | $199.900 |
| **Precio/mes (USD)** | $0 | ~$12 | ~$24 | ~$49 |
| Usuarios | 1 | 3 | 10 | Ilimitado |
| Productos | 50 | 500 | Ilimitado | Ilimitado |
| Ventas/mes | 30 | Ilimitado | Ilimitado | Ilimitado |
| Asistente IA (voz/texto) | — | 20 comandos/día | 100 comandos/día | Ilimitado |
| Créditos/fiado | 5 activos | Ilimitado | Ilimitado | Ilimitado |
| Export CSV | — | Ventas | Todo | Todo |
| Reportes/Analytics | Básico | Completo | Completo + historial | Completo + historial |
| Escaneo código barras | Sí | Sí | Sí | Sí |
| Modo offline | Sí | Sí | Sí | Sí |
| Lotes con vencimiento | — | Sí | Sí | Sí |
| Recordatorios WhatsApp | — | Sí | Sí | Sí |
| Roles y permisos | — | — | Sí | Sí |
| Auditoría | — | — | Sí | Sí |
| DIAN facturación electrónica | — | — | — | Sí |
| Soporte | Comunidad | Email (48h) | Email (24h) + WhatsApp | Prioritario + onboarding |
| **Descuento anual** | — | 2 meses gratis | 2 meses gratis | 2 meses gratis |

### Justificación de precios

- **Emprendedor ($49.900)**: Menos que un almuerzo ejecutivo. Compite con Alegra ($79.900) y Siigo ($89.900) siendo más económico
- **Negocio ($99.900)**: Para negocios con empleados. Aún más barato que la competencia
- **Empresa ($199.900)**: DIAN integrado justifica el precio. Competencia cobra $200.000-$400.000

### Métricas de conversión esperadas

| Métrica | Mes 1 | Mes 3 | Mes 6 | Mes 12 |
|---------|-------|-------|-------|--------|
| Descargas totales | 200 | 1.000 | 3.000 | 8.000 |
| Usuarios activos (gratis) | 50 | 300 | 800 | 2.000 |
| Conversión a pago | 3-5% | 5-8% | 8-10% | 10-12% |
| Suscriptores pagos | 2-5 | 15-40 | 60-100 | 200-300 |
| MRR (COP) | $100K-250K | $750K-2M | $3M-5M | $10M-15M |
| Churn mensual | <15% | <10% | <8% | <5% |
| Reviews Play Store | 10+ | 50+ | 100+ | 300+ |

---

## Pasarela de Pago: Stripe

### ¿Por qué Stripe?

| Criterio | Stripe | Wompi | ePayco | Gumroad |
|----------|--------|-------|--------|---------|
| Suscripciones recurrentes | Nativo (Billing) | Básico | Básico | No aplica (venta única) |
| Tarjetas internacionales | Sí | Sí | Sí | Sí |
| PSE / Nequi / Daviplata | No | Sí | Sí | No |
| Cuenta desde Colombia | Sí (desde 2023) | Sí | Sí | Sí (USD) |
| SDK Node.js | Excelente | Bueno | Bueno | Limitado |
| Webhooks | Robustos | Básicos | Básicos | Básicos |
| Customer Portal | Incluido gratis | No | No | No |
| Documentación | Mejor del mercado | Buena | Buena | Básica |
| Escalabilidad global | Total | Solo Colombia | Solo Colombia | Global pero limitado |
| Comisión Colombia | 2.9% + $900 COP | 2.9% + $900 COP | 3.49% + $900 COP | 10% |

### Decisión

**Fase 1 (MVP)**: Solo Stripe — cubre tarjetas de crédito/débito y suscripciones.
**Fase 2 (si hay demanda)**: Agregar Wompi como complemento para PSE, Nequi y Daviplata.

**Razones:**
- Stripe Billing maneja automáticamente: cobros recurrentes, reintentos, facturas, upgrades/downgrades
- El Customer Portal (gratuito) permite al usuario manejar su suscripción sin desarrollo adicional
- Si la app escala fuera de Colombia (LATAM, España), Stripe ya está listo
- La mayoría de usuarios que pagan suscripciones de apps ya tienen tarjeta

### Qué NO usar

- **Gumroad**: Cobra 10% de comisión, no soporta suscripciones recurrentes nativas, no acepta PSE/Nequi, está pensado para productos digitales de venta única
- **PayU**: Comisiones más altas, SDK menos moderno, webhooks menos confiables

---

## Implementación Técnica del Billing

### Módulo `billing/` (Backend - NestJS)

```
backend/src/billing/
├── billing.module.ts
├── billing.controller.ts          # Endpoints de planes y suscripción
├── billing.service.ts             # Lógica de Stripe
├── stripe-webhook.controller.ts   # Webhooks de Stripe
├── guards/
│   └── plan-limit.guard.ts        # Middleware que valida uso vs plan
├── decorators/
│   └── require-plan.decorator.ts  # @RequirePlan('emprendedor')
├── entities/
│   ├── subscription.entity.ts     # Suscripción del equipo
│   └── usage.entity.ts            # Tracking de uso (ventas, productos, etc.)
├── dto/
│   ├── create-checkout.dto.ts
│   └── update-subscription.dto.ts
└── billing.constants.ts           # Definición de planes y límites
```

### Nuevas tablas en PostgreSQL

```sql
-- Suscripción del equipo
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES teams(id) NOT NULL UNIQUE,
  stripe_customer_id VARCHAR(255) NOT NULL,
  stripe_subscription_id VARCHAR(255),
  plan VARCHAR(50) NOT NULL DEFAULT 'free',  -- free, emprendedor, negocio, empresa
  status VARCHAR(50) NOT NULL DEFAULT 'active',  -- active, past_due, canceled, trialing
  current_period_start TIMESTAMP,
  current_period_end TIMESTAMP,
  cancel_at_period_end BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Tracking de uso mensual
CREATE TABLE usage_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES teams(id) NOT NULL,
  period_start DATE NOT NULL,  -- Primer día del mes
  sales_count INT DEFAULT 0,
  products_count INT DEFAULT 0,
  ai_commands_count INT DEFAULT 0,
  credits_count INT DEFAULT 0,
  UNIQUE(team_id, period_start)
);
```

### Endpoints del Billing

```
POST   /billing/checkout           # Crear sesión de Stripe Checkout
POST   /billing/portal             # Abrir Customer Portal de Stripe
GET    /billing/subscription       # Estado actual de la suscripción
GET    /billing/usage              # Uso actual vs límites del plan
POST   /billing/webhooks/stripe    # Webhook de Stripe (eventos de pago)
```

### Flujo de suscripción

```
1. Usuario se registra → plan Gratis automático
2. Toca "Mejorar plan" en la app
3. App llama POST /billing/checkout con el plan deseado
4. Backend crea Stripe Checkout Session → devuelve URL
5. App abre URL en WebView / navegador externo
6. Usuario paga en la página de Stripe
7. Stripe envía webhook → backend actualiza subscription
8. App detecta cambio → desbloquea features
```

### Guard de límites por plan

Cada request que crea un recurso (venta, producto, etc.) pasa por `PlanLimitGuard`:

```typescript
// Pseudocódigo del guard
@Injectable()
export class PlanLimitGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const team = getTeamFromRequest(context);
    const subscription = getSubscription(team.id);
    const usage = getCurrentUsage(team.id);
    const limits = PLAN_LIMITS[subscription.plan];

    // Ejemplo: verificar límite de ventas
    if (resource === 'sales' && usage.salesCount >= limits.maxSalesPerMonth) {
      throw new ForbiddenException('Límite de ventas alcanzado. Mejora tu plan.');
    }
    return true;
  }
}
```

### Variables de entorno nuevas

```env
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_EMPRENDEDOR_MONTHLY=price_...
STRIPE_PRICE_EMPRENDEDOR_YEARLY=price_...
STRIPE_PRICE_NEGOCIO_MONTHLY=price_...
STRIPE_PRICE_NEGOCIO_YEARLY=price_...
STRIPE_PRICE_EMPRESA_MONTHLY=price_...
STRIPE_PRICE_EMPRESA_YEARLY=price_...
```

---

## UI Móvil — Pantallas de Billing

### 1. Pantalla de Planes (`subscription_screen.dart`)

- Carrusel horizontal con los 4 planes
- Cada plan muestra: nombre, precio, features incluidos, badge "Popular" en Emprendedor
- Botón CTA: "Empezar gratis" / "Mejorar plan" / "Plan actual"
- Toggle mensual/anual con badge "Ahorra 2 meses"

### 2. Banner de límite alcanzado

- Cuando el usuario alcanza un límite (ej: 50 productos), se muestra un banner:
  > "Has alcanzado el límite de 50 productos del plan Gratis. Mejora a Emprendedor para tener hasta 500."
  > [Botón: Ver planes]

### 3. Badge en Settings

- En la pantalla de Settings, mostrar el plan actual del equipo
- Link a "Gestionar suscripción" → abre Stripe Customer Portal

### 4. Onboarding (3 pantallas)

- **Pantalla 1**: "Controla tu negocio desde el celular" — ilustración de la app
- **Pantalla 2**: "Vende con voz: solo habla y la IA registra" — demo del asistente
- **Pantalla 3**: "Empieza gratis, crece cuando quieras" — tabla de planes simplificada
- Botón: "Crear cuenta gratis"

---

## Estrategia de Ventas: Paso a Paso

### Fase 1: Pre-lanzamiento (Semana 1-2)

**Objetivo**: Tener un producto listo para que alguien pague.

| # | Tarea | Responsable | Estado |
|---|-------|-------------|--------|
| 1 | Implementar módulo billing con Stripe | Desarrollo | Pendiente |
| 2 | Implementar UI de planes en la app | Desarrollo | Pendiente |
| 3 | Implementar onboarding screens | Desarrollo | Pendiente |
| 4 | Crear landing page (inventario.app) | Desarrollo/Diseño | Pendiente |
| 5 | Subir app a Play Store (track interno) | Desarrollo | Pendiente |
| 6 | Grabar video demo de 60 segundos | Marketing | Pendiente |
| 7 | Crear perfil de Instagram y TikTok | Marketing | Pendiente |

### Fase 2: Validación orgánica (Semana 3-4)

**Objetivo**: Conseguir los primeros 50 usuarios gratis y validar que la app se entiende.

| # | Tarea | Canal |
|---|-------|-------|
| 8 | Publicar 3-5 videos cortos/semana en TikTok e Instagram Reels | Orgánico |
| 9 | Publicar en grupos de Facebook de emprendedores colombianos | Orgánico |
| 10 | Publicar en r/Colombia, r/programacion, comunidades de pymes | Orgánico |
| 11 | Ofrecer la app gratis a 20-30 tiendas/negocios locales (beta testers presenciales) | Directo |
| 12 | Recoger feedback y hacer ajustes rápidos | Producto |

**Ideas de contenido para redes:**
- "Hice una app para que tu tienda deje de perder plata" (hook emocional)
- Demo del asistente de voz: "Véndele 3 cocas a Don Carlos... fiado" (wow factor)
- "Tu negocio pierde plata si no sabes qué tienes en inventario" (dolor)
- Before/After: cuaderno vs app (transformación)
- "Le puse IA a una app de inventario y esto pasó" (curiosidad tech)
- Comparación de precio vs competencia: "Alegra cobra $80.000... nosotros $49.900" (valor)

### Fase 3: Primeras ventas pagadas (Semana 5-8)

**Objetivo**: Conseguir las primeras 3-10 suscripciones pagadas.

| # | Tarea | Presupuesto |
|---|-------|-------------|
| 13 | Campaña Facebook/Instagram Ads (5-7 días) | $80.000-$160.000 COP (~$20-40 USD) |
| 14 | Target: Colombia, 25-55 años, intereses "emprendimiento", "punto de venta", "inventario" | — |
| 15 | Creative: video demo 15-30s mostrando la app en acción | — |
| 16 | CTA: "Prueba gratis → Descarga en Play Store" | — |
| 17 | Email marketing a beta testers: 50% descuento primer mes | $0 |
| 18 | Pedir testimonios y reviews en Play Store | $0 |
| 19 | Google Ads para keywords de intención alta (opcional) | $80.000-$160.000 COP |

**Keywords para Google Ads:**
- "app inventario gratis"
- "control de inventario tienda"
- "punto de venta Colombia"
- "app para tienda de barrio"
- "sistema de inventario gratis"
- "app para vender fiado"

### Fase 4: Escalar (Mes 3+)

**Objetivo**: Crecimiento sostenido hasta alcanzar $5M+ MRR.

| # | Tarea | Tipo |
|---|-------|------|
| 20 | Programa de referidos: "Invita un amigo → 1 mes gratis para ambos" | Viral |
| 21 | Contenido educativo: Blog/YouTube sobre gestión de inventario para pymes | SEO |
| 22 | Alianzas con contadores y asesores de pymes | Partnership |
| 23 | WhatsApp Business: canal de soporte + comunidad de usuarios | Retención |
| 24 | Implementar DIAN facturación electrónica (diferenciador plan Empresa) | Producto |
| 25 | Expandir a otros países LATAM (México, Perú, Ecuador) | Crecimiento |
| 26 | App Store (iOS) | Distribución |

---

## Ventajas Competitivas

Features que la competencia NO tiene o cobra mucho más por ellas:

| Feature | Inventario | Alegra | Siigo | Loyverse |
|---------|-----------|--------|-------|----------|
| Asistente IA por voz | ✅ | — | — | — |
| Jerga colombiana ("fiado", "lucas") | ✅ | — | — | — |
| Modo offline | ✅ | — | Parcial | ✅ |
| Créditos/fiado con cuotas | ✅ | Básico | Básico | — |
| Recordatorios WhatsApp | ✅ | — | — | — |
| Multi-equipo con permisos | ✅ | ✅ | ✅ | Limitado |
| Escaneo código barras | ✅ | — | — | ✅ |
| Lotes con vencimiento (FEFO) | ✅ | — | — | — |
| Precio plan base | $49.900 | $79.900 | $89.900 | $59.900 |

**Mensaje diferenciador:**
> "La primera app de inventario con IA que entiende cómo hablas. Dile 'véndele 3 cocas a Don Carlos, fiado' y listo."

---

## Landing Page (inventario.app)

### Estructura propuesta

```
[Hero]
  - Título: "Controla tu negocio desde el celular"
  - Subtítulo: "La app de inventario con IA que entiende cómo hablas"
  - Video demo de 60s
  - CTA: "Descargar gratis" → Play Store

[Features]
  - Ventas por voz con IA
  - Inventario en tiempo real
  - Fiado con cuotas automáticas
  - Funciona sin internet

[Precios]
  - Tabla de planes (igual que arriba)
  - Toggle mensual/anual

[Testimonios]
  - (después de tener beta testers)

[FAQ]
  - ¿Es gratis? Sí, el plan básico es gratis para siempre
  - ¿Funciona sin internet? Sí
  - ¿Puedo usarlo en iPhone? Próximamente
  - ¿Sirve para mi tipo de negocio? Sí, para cualquier negocio que venda productos

[Footer]
  - Links a redes sociales
  - Contacto: WhatsApp / email
```

### Opciones técnicas para la landing

| Opción | Costo | Velocidad | Personalización |
|--------|-------|-----------|-----------------|
| **Carrd.co** | $19 USD/año | 1-2 horas | Media |
| **Framer** | $0-15 USD/mes | 2-4 horas | Alta |
| **Astro (en el repo)** | $0 | 4-8 horas | Total |
| **Next.js (en el repo)** | $0 | 8-16 horas | Total |

**Recomendación**: Empezar con **Framer** o **Carrd** para validar rápido. Migrar a Astro/Next.js cuando haya tracción.

---

## Métricas Clave a Rastrear

### Adquisición
- **Descargas**: Play Store downloads
- **Registros**: Nuevos usuarios por día/semana
- **Fuente de tráfico**: Orgánico vs pagado vs referido
- **CAC** (Costo de adquisición): Gasto en ads ÷ nuevos suscriptores pagados

### Activación
- **Onboarding completado**: % de nuevos usuarios que completan las 3 pantallas
- **Primera venta**: % de usuarios que registran al menos 1 venta en los primeros 7 días
- **Time to value**: Tiempo desde registro hasta primera venta

### Retención
- **DAU/MAU**: Usuarios activos diarios / mensuales
- **Churn mensual**: % de suscriptores que cancelan por mes
- **NPS**: Net Promoter Score (encuesta in-app después de 30 días)

### Revenue
- **MRR** (Monthly Recurring Revenue): Ingreso mensual recurrente
- **ARPU** (Average Revenue Per User): MRR ÷ suscriptores pagados
- **LTV** (Lifetime Value): ARPU × (1 ÷ churn rate)
- **LTV:CAC ratio**: Debe ser > 3:1 para ser sostenible

### Herramientas de tracking

| Métrica | Herramienta |
|---------|-------------|
| Descargas y ratings | Google Play Console / App Store Connect |
| Eventos in-app | PostHog (ya configurado como feature flag provider) |
| Revenue y suscripciones | Stripe Dashboard |
| Ads performance | Meta Ads Manager / Google Ads |
| Errores y crashes | Sentry (ya configurado) |

---

## Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------|---------|------------|
| Nadie paga (conversión < 1%) | Media | Alto | Validar con ads baratos antes de invertir más. Ajustar precios o features del plan gratis |
| Churn alto (> 20%) | Media | Alto | Mejorar onboarding, agregar valor mensual (reportes, AI improvements), soporte proactivo |
| Competencia baja precios | Baja | Medio | Diferenciarse con IA y UX, no solo precio |
| Stripe bloquea cuenta | Baja | Alto | Mantener documentación legal al día, responder chargebacks rápido |
| Costos de IA (Claude API) | Media | Medio | Prompt caching (ya implementado), límites por plan, monitorear uso |
| Play Store rechaza app | Baja | Alto | Cumplir todas las políticas antes de enviar, tener privacy policy |

---

## Calendario Resumido

```
Semana 1-2:  Implementar billing + onboarding + landing page
Semana 3-4:  Publicar en Play Store + contenido orgánico en redes
Semana 5-8:  Campaña de ads ($20-40 USD) + primeras ventas
Mes 3:       Programa de referidos + contenido educativo
Mes 6:       DIAN integración + iOS App Store
Mes 12:      $10M+ MRR objetivo, expandir LATAM
```
