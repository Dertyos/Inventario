# ADR-003: Flutter para Aplicación Móvil

**Estado**: Aceptado
**Fecha**: 2026-03-24
**Contexto**: Seleccionar tecnología para la app móvil (Android + iOS).

## Decisión

Usar **Flutter 3.29.x** con Dart para desarrollo cross-platform.

## Alternativas Consideradas

1. **Nativo (Kotlin + Swift)**: Mejor rendimiento y acceso a APIs nativas, pero doble codebase y doble equipo.
2. **React Native**: Ecosistema JS, pero bridge entre JS y nativo agrega latencia y complejidad.
3. **Flutter** (elegido): Una codebase, rendimiento nativo (compilado a ARM), widgets propios sin bridge.

## Consecuencias

- (+) Una sola codebase para Android e iOS
- (+) Hot-reload acelera desarrollo
- (+) Rendimiento cercano a nativo (compilado, no interpretado)
- (+) Widget library rica para UI consistente
- (-) Tamaño de APK/IPA mayor que nativo
- (-) Ecosistema de packages menos maduro que JS/npm
- (-) Dart es un lenguaje menos conocido que JS/Kotlin/Swift
