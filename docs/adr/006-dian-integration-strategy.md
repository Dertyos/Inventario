# ADR-006: Estrategia de Integración DIAN (Facturación Electrónica)

**Estado**: Aceptado
**Fecha**: 2026-03-24
**Contexto**: El sistema debe cumplir con la facturación electrónica obligatoria en Colombia (DIAN).

## Decisión

Soportar **dos modos de integración**, configurable por variable de entorno:

1. **`provider` (REST)**: Vía proveedor tecnológico como Alegra. **Modo por defecto para MVP**.
2. **`direct` (SOAP)**: Conexión directa al web service de la DIAN.

## Alternativas Consideradas

1. **Solo proveedor (Alegra/Siigo)**: Más simple pero vendor lock-in y costos por factura.
2. **Solo directo (SOAP DIAN)**: Sin costos recurrentes pero requiere certificado digital, manejo de XML-DSIG, y más desarrollo.
3. **Dual mode** (elegido): Flexibilidad para empezar rápido con proveedor y migrar a directo cuando sea rentable.

## Consecuencias

- (+) MVP rápido vía proveedor REST (Alegra tiene API simple)
- (+) Migración a directo sin cambiar el resto del sistema
- (+) Clientes pueden elegir según su volumen de facturación
- (-) Dos integraciones que mantener
- (-) Integración directa SOAP requiere expertise en XML signatures y certificados

## Variables de Entorno

```
DIAN_INTEGRATION_MODE=provider|direct
DIAN_PROVIDER_API_URL=       # Para modo provider
DIAN_PROVIDER_API_KEY=       # Para modo provider
DIAN_WSDL_URL=               # Para modo direct
DIAN_CERTIFICATE_PATH=       # Para modo direct
DIAN_CERTIFICATE_PASSWORD=   # Para modo direct
```
