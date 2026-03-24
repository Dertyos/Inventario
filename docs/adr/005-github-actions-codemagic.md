# ADR-005: GitHub Actions + Codemagic para CI/CD

**Estado**: Aceptado
**Fecha**: 2026-03-24
**Contexto**: Seleccionar herramientas de CI/CD para backend, infraestructura y mobile.

## Decisión

- **GitHub Actions**: CI/CD para backend, infraestructura (Terraform) y validación de PRs móviles.
- **Codemagic**: Builds de release móviles firmados (Play Store, TestFlight).

## Alternativas Consideradas

1. **Solo GitHub Actions**: Posible para todo, pero builds iOS requieren `macos-latest` que es lento y costoso.
2. **Solo Codemagic**: Bueno para mobile pero no ideal para backend/Terraform.
3. **CircleCI / GitLab CI**: Requiere integración adicional, GitHub Actions ya está integrado.
4. **GHA + Codemagic** (elegido): Lo mejor de ambos mundos.

## Consecuencias

- (+) GHA: Gratis para repos públicos, integrado con GitHub (PR comments, checks)
- (+) GHA: Services (PostgreSQL, Redis) para tests de integración
- (+) Codemagic: Máquinas M2 para builds iOS rápidos
- (+) Codemagic: Gestión de certificados y provisioning profiles integrada
- (+) Codemagic: Firebase App Distribution para builds de PR
- (-) Dos plataformas de CI/CD que mantener
- (-) Secretos duplicados en algunos casos
