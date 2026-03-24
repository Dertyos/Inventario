# ADR-002: NestJS como Framework de Backend

**Estado**: Aceptado
**Fecha**: 2026-03-24
**Contexto**: Seleccionar framework para la API REST del sistema de inventarios.

## Decisión

Usar **NestJS 10.x** con TypeScript sobre Node.js 20.

## Alternativas Consideradas

1. **Express.js puro**: Ligero pero sin estructura opinada. Propenso a inconsistencias en equipos.
2. **Fastify**: Mejor rendimiento raw pero ecosistema más pequeño.
3. **NestJS** (elegido): Arquitectura modular (módulos, servicios, controladores), TypeScript nativo, decoradores, DI container, ecosistema maduro.
4. **Django/FastAPI (Python)**: Requiere equipo con expertise en Python.

## Consecuencias

- (+) Arquitectura modular facilita agregar features (DIAN, auth, inventario)
- (+) TypeScript end-to-end con el frontend si se usara web
- (+) Ecosistema de packages (`@nestjs/typeorm`, `@nestjs/jwt`, etc.)
- (+) Testing integrado con Jest
- (-) Curva de aprendizaje con decoradores y DI para devs nuevos
- (-) Mayor uso de memoria vs Express puro
