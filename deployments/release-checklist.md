# Checklist de Release — Inventario

## Pre-release

- [ ] Todos los tests pasan (`npm test` en backend, `flutter test` en mobile)
- [ ] Lint sin errores (`npm run lint`, `dart analyze`)
- [ ] Code review aprobado por al menos 1 reviewer
- [ ] `CHANGELOG.md` actualizado con los cambios de la versión
- [ ] Versión actualizada en `/VERSION`
- [ ] Release notes creadas en `deployments/releases/vX.Y.Z.md`
- [ ] No hay secrets ni credenciales en el código (verificar `.env.example`)

## Backend

- [ ] Build Docker exitoso: `docker build -t inventario-backend .`
- [ ] Deploy a **staging** automático (push a `main`)
- [ ] Verificar API en staging: `curl https://staging.inventario.app/health`
- [ ] Ejecutar tests e2e contra staging
- [ ] Migraciones de base de datos aplicadas correctamente
- [ ] Variables de entorno actualizadas en AWS Secrets Manager (si aplica)

## Mobile

- [ ] Version bump en `pubspec.yaml` (version + build number)
- [ ] Build Android APK: `flutter build apk --release`
- [ ] Build iOS: `flutter build ios --release`
- [ ] Probar en dispositivo físico (Android + iOS)
- [ ] Screenshots actualizados (si hay cambios de UI)
- [ ] Submit a Play Store (internal track) vía Codemagic
- [ ] Submit a TestFlight vía Codemagic

## Post-release

- [ ] Verificar deploy en producción: `curl https://api.inventario.app/health`
- [ ] Verificar app móvil descargada desde stores
- [ ] Monitorear Sentry por errores nuevos (primeras 24h)
- [ ] Monitorear CloudWatch por anomalías en logs
- [ ] Crear tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
- [ ] Push del tag: `git push origin vX.Y.Z`
- [ ] Notificar al equipo que el release está en producción
