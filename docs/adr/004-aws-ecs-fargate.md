# ADR-004: AWS ECS Fargate para Despliegue

**Estado**: Aceptado
**Fecha**: 2026-03-24
**Contexto**: Definir plataforma de hosting para el backend containerizado.

## Decisión

Usar **AWS ECS Fargate** en la región **sa-east-1** (São Paulo).

## Alternativas Consideradas

1. **AWS ECS con EC2**: Más control y potencialmente más barato a escala, pero requiere gestionar instancias.
2. **AWS EKS (Kubernetes)**: Más flexible pero overhead operacional significativo para MVP.
3. **AWS Lambda**: Serverless puro, pero cold starts y limitaciones en conexiones persistentes (WebSocket, DB pools).
4. **ECS Fargate** (elegido): Serverless containers, sin gestión de infra, auto-scaling nativo, pricing por uso.
5. **DigitalOcean/Railway**: Más simple pero sin la profundidad de servicios AWS (Secrets Manager, CloudWatch, etc.).

## Consecuencias

- (+) Sin gestión de servidores o instancias EC2
- (+) Auto-scaling automático (CPU target tracking)
- (+) Circuit breaker con rollback automático
- (+) Fargate Spot para ahorro de costos (~70%)
- (+) Región sa-east-1 para baja latencia en Colombia
- (-) Costo por tarea mayor que EC2 a gran escala
- (-) Vendor lock-in con AWS
- (-) Cold start de ~30s al escalar desde 0 (mitigado con min_capacity=1)
