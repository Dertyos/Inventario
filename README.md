# Inventario

Sistema de gestion de inventarios para el mercado colombiano con asistente IA integrado.

**Backend**: NestJS + PostgreSQL | **Mobile**: Flutter (Android + iOS) | **IA**: Claude API

---

## Que hace

- Gestion completa de productos, categorias, clientes, proveedores
- Ventas transaccionales con consecutivo auto (V-0001)
- Compras con ordenes y recepcion
- Control de inventario con movimientos (entrada/salida/ajuste)
- Creditos con cuotas e intereses
- Lotes con FEFO (First Expired, First Out)
- Multi-tenant: equipos con roles (owner/admin/manager/staff)
- **Asistente IA por voz y texto** que controla toda la app
- Reportes y analytics (graficas de ventas, top productos, metodos de pago)
- Export CSV (ventas, productos, inventario)
- Auditoria (quien cambio que, cuando)
- Permisos granulares (15 permisos en 5 categorias, configurables por rol)
- Modo offline (ventas, productos, clientes se guardan local y sincronizan)
- Cron jobs automaticos (recordatorios de pago 8am, lotes expirados 6am)
- Redis cache (productos 30min, analytics 5min)

---

## Asistente IA

El asistente entiende lenguaje natural en espanol colombiano y ejecuta acciones directamente. Funciona por voz (speech-to-text on-device) o texto.

### Acciones soportadas

| Dices... | La IA hace... |
|---|---|
| "Venta de 5 tornillos a Pedro por 25 mil" | Prepara venta con items, cliente y total |
| "Compra de 20 clavos al proveedor Garcia" | Registra orden de compra |
| "Crear producto Coca-Cola 350ml a 2500" | Crea producto con SKU auto-generado |
| "Crear categoria Bebidas" | Crea la categoria |
| "Agregar cliente Maria Garcia tel 3001234567" | Crea cliente con nombre y telefono |
| "Nuevo proveedor Distribuidora ABC nit 900123456" | Crea proveedor con NIT |
| "Entrada de 100 tuercas a bodega" | Registra movimiento de inventario (entrada) |
| "Sacar 10 tornillos del inventario" | Registra movimiento de inventario (salida) |
| "Invitar a juan@email.com como admin" | Envia invitacion al equipo |

### Jerga colombiana soportada

| Expresion | Valor |
|---|---|
| "luca" / "lucas" | 1,000 COP |
| "barra" / "barras" | 1,000,000 COP |
| "quina" | 500 COP |
| "25 mil" | 25,000 COP |
| "fiado" / "me queda debiendo" | Pago a credito |
| "nequi" / "daviplata" | Transferencia |

### Como funciona

1. El texto (voz o escrito) se envia al backend
2. Claude Haiku 4.5 parsea con `tool_use` (JSON garantizado por constrained decoding)
3. Se hace fuzzy matching contra el catalogo de productos, clientes, proveedores y categorias
4. La app muestra preview con indicador de confianza (alta / verificar datos)
5. El usuario confirma y la accion se ejecuta via API

### Seguridad IA

- Prevencion de prompt injection (11 patrones regex + delimitadores + system prompt hardened)
- Input sanitizado: 3-500 caracteres, sin markup
- Rate limiting: 5 req/min por usuario
- Prompt caching para reduccion de costos
- Audio de voz procesado on-device (nunca sale del telefono)

---

## Estructura del proyecto

```
Inventario/
├── backend/              # NestJS REST API
│   ├── src/
│   │   ├── ai/           # Modulo IA (Claude API)
│   │   ├── auth/         # JWT authentication
│   │   ├── products/     # Productos CRUD
│   │   ├── categories/   # Categorias CRUD
│   │   ├── customers/    # Clientes CRUD
│   │   ├── suppliers/    # Proveedores CRUD
│   │   ├── sales/        # Ventas transaccionales
│   │   ├── purchases/    # Ordenes de compra
│   │   ├── inventory/    # Movimientos de inventario
│   │   ├── credits/      # Cuentas de credito
│   │   ├── payments/     # Pagos
│   │   ├── lots/         # Lotes de productos
│   │   ├── reminders/    # Recordatorios de pago
│   │   ├── notifications/# Centro de notificaciones
│   │   ├── analytics/    # Metricas y reportes
│   │   ├── export/       # Export CSV
│   │   ├── audit/        # Log de cambios
│   │   └── teams/        # Multi-tenant, roles, permisos
│   ├── Dockerfile
│   └── .env.example
├── mobile/               # Flutter app (Android + iOS)
│   ├── lib/
│   │   ├── core/         # Config, network, theme, AI service, storage
│   │   ├── features/     # Auth, Dashboard, Products, Sales, Inventory,
│   │   │                 # Customers, Settings, AI Chat
│   │   └── shared/       # Models, providers, widgets
│   ├── android/
│   └── ios/
├── infrastructure/       # Terraform (ECS Fargate, ALB, etc.)
├── .github/workflows/    # CI/CD pipelines
├── deployments/          # Guias de despliegue
└── docs/                 # Arquitectura, ADRs
```

