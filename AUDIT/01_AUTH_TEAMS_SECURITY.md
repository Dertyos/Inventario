# Auditoría: Auth + Teams + Security
Fecha: 2026-03-28

---

## 🔴 CRÍTICO — Falta de Refresh Token + JWT expiry de 30 días

**Archivo**: `backend/src/auth/auth.module.ts:22` + `mobile/lib/shared/providers/auth_provider.dart:77-82`
**Descripción**: JWT configurado a 30 días (`expiresIn: '2592000s'`). En mobile, al expirar solo hay un callback 401 que fuerza logout directo — no hay mecanismo de refresh token. Usuario pierde la sesión sin posibilidad de renovación silenciosa.
**Impacto**: Sesiones robadas son válidas 30 días completos sin posibilidad de revocación. UX terrible: usuario pierde contexto al expirar.
**Recomendación**: Implementar refresh token con rotación. Reducir access token TTL a 15–60 min. Guardar refresh token en secure storage.

---

## 🔴 CRÍTICO — Sin consentimiento en Social Auth (Google/Apple)

**Archivo**: `backend/src/auth/auth.service.ts:366-375 (Google)` y `:444-452 (Apple)`
**Descripción**: Cuando un usuario se registra vía Google/Apple sin cuenta previa, se auto-crea el usuario sin solicitar aceptación de términos ni política de privacidad. El campo `emailVerified` se marca `true` automáticamente.
**Impacto**: Violación potencial de GDPR/Ley 1581 Colombia. Usuarios creados sin consentimiento explícito.
**Recomendación**: Antes de crear el usuario, redirigir a pantalla de aceptación de términos + política de privacidad.

---

## 🟠 ALTO — Endpoint de invitación sin rate limiting

**Archivo**: `backend/src/teams/invite-landing.controller.ts:16-22`
**Descripción**: `GET /invite/:token` es público y sin `@Throttle()`. Permite enumerar invitaciones válidas y ataques de fuerza bruta contra tokens de invitación. Tokens duran 7 días.
**Impacto**: Token disclosure, information leakage.
**Recomendación**: Agregar `@Throttle({ short: { ttl: 60000, limit: 5 } })`. Usar UUID + hash en tokens de invitación.

---

## 🟠 ALTO — IDOR en GET /users/:id

**Archivo**: `backend/src/users/users.controller.ts:33-36`
**Descripción**: `GET /users/:id` protegido por `JwtAuthGuard` pero sin validar que el usuario autenticado solo pueda ver su propio perfil. Cualquier usuario autenticado puede leer `firstName`, `lastName`, `email` de otros usuarios.
**Impacto**: Information disclosure (IDOR limitado).
**Recomendación**: Reemplazar por `GET /users/me` o agregar guard: solo self o admin puede ver otro perfil.

---

## 🟠 ALTO — Team slugs predecibles + phishing

**Archivo**: `backend/src/teams/teams.service.ts:507-512`
**Descripción**: Slug generado como `name.toLowerCase().replace(/[^a-z0-9]+/g, '-')`. Predecible, facilita guessing de team names y phishing via emails de invitación.
**Impacto**: Guessing attack, phishing facilitado.
**Recomendación**: Agregar sufijo random al slug (ej. `"mi-equipo-a3f2x9"`) o usar solo UUID internamente.

---

## 🟠 ALTO — Race condition en invitaciones duplicadas

**Archivo**: `backend/src/teams/teams.service.ts:264-273`
**Descripción**: Se valida que email no tenga invitación activa, pero sin transacción ni constraint de DB. Dos requests concurrentes pueden crear 2 invites para el mismo email.
**Impacto**: Duplicate invites, confusión de usuario, inconsistencia de datos.
**Recomendación**: Agregar constraint `UNIQUE(teamId, email, status='pending')` en tabla `team_invite`.

---

## 🟡 MEDIO — JWT strategy expone objeto User completo

**Archivo**: `backend/src/auth/strategies/jwt.strategy.ts:25-31`
**Descripción**: `validate()` retorna el objeto `user` completo desde DB en `request.user`. Frágil: si se agregan campos sensibles sin `@Exclude()`, se exponen automáticamente.
**Impacto**: Potential information leakage en `request.user`.
**Recomendación**: Retornar DTO mínimo `{ id, email, role }` en lugar del objeto User completo.

