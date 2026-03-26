# Arquitectura del Sistema — Inventario

## Visión General

**Inventario** es un sistema de gestión de inventarios diseñado para el mercado colombiano, con integración nativa a la DIAN (facturación electrónica). La arquitectura sigue un modelo cliente-servidor con una app móvil Flutter y un backend API en NestJS.

```
┌─────────────────┐     ┌─────────────────────┐     ┌──────────────┐
│   Flutter App    │────▶│   NestJS Backend     │────▶│ PostgreSQL   │
│   (Android/iOS)  │     │   (REST API)         │     │ 16           │
└─────────────────┘     └──────────┬──────────┘     └──────────────┘
                                   │
                          ┌────────┴────────┐
                          │     Redis 7     │
                          │  (Cache/Queue)  │
                          └─────────────────┘
```

## Stack Tecnológico

| Capa            | Tecnología              | Versión   | Justificación                                      |
|-----------------|-------------------------|-----------|-----------------------------------------------------|
| Mobile          | Flutter                 | 3.29.x    | Cross-platform, una sola codebase Android + iOS     |
| Backend API     | NestJS (Node.js)        | 10.x      | TypeScript nativo, arquitectura modular, ecosistema npm |
| Base de datos   | PostgreSQL              | 16        | ACID, JSON support, madurez empresarial             |
| Cache / Colas   | Redis                   | 7         | Baja latencia, pub/sub, colas de trabajo            |
| Contenedores    | Docker                  | Multi-stage | Builds reproducibles, imágenes ligeras (Alpine)    |
| IaC             | Terraform               | ≥ 1.7     | Multi-cloud, estado declarativo, modules reutilizables |
| Cloud           | AWS (sa-east-1)         | —         | Proximidad geográfica (São Paulo), ECS Fargate      |
| CI/CD           | GitHub Actions + Codemagic | —      | GHA para backend/infra, Codemagic para builds móviles firmados |

## Estructura del Monorepo

```
Inventario/
├── backend/              # NestJS REST API
│   ├── src/              # Código fuente TypeScript
│   ├── test/             # Tests e2e
│   ├── Dockerfile        # Multi-stage build (node:20-alpine)
│   └── .env.example      # Variables de entorno documentadas
├── mobile/               # Flutter app
│   ├── lib/              # Código Dart
│   ├── test/             # Widget & unit tests
│   ├── codemagic.yaml    # Pipelines de release móvil
│   ├── android/          # Configuración nativa Android
│   └── ios/              # Configuración nativa iOS
├── infrastructure/       # Infraestructura como código
│   └── terraform/
│       ├── modules/      # Módulos reutilizables (ecs, etc.)
│       └── environments/ # Configuración por entorno (staging)
├── scripts/              # Utilidades de desarrollo
│   └── setup-local.sh    # Script de setup local
├── .github/workflows/    # Pipelines CI/CD
│   ├── backend-ci.yml
│   ├── backend-deploy.yml
│   ├── mobile-ci.yml
│   └── terraform-ci.yml
└── docker-compose.yml    # Entorno local de desarrollo
```

## Principios de Arquitectura

1. **Monorepo con responsabilidades claras**: Cada carpeta raíz (`backend/`, `mobile/`, `infrastructure/`) es independiente y desplegable por separado.

2. **Entornos inmutables**: Los contenedores Docker se construyen una vez y se promueven entre entornos (staging → producción), sin reconstruir.

3. **Seguridad por defecto**:
   - Contenedores ejecutan como usuario no-root (`nestjs`, UID 1001)
   - Secretos gestionados vía AWS Secrets Manager (no en código)
   - Escaneo de vulnerabilidades en CI (Trivy, npm audit, tfsec)

4. **Infraestructura declarativa**: Todo recurso cloud está definido en Terraform. No se crean recursos manualmente.

5. **CI/CD automatizado**: Cada push a `main` despliega automáticamente a staging. Producción requiere aprobación manual (`workflow_dispatch`).

## Integraciones Clave

### DIAN — Facturación Electrónica

El sistema soporta dos modos de integración con la DIAN colombiana:

