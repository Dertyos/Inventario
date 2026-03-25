# Despliegues

Directorio de gestión de releases y despliegues del proyecto Inventario.

## Estructura

```
deployments/
├── README.md              # Este archivo
├── release-checklist.md   # Checklist pre-release
└── releases/
    └── v1.1.0.md          # Release notes por versión
```

## Versionado

Usamos [Semantic Versioning](https://semver.org/lang/es/):

- **MAJOR** (X.0.0): Cambios incompatibles con versiones anteriores
- **MINOR** (0.X.0): Funcionalidad nueva compatible con versiones anteriores
- **PATCH** (0.0.X): Correcciones de bugs compatibles

La versión actual se mantiene en `/VERSION` en la raíz del repo.

## Proceso de Release

1. Actualizar `VERSION` en la raíz del repo
2. Actualizar `CHANGELOG.md` con los cambios de la versión
3. Crear release notes en `deployments/releases/vX.Y.Z.md`
4. Completar el checklist en `release-checklist.md`
5. Crear tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
6. Push del tag: `git push origin vX.Y.Z`
7. GitHub Actions + Codemagic se encargan del deploy automático

## Entornos

| Entorno | Trigger | URL |
|---------|---------|-----|
| **Staging** | Push a `main` | `staging.inventario.app` |
| **Producción** | Tag `vX.Y.Z` + aprobación manual | `api.inventario.app` |
| **Mobile (Android)** | Tag `vX.Y.Z` | Play Store (internal track) |
| **Mobile (iOS)** | Tag `vX.Y.Z` | TestFlight |
