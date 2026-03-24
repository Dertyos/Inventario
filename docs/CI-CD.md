# CI/CD — Pipelines y Workflows

## Resumen de Pipelines

El proyecto utiliza **GitHub Actions** para backend e infraestructura, y **Codemagic** para builds de release móviles.

```
                    ┌──────────────┐
  Push/PR ────────▶ │  GitHub      │
                    │  Actions     │
                    └──────┬───────┘
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
   ┌─────────────┐ ┌─────────────┐ ┌───────────────┐
   │ Backend CI  │ │ Mobile CI   │ │ Terraform CI  │
   │ (4 jobs)    │ │ (4 jobs)    │ │ (2 jobs)      │
   └──────┬──────┘ └─────────────┘ └───────────────┘
          ▼
   ┌─────────────┐        ┌──────────────┐
   │ Backend     │        │  Codemagic   │
   │ Deploy      │        │  (releases)  │
   │ (ECS)       │        └──────────────┘
   └─────────────┘
```

---

## 1. Backend CI (`backend-ci.yml`)

**Trigger**: Push/PR a `main` o `develop` cuando cambian archivos en `backend/`.

### Jobs

| Job      | Descripción                          | Dependencias |
|----------|--------------------------------------|--------------|
| `lint`   | ESLint + Prettier format check       | —            |
| `test`   | Unit tests + e2e con coverage        | `lint`       |
| `build`  | Docker build + push a GHCR           | `test`       |
| `security` | npm audit + Trivy vulnerability scan | `lint`     |

### Servicios en CI

- **PostgreSQL 16** (`postgres:16-alpine`): Para tests de integración
- **Redis 7** (`redis:7-alpine`): Para tests que requieren cache/colas

### Variables de Entorno en CI

```
DATABASE_URL=postgresql://inventario_test:test_password@localhost:5432/inventario_test
REDIS_URL=redis://localhost:6379
NODE_ENV=test
JWT_SECRET=test-secret-key-for-ci
```

### Docker Build

- Push a `ghcr.io` solo en push a `main` (no en PRs)
- Tags: SHA del commit, nombre de branch, semver si hay tag
- Caché via GitHub Actions cache (`type=gha`)

---

## 2. Backend Deploy (`backend-deploy.yml`)

**Trigger**:
- Push a `main` → Deploy automático a **staging**
- `workflow_dispatch` → Deploy manual a **staging** o **producción**

### Flujo de Despliegue

```
Code push → Build Docker image → Push a ECR → Update ECS Task Definition → Deploy ECS Service → Smoke test
```

### Entornos

| Entorno     | URL                              | Trigger              |
|-------------|----------------------------------|----------------------|
| Staging     | `staging-api.inventario.app`     | Push a `main` (auto) |
| Producción  | `api.inventario.app`             | Manual (workflow_dispatch) |

### Seguridad del Deploy

- **OIDC Authentication**: Usa `role-to-assume` (sin access keys estáticas)
- **Concurrency groups**: Evita deploys simultáneos al mismo entorno
- **Smoke tests**: Valida `/health` endpoint post-deploy

### Secretos Requeridos (GitHub)

| Secreto                    | Descripción                     |
|----------------------------|---------------------------------|
| `AWS_ROLE_ARN_STAGING`     | IAM Role para deploy a staging  |
| `AWS_ROLE_ARN_PRODUCTION`  | IAM Role para deploy a producción |

---

## 3. Mobile CI (`mobile-ci.yml`)

**Trigger**: Push/PR a `main` o `develop` cuando cambian archivos en `mobile/`.

### Jobs

| Job             | Runner           | Descripción                     | Dependencias |
|-----------------|------------------|---------------------------------|--------------|
| `analyze`       | `ubuntu-latest`  | `dart format` + `flutter analyze` | —          |
| `test`          | `ubuntu-latest`  | Unit + Widget tests con coverage | `analyze`   |
| `build-android` | `ubuntu-latest`  | Build APK debug                 | `test`       |
| `build-ios`     | `macos-latest`   | Build iOS sin codesign          | `test`       |