---

## Setup rapido

### Prerequisitos

- Docker 20+
- Node.js 20 LTS
- Flutter 3.29.x
- Git

### 1. Clonar e instalar

```bash
git clone https://github.com/Dertyos/Inventario.git
cd Inventario

# Setup automatico
chmod +x scripts/setup-local.sh
./scripts/setup-local.sh
```

### 2. Levantar servicios

```bash
# PostgreSQL + Redis
docker compose up -d postgres redis

# Backend (en otra terminal)
cd backend
cp .env.example .env
npm install
npm run start:dev
# API en http://localhost:3000

# Mobile (en otra terminal)
cd mobile
flutter pub get
flutter run
```

### 3. Configurar IA (opcional)

Para habilitar el asistente IA, agrega tu API key en `backend/.env`:

```
ANTHROPIC_API_KEY=sk-ant-...
```

---

## Variables de entorno

### Backend (`backend/.env`)

| Variable | Descripcion | Default |
|---|---|---|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://inventario:inventario_dev@localhost:5432/inventario` |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379` |
| `JWT_SECRET` | Secret para tokens JWT | `change-this-in-production` |
| `JWT_EXPIRATION` | Tiempo de expiracion JWT (seg) | `3600` |
| `ANTHROPIC_API_KEY` | API key de Anthropic (para IA) | _(opcional)_ |
| `PORT` | Puerto del API | `3000` |

### Mobile

| Variable | Descripcion | Default |
|---|---|---|
| `API_BASE_URL` | URL del backend (compile-time) | `http://10.0.2.2:3000` |

Tambien configurable en runtime desde **Settings > Servidor** en la app.

---

## Despliegue

### Opcion gratis ($0)

Ver [deployments/DEPLOY-GRATIS.md](deployments/DEPLOY-GRATIS.md) para desplegar con:
- **Neon.tech**: PostgreSQL gratis
- **Render.com**: Backend gratis
- **GitHub Actions**: Compilar APK gratis

### APK

```bash
# Compilar localmente
cd mobile
flutter build apk --release

# O via GitHub Actions:
# 1. Ve a Actions > "Build & Release APK" > Run workflow
# 2. Opcionalmente pasa la URL del backend como api_base_url
# 3. Descarga el APK de Artifacts
```

### Release automatico

```bash
git tag v1.2.0
git push origin v1.2.0
# El APK aparece en GitHub Releases
```

---

## Stack tecnologico

| Capa | Tecnologia | Version |
|---|---|---|
| Mobile | Flutter | 3.29.x |
| Backend | NestJS (Node.js) | 10.x |
| Base de datos | PostgreSQL | 16 |
| Cache / Colas | Redis | 7 |
| IA | Claude Haiku 4.5 (Anthropic SDK) | - |
| Contenedores | Docker (multi-stage) | - |
| IaC | Terraform | >= 1.7 |
| Cloud | AWS (sa-east-1) | - |
| CI/CD | GitHub Actions + Codemagic | - |

---

## API endpoints principales

### Auth
- `POST /auth/register` - Registro
- `POST /auth/login` - Login
- `GET /auth/profile` - Perfil del usuario

### Teams
- `POST /teams` - Crear equipo
- `GET /teams` - Mis equipos
- `POST /teams/:id/members` - Invitar miembro

### Productos & Categorias
- `CRUD /teams/:id/products`
- `CRUD /teams/:id/categories`

### Clientes & Proveedores
- `CRUD /teams/:id/customers`
- `CRUD /teams/:id/suppliers`

### Ventas & Compras
- `POST /teams/:id/sales` - Crear venta
- `POST /teams/:id/purchases` - Crear compra