- **`provider` (REST)**: Vía proveedor tecnológico como Alegra. Recomendado para MVP.
- **`direct` (SOAP)**: Conexión directa al web service de la DIAN. Requiere certificado digital.

La configuración se controla con `DIAN_INTEGRATION_MODE` en las variables de entorno.

### Monitoreo

- **Sentry**: Tracking de errores en producción (`SENTRY_DSN`)
- **PostHog**: Feature flags y analytics (`FEATURE_FLAG_PROVIDER`)
- **CloudWatch**: Logs de contenedores ECS

### IA / Transacciones por Voz

El sistema permite registrar ventas y compras mediante comandos de voz, usando IA para interpretar lenguaje natural.

- **Backend**: Módulo NestJS (`ai-transactions`) que integra el SDK de Anthropic (Claude Haiku) para parsear texto libre en datos estructurados de venta o compra.
- **Mobile**: Paquete `speech_to_text` para reconocimiento de voz on-device (sin enviar audio a servidores externos).
- **Flujo**: Voz → texto (on-device) → API backend → Claude Haiku parsea → datos estructurados (producto, cantidad, precio) → se crea la transacción.
- **Privacidad**: El audio nunca sale del dispositivo. Solo el texto transcrito se envía al API, y de ahí a Anthropic para parsing.

## Módulos del Backend

| Módulo | Descripción |
|---|---|
| Auth | JWT + Google + Apple Sign-In |
| Teams | Multi-tenant, roles, permisos granulares |
| Products | CRUD, categorías, stock |
| Sales | Ventas transaccionales, créditos |
| Purchases | Órdenes de compra |
| Inventory | Movimientos de stock |
| Customers | Clientes CRUD |
| Suppliers | Proveedores CRUD |
| Credits | Cuentas por cobrar, cuotas |
| Lots | Lotes con FEFO |
| Payments | Pagos asociados a ventas |
| Reminders | Recordatorios de pago + cron |
| Notifications | Centro de notificaciones |
| Analytics | Métricas, reportes, gráficas |
| Export | CSV de ventas, productos, inventario |
| Audit | Log de cambios (quién, qué, cuándo) |
| AI | Claude Haiku - copiloto con 9 acciones |

## Cache (Redis)

Redis se usa como capa de cache para reducir carga en PostgreSQL:

| Clave | TTL | Invalidación |
|---|---|---|
| Productos del equipo | 30 min | Al crear/editar/eliminar producto |
| Analytics summary | 5 min | Al crear venta o movimiento de inventario |
| Analytics sales | 5 min | Al crear venta |
| Analytics inventory | 5 min | Al crear movimiento |

La invalidación es automática: cada write en los módulos correspondientes limpia las claves de cache afectadas.

## Modo Offline

La app Flutter implementa un patrón de cola de sincronización:

1. Las operaciones (crear venta, crear cliente) se guardan en almacenamiento local (SharedPreferences/SQLite)
2. Un listener de conectividad detecta cuando se recupera la conexión
3. La cola se procesa en orden FIFO, enviando cada operación al backend
4. Si una operación falla, se reintenta en el siguiente ciclo
5. Un banner en la UI muestra el estado: online, offline, o sincronizando

Datos que se cachean para lectura offline: productos, categorías, clientes.

## Permisos (RBAC)

El sistema combina roles fijos con permisos granulares configurables:

- Cada equipo tiene una tabla `team_permissions` con 15 permisos por rol
- El owner puede modificar los permisos de admin, manager y staff
- Los endpoints protegidos usan el decorator `@RequirePermission('permiso')` que valida contra los permisos del rol del usuario en el equipo
- Los permisos del owner son inmutables (siempre tiene todos)

Categorías: ventas (3), inventario (3), clientes (3), reportes (2), admin (4).

## Decisiones de Escalamiento

| Fase   | Estrategia                                     |
|--------|------------------------------------------------|
| Fase 1 (MVP) | 1 tarea ECS Fargate, PostgreSQL single-instance |
| Fase 2       | Auto-scaling 1→10 tareas (CPU target 70%), RDS Multi-AZ |
| Fase 3       | Microservicios, colas Redis para procesamiento async |