### Decisión: GH Actions vs Codemagic

- **GitHub Actions**: Validación en PRs (analyze, test, debug builds). Gratis para repos públicos.
- **Codemagic**: Builds firmados para release (AAB → Play Store, IPA → TestFlight). Requiere certificados y provisioning profiles.

---

## 4. Codemagic (`mobile/codemagic.yaml`)

### Workflows

| Workflow         | Trigger                | Output                        | Destino              |
|------------------|------------------------|-------------------------------|----------------------|
| Android Release  | Tag `v*-android` / `v*` | AAB (App Bundle)             | Play Store (internal) |
| iOS Release      | Tag `v*-ios` / `v*`    | IPA                           | TestFlight           |
| Android Debug    | PR a `develop`         | APK debug                     | Firebase App Distribution |

### Secretos Codemagic

| Variable                  | Uso                              |
|---------------------------|----------------------------------|
| `CM_KEYSTORE`             | Keystore Android (base64)        |
| `CM_KEY_ALIAS`            | Alias de la key                  |
| `CM_KEY_PASSWORD`         | Password de la key               |
| `CM_KEYSTORE_PASSWORD`    | Password del keystore            |
| `APP_STORE_CONNECT_*`     | Credenciales de App Store Connect |
| `FIREBASE_TOKEN`          | Token para App Distribution      |

---

## 5. Terraform CI (`terraform-ci.yml`)

**Trigger**: Push/PR a `main` o `develop` cuando cambian archivos en `infrastructure/terraform/`.

### Jobs

| Job        | Descripción                         |
|------------|-------------------------------------|
| `validate` | `terraform fmt`, `init`, `validate`, `plan` |
| `security` | `tfsec` scan (soft fail)            |

### Comportamiento en PRs

- Ejecuta `terraform plan` y publica el resultado como comentario en el PR
- Permite revisar cambios de infraestructura antes del merge

---

## 6. Matriz de Secretos

### GitHub Actions Secrets

| Secreto                    | Pipeline          | Descripción                      |
|----------------------------|-------------------|----------------------------------|
| `GITHUB_TOKEN`             | Backend CI        | Auto-generado, push a GHCR      |
| `AWS_ROLE_ARN_STAGING`     | Backend Deploy    | OIDC role para staging           |
| `AWS_ROLE_ARN_PRODUCTION`  | Backend Deploy    | OIDC role para producción        |
| `AWS_ROLE_ARN_TERRAFORM`   | Terraform CI      | OIDC role para Terraform plan    |

### Codemagic Secrets

| Secreto                    | Pipeline          | Descripción                      |
|----------------------------|-------------------|----------------------------------|
| `CM_KEYSTORE`              | Android Release   | Keystore en base64               |
| `CM_KEY_ALIAS`             | Android Release   | Alias de signing key             |
| `CM_KEY_PASSWORD`          | Android Release   | Password de la key               |
| `CM_KEYSTORE_PASSWORD`     | Android Release   | Password del keystore            |
| `FIREBASE_TOKEN`           | Android Debug     | Firebase App Distribution token  |

---

## 7. Diagrama de Flujo Completo

```
Developer Push
       │
       ├── backend/** ──────▶ Backend CI ──▶ [lint → test → build → security]
       │                                           │
       │                                    push a main?
       │                                     │          │
       │                                    Sí         No
       │                                     ▼          ▼
       │                              Backend Deploy   (fin)
       │                              [staging auto]
       │                                     │
       │                              workflow_dispatch?
       │                                     ▼
       │                              [producción manual]
       │
       ├── mobile/** ───────▶ Mobile CI ───▶ [analyze → test → build APK/iOS]
       │
       ├── infrastructure/** ▶ Terraform CI ▶ [validate → plan → tfsec]
       │
       └── tag v* ──────────▶ Codemagic ───▶ [build → sign → publish]
                                              [Play Store / TestFlight]
```
