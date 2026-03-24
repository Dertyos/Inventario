# ADR-001: Estructura Monorepo

**Estado**: Aceptado
**Fecha**: 2026-03-24
**Contexto**: Definir cómo organizar el código del backend, mobile e infraestructura.

## Decisión

Usar un **monorepo** con carpetas separadas por dominio: `backend/`, `mobile/`, `infrastructure/`.

## Alternativas Consideradas

1. **Repos separados** (backend, mobile, infra): Mayor aislamiento pero complejidad en versionado cruzado y CI/CD.
2. **Monorepo con Nx/Turborepo**: Overhead para un equipo pequeño en fase MVP.
3. **Monorepo simple** (elegido): Carpetas independientes, cada una con su propio build y deploy.

## Consecuencias

- (+) Un solo repo para clonar, revisar PRs y gestionar issues
- (+) CI/CD se simplifica con `paths` filters en GitHub Actions
- (+) Cambios que afectan backend + infra se revisan juntos
- (-) Repo puede crecer mucho si no se cuida el `.gitignore`
- (-) Sin herramienta de monorepo, no hay cache compartido entre proyectos
