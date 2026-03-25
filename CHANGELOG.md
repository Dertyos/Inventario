# Changelog

Todos los cambios notables del proyecto se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).
Versionado según [Semantic Versioning](https://semver.org/lang/es/).

## [1.1.0] - 2026-03-25

### Agregado
- **Transacciones por voz**: Registrar ventas y compras dictando en lenguaje natural
  - Reconocimiento de voz on-device (speech_to_text) — audio nunca sale del teléfono
  - Parsing con Claude Haiku 4.5 via tool_use (JSON garantizado por constrained decoding)
  - Soporte para jerga colombiana: "lucas", "barras", "quina", "fiado"
  - Matching fuzzy de productos contra el catálogo del equipo
  - Indicador de confianza (alta/verificar datos) en resultados parseados
  - Feedback visual del nivel de sonido durante escucha
- **Módulo AI en backend**: Controller, service, provider con Anthropic SDK
  - Prompt caching para 90% reducción de costo en tokens de input
  - Prevención de prompt injection (regex + delimitadores + system prompt hardened)
  - Rate limiting: 5 req/min por usuario en endpoint AI
  - Validación de input: 3-500 caracteres, sanitización de markup
- **Permisos nativos**: RECORD_AUDIO + BLUETOOTH en Android, Speech + Microphone en iOS

### Cambiado
- Migrado auth_provider de `StateNotifier` (deprecated) a `Notifier` (Riverpod 3.x)
- Actualizado dependencias Flutter a versiones compatibles con Dart 3.11.3
- Dashboard FAB ahora incluye acceso directo al registro por voz

### Eliminado
- Predicciones de demanda con IA (AiDemandForecast)
- Sugerencia de precios con IA (AiPriceSuggestion)
- Insights de IA en dashboard (AiInsightCard)
- Chat genérico de IA (reemplazado por transacciones por voz)

## [1.0.0] - 2026-03-25

### Agregado
- **Backend completo** (NestJS + PostgreSQL + TypeORM)
  - Auth JWT con registro/login
  - Multi-tenant: Teams, TeamMembers, roles (owner/admin/manager/staff)
  - Products, Categories, Inventory con stock tracking
  - Customers CRUD con documento único por equipo
  - Sales transaccionales con pessimistic locking, consecutivo auto (V-0001)
  - Payments (cash/card/transfer) asociados a ventas
  - Credit accounts con 3 tipos de interés y auto-generación de cuotas
  - Product lots con FEFO (First Expired, First Out)
  - Suppliers CRUD con NIT único por equipo
  - Purchase orders con consecutivo auto (C-0001)
  - Reminders de pago y notificaciones internas
  - 121 unit tests, 15 suites
- **App móvil Flutter** (Android + iOS)
  - 12 pantallas: Auth, Dashboard, Products, Sales, Inventory, Customers, Settings, Voice
  - MVVM + Repository pattern
  - Riverpod para state management
  - go_router con auth guards
  - Material 3 con dark mode automático
  - Dio con interceptors para auth y error handling
- **CI/CD**
  - GitHub Actions: Backend CI (lint, test, Docker build, Trivy scan)
  - Codemagic: Flutter release pipelines (Play Store + TestFlight)
  - Docker: Multi-stage Dockerfile (node:20-alpine, non-root)
- **Infraestructura**
  - Terraform: ECS Fargate, ALB, Secrets Manager, CloudWatch
  - AWS sa-east-1 (São Paulo + Bogotá Local Zone)
  - docker-compose para desarrollo local
- **Documentación**
  - ARCHITECTURE.md, CI-CD.md, INFRASTRUCTURE.md, DEVELOPMENT.md
  - 6 Architecture Decision Records (ADRs)
