# Despliegue 100% Gratis - Inventario

Todo sin tarjeta de crédito, $0 total.

---

## Paso 1: Base de datos PostgreSQL (Neon.tech - gratis para siempre)

1. Ve a **https://neon.tech** y crea una cuenta con GitHub
2. Clic en **"Create Project"**
   - Name: `inventario`
   - Region: **US East** (o el más cercano)
3. Copia el **connection string** que te da, se ve así:
   ```
   postgresql://neondb_owner:abc123@ep-cool-name-123.us-east-2.aws.neon.tech/neondb?sslmode=require
   ```
4. **Guárdalo**, lo necesitas en el paso 2

**Free tier de Neon**: 0.5 GB storage, sin límite de tiempo.

---

## Paso 2: Backend en Render.com (gratis)

1. Ve a **https://render.com** y crea cuenta con GitHub
2. Clic en **"New" → "Web Service"**
3. Conecta tu repo **Dertyos/Inventario**
4. Configura:
   - **Name**: `inventario-api`
   - **Region**: Oregon
   - **Root Directory**: `backend`
   - **Runtime**: Docker
   - **Instance Type**: **Free**
5. En **Environment Variables**, agrega:

   | Variable | Valor |
   |----------|-------|
   | `NODE_ENV` | `production` |
   | `PORT` | `10000` |
   | `DATABASE_URL` | *(pega el string de Neon del paso 1)* |
   | `JWT_SECRET` | *(inventa algo largo, ej: mi-super-secreto-2026-xyz)* |
   | `JWT_EXPIRATION` | `3600` |

6. Clic en **"Create Web Service"**
7. Espera ~3-5 min mientras construye
8. Tu API estará en: `https://inventario-api.onrender.com`

**Nota**: En el plan gratis, el servidor se "duerme" después de 15 min sin tráfico.
La primera request después de dormir tarda ~30 seg. Esto es normal y suficiente para empezar.

---

## Paso 3: Descargar el APK (GitHub Actions - gratis)

### Opción A: Trigger manual (recomendado la primera vez)
1. Ve a tu repo en GitHub → pestaña **"Actions"**
2. En el sidebar izquierdo, clic en **"Build & Release APK"**
3. Clic en **"Run workflow"** → **"Run workflow"**
4. Espera ~5 min a que termine
5. Clic en el workflow completado → sección **"Artifacts"** → descarga **inventario-apk**
6. Instala el APK en tu teléfono Android

### Opción B: Release automático con tag
```bash
git tag v1.1.0
git push origin v1.1.0
```
El APK aparecerá automáticamente en GitHub → Releases.

---

## Paso 4: Conectar la app al backend

En la app Flutter, actualiza la URL del backend a tu URL de Render:
```
https://inventario-api.onrender.com
```

Esto se configura en `mobile/lib/core/config/` o como variable de entorno.

---

## Resumen de costos

| Servicio | Qué hace | Costo | Límite |
|----------|----------|-------|--------|
| **Neon.tech** | PostgreSQL | $0 | 0.5 GB, sin expiración |
| **Render.com** | Backend API | $0 | Se duerme tras 15 min inactivo |
| **GitHub Actions** | Compila APK | $0 | 2,000 min/mes (sobra) |
| **GitHub Releases** | Descarga APK | $0 | Sin límite |
| **Total** | | **$0** | |

---

## Cuando tengas ingresos (upgrade sugerido)

- **Render Starter** ($7/mes): servidor siempre encendido
- **Neon Launch** ($19/mes): 10 GB, más conexiones
- O migrar a **Railway** ($5/mes): todo incluido