### Inventario
- `POST /teams/:id/inventory/movements` - Movimiento de stock

### Creditos & Pagos
- `POST /teams/:id/credits` - Crear credito
- `POST /teams/:id/payments` - Registrar pago

### IA
- `POST /teams/:id/ai/parse-command` - Parsear comando en lenguaje natural
- `POST /teams/:id/ai/parse-transaction` - Parsear transaccion (legacy)

### Analytics & Reportes
- `GET /teams/:id/analytics/summary` - Dashboard analytics
- `GET /teams/:id/analytics/sales` - Ventas por periodo
- `GET /teams/:id/analytics/inventory` - Metricas de inventario

### Export CSV
- `GET /teams/:id/export/sales` - Exportar ventas CSV
- `GET /teams/:id/export/products` - Exportar productos CSV
- `GET /teams/:id/export/inventory` - Exportar inventario CSV

### Auditoria
- `GET /teams/:id/audit` - Logs de auditoria

### Permisos
- `GET /teams/:id/permissions/:role` - Obtener permisos de un rol
- `PATCH /teams/:id/permissions/:role` - Actualizar permisos de un rol

---

## Permisos granulares

El sistema tiene 15 permisos agrupados en 5 categorias, configurables por rol:

| Categoria | Permisos |
|---|---|
| Ventas | `sales.create`, `sales.view`, `sales.delete` |
| Inventario | `inventory.create`, `inventory.view`, `inventory.edit` |
| Clientes | `customers.create`, `customers.view`, `customers.edit` |
| Reportes | `reports.view`, `reports.export` |
| Admin | `admin.team`, `admin.roles`, `admin.audit`, `admin.settings` |

**Roles por defecto:**
- **Owner**: todos los permisos (no editable)
- **Admin**: todos excepto `admin.team`
- **Manager**: ventas, inventario, clientes, `reports.view`
- **Staff**: `sales.create`, `sales.view`, `inventory.view`, `customers.view`

El owner puede personalizar los permisos de cada rol desde **Settings > Permisos**. Los endpoints protegidos usan `@RequirePermission()` para validar acceso.

---

## Modo offline

La app funciona sin conexion a internet:

- **Ver productos**: catalogo cacheado localmente
- **Crear ventas**: se guardan en cola local
- **Crear clientes**: se guardan en cola local

Al reconectar, la app sincroniza automaticamente los datos pendientes con el backend. Un banner en la parte superior indica el estado de conexion.

---

## Documentacion

### Producto y Negocio
- [MONETIZATION.md](docs/MONETIZATION.md) - Estrategia de monetizacion, planes, precios, Stripe, plan de ventas
- [ROADMAP.md](docs/ROADMAP.md) - Roadmap del producto con timeline y prioridades
- [GAPS.md](docs/GAPS.md) - Gaps y pendientes (funcionales + monetizacion)

### Arquitectura y Desarrollo
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Arquitectura del sistema
- [DATABASE.md](docs/DATABASE.md) - Esquema de base de datos
- [DEVELOPMENT.md](docs/DEVELOPMENT.md) - Guia de desarrollo local

### Infraestructura y Deploy
- [CI-CD.md](docs/CI-CD.md) - Pipelines y workflows
- [INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md) - Infraestructura cloud (AWS)
- [DEPLOY-GRATIS.md](deployments/DEPLOY-GRATIS.md) - Despliegue gratuito ($0)
- [release-checklist.md](deployments/release-checklist.md) - Checklist de release

### Calidad
- [AUDIT/](AUDIT/) - Auditoria completa (89 hallazgos tecnicos + 30 UX)
- [AUDIT/SECURITY_AUDIT.md](AUDIT/SECURITY_AUDIT.md) - Auditoria de seguridad
- [AUDIT/ISSUES_SUMMARY.md](AUDIT/ISSUES_SUMMARY.md) - Resumen de issues + plan de 4 sprints
- [ui_audit.md](docs/ui_audit.md) - Auditoria de UI/UX
- [ui_fixes_plan.md](docs/ui_fixes_plan.md) - Plan de correcciones UI

### Decisiones
- [CHANGELOG.md](CHANGELOG.md) - Historial de cambios
- [ADRs](docs/adr/) - Architecture Decision Records (7 ADRs)

---

## Licencia

Proyecto privado. Todos los derechos reservados.