---

## 🟡 MEDIO — Cambio de email sin verificación

**Archivo**: `backend/src/users/users.controller.ts:28-31`
**Descripción**: `PATCH /users/me` permite actualizar email sin verificación. No hay endpoint de cambio de email con código de confirmación.
**Impacto**: Account takeover potencial. Email hijacking.
**Recomendación**: Crear endpoint `/auth/change-email` con código de verificación enviado al email nuevo.

---

## 🟡 MEDIO — Enumeración de estructura de permisos

**Archivo**: `backend/src/teams/teams.controller.ts:158-166`
**Descripción**: `GET /teams/:teamId/permissions/:role` expone estructura completa de permisos por rol. Facilita enumerar qué acciones están disponibles.
**Impacto**: Permission enumeration attack.
**Recomendación**: Retornar solo permisos del usuario autenticado actual, no por rol arbitrario.

---

## 🟡 MEDIO — Sin Certificate Pinning en mobile

**Archivo**: `mobile/lib/core/` (config de red)
**Descripción**: La app permite cambiar la URL del servidor via secure storage sin pinning de certificados. Un atacante con control de red puede hacer MitM.
**Impacto**: Man-in-the-middle attack, robo de credenciales.
**Recomendación**: Implementar Certificate Pinning (Android Network Security Config + iOS security plist) para `inventario.dertyos.com`.

---

## 🟡 MEDIO — Apple Sign-In sin validación de nonce

**Archivo**: `backend/src/auth/auth.service.ts:394-429`
**Descripción**: Identity token de Apple se verifica (issuer, audience) pero no se valida el `nonce`. Posible replay attack.
**Impacto**: Token replay si se intercepta.
**Recomendación**: Agregar nonce validation en el flujo Apple Sign-In.

---

## 🟢 BAJO — /auth/register sin rate limiting

**Archivo**: `backend/src/auth/auth.controller.ts:29-32`
**Descripción**: `POST /auth/register` no tiene `@Throttle()`. `/auth/resend-verification` sí lo tiene. Sin protección, se puede hacer user enumeration.
**Impacto**: User enumeration attack.
**Recomendación**: Agregar `@Throttle({ short: { ttl: 60000, limit: 5 } })`.

---

## 🟢 BAJO — TeamAuditInterceptor sin validación temprana de UUID

**Archivo**: `backend/src/common/interceptors/team-audit.interceptor.ts:96-121`
**Descripción**: La validación de formato UUID no ocurre al inicio del interceptor. Puede loguear entity types "unknown" contaminando el audit log.
**Impacto**: Audit log pollution.
**Recomendación**: Validar formato UUID al inicio del interceptor antes de procesar.

---

## 🟢 BAJO — Invite tokens como plaintext predecible

**Archivo**: `backend/src/teams/teams.service.ts` (generación de token)
**Descripción**: Tokens de invitación no usan hashing adicional sobre el UUID.
**Impacto**: Muy bajo, pero mejora de hardening.
**Recomendación**: HMAC-SHA256 del UUID + timestamp como token.

---

## ✅ Fortalezas detectadas

- `@Exclude()` en entidades sensibles (password, codes) en User entity
- `JwtAuthGuard` + `TeamRolesGuard` en TODOS los controllers de negocio
- `TeamRolesGuard` valida pertenencia al team en todos los endpoints `/teams/:teamId/*`
- Queries filtran por `teamId` en todos los servicios
- `FlutterSecureStorage` con `encryptedSharedPreferences` en mobile
- Auth interceptor maneja 401 y limpia token correctamente
- Reset password con token single-use (`jti`) y expiración de 5 min
- Códigos de verificación con bcrypt + protección anti-brute-force (5 intentos)

---

## Resumen

| Severidad | Cantidad |
|-----------|----------|
| 🔴 CRÍTICO | 2 |
| 🟠 ALTO | 4 |
| 🟡 MEDIO | 5 |
| 🟢 BAJO | 3 |
| **TOTAL** | **14** |

**Top 3 más importantes:**
1. JWT 30 días sin refresh token — riesgo de sesión robada larga duración
2. Sin consentimiento en social auth — cumplimiento legal
3. Endpoint invitación sin rate limiting — enumeración y fuerza bruta
