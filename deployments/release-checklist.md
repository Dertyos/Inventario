# Checklist Pre-Release

Completar antes de cada release a producción.

## Código

- [ ] Todos los tests unitarios pasan (`npm test` / `flutter test`)
- [ ] Lint limpio (`npm run lint` / `flutter analyze`)
- [ ] TypeScript compila sin errores (`npx tsc --noEmit`)
- [ ] Prettier formateado (`npm run format:check`)
- [ ] No hay secretos hardcodeados (API keys, passwords)
- [ ] No hay `console.log` / `print()` de debug en producción

## Seguridad

- [ ] `npm audit` sin vulnerabilidades críticas o altas
- [ ] Trivy scan del Docker image sin CVEs críticas
- [ ] Variables de entorno documentadas en `.env.example`
- [ ] Secretos nuevos agregados a AWS Secrets Manager

## Base de datos

- [ ] Migraciones generadas y probadas (`migration:generate`, `migration:run`)
- [ ] Migraciones son reversibles (tiene `down()`)
- [ ] No hay `synchronize: true` en producción

## Mobile

- [ ] `flutter build apk --release` genera APK firmado
- [ ] `flutter build ios --release` genera IPA
- [ ] Versión actualizada en `pubspec.yaml` (version: X.Y.Z+BUILD)
- [ ] Permisos nativos actualizados (AndroidManifest, Info.plist)
- [ ] Tamaño del APK/IPA revisado (no hay assets innecesarios)

## Documentación

- [ ] `VERSION` actualizado en raíz del repo
- [ ] `CHANGELOG.md` actualizado con cambios de esta versión
- [ ] Release notes creado en `deployments/releases/vX.Y.Z.md`
- [ ] API docs actualizados (Swagger decorators en nuevos endpoints)

## Deploy

- [ ] Staging desplegado y probado manualmente
- [ ] Smoke tests en staging (auth, CRUD básico, nueva funcionalidad)
- [ ] Tag creado: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
- [ ] Tag pusheado: `git push origin vX.Y.Z`
- [ ] GitHub Actions deploy completado sin errores
- [ ] Codemagic build completado para Android + iOS
- [ ] Verificar health check en producción post-deploy
