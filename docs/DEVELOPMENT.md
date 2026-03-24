# Guía de Desarrollo Local

## Prerequisitos

| Herramienta | Versión mínima | Instalación                        |
|-------------|----------------|------------------------------------|
| Docker      | 20+            | [docker.com](https://docs.docker.com/get-docker/) |
| Node.js     | 20 LTS         | [nodejs.org](https://nodejs.org/)  |
| Flutter     | 3.29.x         | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Git         | 2.x            | Ya instalado en la mayoría de OS   |

## Setup Rápido

```bash
# 1. Clonar el repositorio
git clone https://github.com/Dertyos/Inventario.git
cd Inventario

# 2. Ejecutar script de setup
chmod +x scripts/setup-local.sh
./scripts/setup-local.sh
```

El script automáticamente:
- Verifica que Docker, Node.js y Flutter estén instalados
- Crea `backend/.env` desde `.env.example`
- Instala dependencias del backend (`npm install`)
- Instala dependencias del mobile (`flutter pub get`)
- Levanta PostgreSQL y Redis con Docker Compose

## Setup Manual (paso a paso)

### 1. Servicios de infraestructura

```bash
# Levantar PostgreSQL 16 y Redis 7
docker compose up -d postgres redis

# Verificar que estén corriendo
docker compose ps
```

| Servicio   | Puerto | Credenciales                          |
|------------|--------|---------------------------------------|
| PostgreSQL | 5432   | user: `inventario` / pass: `inventario_dev` / db: `inventario` |
| Redis      | 6379   | Sin autenticación (desarrollo)        |

### 2. Backend (NestJS)

```bash
cd backend

# Crear archivo de variables de entorno
cp .env.example .env

# Instalar dependencias
npm install

# Ejecutar en modo desarrollo (hot-reload)
npm run start:dev

# El API estará en http://localhost:3000
```

### 3. Mobile (Flutter)

```bash
cd mobile

# Instalar dependencias
flutter pub get

# Ejecutar en emulador o dispositivo conectado
flutter run

# Ejecutar solo en Chrome (web)
flutter run -d chrome
```

### 4. Todo junto con Docker Compose

```bash
# Levanta backend + postgres + redis
docker compose up

# O en background
docker compose up -d

# Ver logs
docker compose logs -f backend
```

## Variables de Entorno

El archivo `backend/.env.example` documenta todas las variables necesarias:

### Requeridas para desarrollo

| Variable       | Valor por defecto                                          | Descripción           |
|----------------|------------------------------------------------------------|-----------------------|
| `NODE_ENV`     | `development`                                              | Entorno de ejecución  |
| `PORT`         | `3000`                                                     | Puerto del API        |
| `DATABASE_URL` | `postgresql://inventario:inventario_dev@localhost:5432/inventario` | PostgreSQL connection |
| `REDIS_URL`    | `redis://localhost:6379`                                   | Redis connection      |
| `JWT_SECRET`   | `change-this-in-production`                                | Secret para JWT       |

### Opcionales (features avanzados)

| Variable                | Descripción                                 |
|-------------------------|---------------------------------------------|
| `DIAN_INTEGRATION_MODE` | `provider` (Alegra REST) o `direct` (SOAP)  |
| `DIAN_PROVIDER_API_URL` | URL del proveedor de facturación             |
| `DIAN_PROVIDER_API_KEY` | API key del proveedor                        |
| `SENTRY_DSN`            | DSN de Sentry para error tracking            |
| `FEATURE_FLAG_*`        | Configuración de PostHog/Flagsmith           |

## Comandos Frecuentes

### Backend

```bash
npm run start:dev      # Desarrollo con hot-reload
npm run build          # Compilar TypeScript
npm run start:prod     # Ejecutar build de producción
npm run lint           # Ejecutar ESLint
npm run format:check   # Verificar formato (Prettier)
npm run test           # Tests unitarios
npm run test -- --coverage  # Tests con coverage
npm run test:e2e       # Tests end-to-end
```

### Mobile

```bash
flutter pub get        # Instalar dependencias
flutter analyze        # Análisis estático
dart format .          # Formatear código
flutter test           # Ejecutar tests
flutter test --coverage # Tests con coverage
flutter build apk      # Build Android
flutter build ios       # Build iOS
```

### Docker

```bash
docker compose up -d              # Levantar servicios en background
docker compose down               # Detener servicios
docker compose down -v            # Detener y eliminar volúmenes (reset DB)
docker compose logs -f [servicio] # Ver logs en tiempo real
docker compose ps                 # Estado de los servicios
```

### Terraform (infraestructura)

```bash
cd infrastructure/terraform/environments/staging

terraform init              # Inicializar providers y backend
terraform fmt -check        # Verificar formato
terraform validate          # Validar configuración
terraform plan              # Ver cambios pendientes
terraform apply             # Aplicar cambios (con confirmación)
```

## Estructura de Branches

| Branch     | Propósito                          |
|------------|------------------------------------|
| `main`     | Producción — deploy automático a staging, manual a prod |
| `develop`  | Integración — CI se ejecuta en PRs |
| `feature/*`| Nuevas funcionalidades             |
| `fix/*`    | Corrección de bugs                 |
| `claude/*` | Branches creados por Claude Code   |

## Troubleshooting

### PostgreSQL no inicia

```bash
# Verificar que el puerto 5432 no esté ocupado
lsof -i :5432

# Reiniciar con volúmenes limpios
docker compose down -v
docker compose up -d postgres
```

### Backend no conecta a la base de datos

1. Verificar que PostgreSQL esté corriendo: `docker compose ps`
2. Verificar `DATABASE_URL` en `backend/.env`
3. Si usas Docker Compose para todo: el host es `postgres` (no `localhost`)
4. Si ejecutas backend fuera de Docker: el host es `localhost`

### Flutter no encuentra dispositivos

```bash
flutter doctor    # Diagnóstico completo
flutter devices   # Listar dispositivos disponibles
```
