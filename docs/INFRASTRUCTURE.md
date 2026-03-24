# Infraestructura — AWS + Terraform

## Visión General

La infraestructura se gestiona 100% con **Terraform** y se despliega en **AWS sa-east-1** (São Paulo), elegida por proximidad geográfica al mercado colombiano.

```
                         Internet
                            │
                      ┌─────┴─────┐
                      │    ALB    │  (HTTP→HTTPS redirect)
                      │  :80/:443 │
                      └─────┬─────┘
                            │
                   ┌────────┴────────┐
                   │   ECS Fargate   │
                   │  (1-4 tareas    │
                   │   staging)      │
                   │  :3000          │
                   └───┬────────┬───┘
                       │        │
              ┌────────┘        └────────┐
              ▼                          ▼
     ┌──────────────┐          ┌──────────────┐
     │ PostgreSQL   │          │    Redis     │
     │ (ext/RDS)    │          │  (ext/EC)    │
     └──────────────┘          └──────────────┘
```

## Terraform — Estructura

```
infrastructure/terraform/
├── modules/
│   └── ecs/
│       ├── main.tf         # Cluster, Task Definition, Service, Auto-scaling
│       ├── variables.tf    # Inputs del módulo
│       └── outputs.tf      # Outputs (cluster_id, service_name, etc.)
└── environments/
    └── staging/
        ├── main.tf         # Networking, SG, ALB, IAM, Secrets, módulo ECS
        ├── variables.tf    # Variables del entorno
        └── outputs.tf      # Outputs del entorno
```

## Recursos por Entorno

### Staging (`environments/staging/`)

| Recurso                    | Tipo AWS                    | Configuración                          |
|----------------------------|-----------------------------|----------------------------------------|
| VPC                        | Default VPC                 | Se usa la VPC por defecto (simplificación para staging) |
| Security Group (backend)   | `aws_security_group`        | Ingress: puerto 3000 solo desde ALB    |
| Security Group (ALB)       | `aws_security_group`        | Ingress: puertos 80, 443 desde 0.0.0.0/0 |
| Load Balancer              | `aws_lb` (ALB)              | Público, redirect HTTP→HTTPS           |
| Target Group               | `aws_lb_target_group`       | IP-based, health check en `/health`    |
| ECS Cluster                | `aws_ecs_cluster`           | Container Insights habilitado          |
| ECS Service                | `aws_ecs_service` (Fargate) | Circuit breaker con rollback automático |
| Task Definition            | `aws_ecs_task_definition`   | 512 CPU, 1024 MB RAM                   |
| Auto-scaling               | `aws_appautoscaling_*`      | Min: 1, Max: 4, Target CPU: 70%       |
| CloudWatch Logs            | `aws_cloudwatch_log_group`  | Retención: 14 días                     |
| IAM (Execution Role)       | `aws_iam_role`              | `AmazonECSTaskExecutionRolePolicy`     |
| IAM (Task Role)            | `aws_iam_role`              | Permisos de la aplicación              |
| Secrets                    | `aws_secretsmanager_secret` | DATABASE_URL, REDIS_URL, JWT_SECRET    |

### Producción (pendiente)

Se creará `environments/production/` con:
- VPC dedicada (no default)
- RDS Multi-AZ para PostgreSQL
- ElastiCache para Redis
- Auto-scaling 2→10 tareas
- Retención de logs: 90 días

## Módulo ECS (`modules/ecs/`)

### Decisiones de Diseño

| Decisión                        | Elección                 | Razón                                           |
|---------------------------------|--------------------------|--------------------------------------------------|
| Tipo de compute                 | Fargate + Fargate Spot   | Sin gestión de EC2, 75% Spot para ahorro         |
| Estrategia Spot                 | Base 1 Fargate, Weight 3 Spot | Siempre 1 tarea estable, el resto Spot     |
| Health check                    | `wget` a `/health`       | Más ligero que `curl` (Alpine no trae curl)      |
| Circuit breaker                 | Habilitado con rollback  | Rollback automático si el deploy falla           |
| Logging                         | `awslogs` driver         | Integración nativa con CloudWatch                |
| Secretos                        | Secrets Manager ARN refs | ECS los inyecta como env vars en runtime         |
| Scale-out cooldown              | 60s                      | Escala rápido ante picos de carga                |
| Scale-in cooldown               | 300s                     | Escala lento hacia abajo para evitar flapping    |

### Variables del Módulo

| Variable                    | Tipo          | Default  | Descripción                        |
|-----------------------------|---------------|----------|------------------------------------|
| `project_name`              | string        | inventario | Prefijo para nombres de recursos |
| `environment`               | string        | —        | staging / production               |
| `backend_image`             | string        | —        | URI de la imagen Docker            |
| `backend_cpu`               | number        | 512      | CPU units (512 = 0.5 vCPU)        |
| `backend_memory`            | number        | 1024     | Memoria en MB                      |
| `desired_count`             | number        | 2        | Tareas iniciales deseadas          |
| `min_capacity`              | number        | 1        | Mínimo para auto-scaling           |
| `max_capacity`              | number        | 10       | Máximo para auto-scaling           |
| `log_retention_days`        | number        | 30       | Retención de CloudWatch Logs       |

## Estado de Terraform

| Componente     | Recurso AWS         | Propósito                           |
|----------------|---------------------|--------------------------------------|
| State file     | S3 bucket           | `inventario-terraform-state`         |
| State locking  | DynamoDB table      | `inventario-terraform-locks`         |
| Encryption     | S3 SSE              | Estado cifrado en reposo             |

> **Prerequisito**: El bucket S3 y la tabla DynamoDB deben crearse manualmente antes del primer `terraform init`.

## Seguridad

### Red

- Backend en subnets privadas (no IP pública)
- Solo accesible via ALB (Security Group restrictivo)
- HTTP redirige a HTTPS automáticamente

### IAM

- **Execution Role**: Solo permisos de ECS + ECR pull + Secrets Manager read
- **Task Role**: Permisos específicos de la app (por definir según features)
- **Deploy via OIDC**: Sin access keys estáticas en CI/CD

### Secretos

Gestionados en AWS Secrets Manager, inyectados como variables de entorno en runtime:

| Secreto                                    | Descripción                  |
|--------------------------------------------|------------------------------|
| `inventario/staging/database-url`          | Connection string PostgreSQL |
| `inventario/staging/redis-url`             | Connection string Redis      |
| `inventario/staging/jwt-secret`            | JWT signing secret           |

## Costos Estimados (Staging)

| Recurso           | Estimación mensual | Notas                              |
|--------------------|--------------------|------------------------------------|
| ECS Fargate        | ~$15-25 USD        | 1 tarea 0.5 vCPU / 1 GB (Spot)   |
| ALB                | ~$16 USD           | Costo fijo + LCUs                  |
| CloudWatch Logs    | ~$1-3 USD          | Depende del volumen de logs        |
| Secrets Manager    | ~$1.20 USD         | 3 secretos × $0.40                 |
| **Total staging**  | **~$33-45 USD/mes**| Sin incluir DB/Redis externos      |
