# Respaldo de la base de datos (sin pagar Supabase Pro)

Supabase Pro trae backups automáticos todos los días, pero eso cuesta mensual. Mientras no
se pague ese plan, este repo tiene un reemplazo gratis: un robot de GitHub
(`.github/workflows/db-backup.yml`) que cada **lunes** guarda una copia de la base de datos,
y que tú también puedes correr a mano cuando quieras (por ejemplo justo antes de que yo
aplique un cambio grande a la base de datos).

Para que funcione necesita UN solo paso de configuración tuyo. Yo (Claude) nunca puedo
hacer este paso por ti ni escribir la contraseña en ningún lado — es una regla de
seguridad que no se salta.

## Paso único: agregar el secreto `SUPABASE_DB_URL`

### 1. Copiar la cadena de conexión desde Supabase

1. Entra a [supabase.com](https://supabase.com) e inicia sesión.
2. Abre el proyecto **Challenge Dynasty**.
3. Ve a **Project Settings** (el ícono de engranaje, abajo a la izquierda) → **Database**.
4. Busca la sección **Connection string** y entra a la pestaña **URI**.
5. Copia el texto completo. Empieza así: `postgresql://postgres:[TU-CONTRASEÑA]@...`
6. Si no te acuerdas la contraseña de la base de datos (la que está donde dice
   `[TU-CONTRASEÑA]`), en esa misma pantalla hay un botón para resetearla
   (**Reset database password**). Resetearla NO rompe nada de la app: Challenge Dynasty se
   conecta a Supabase con otras llaves (las que ya están en Vercel), no con esta
   contraseña — esta contraseña solo la usa este robot de respaldo.
7. Si la reseteaste, vuelve a copiar la cadena de conexión completa (ya con la contraseña
   nueva puesta en el lugar de `[TU-CONTRASEÑA]`).

### 2. Pegarla en GitHub como secreto

1. Entra al repositorio `9dstoreco-wq/challenge-dynasty` en GitHub.
2. Ve a **Settings** → **Secrets and variables** → **Actions**.
3. Botón **New repository secret**.
4. **Name:** `SUPABASE_DB_URL`
5. **Value:** pega ahí la cadena de conexión completa que copiaste en el paso 1.
6. **Add secret**.

Eso es todo. No hace falta tocar nada más — ni este repo, ni Vercel, ni nada de pagos.

## Cómo correrlo manualmente cuando quieras

1. En GitHub, pestaña **Actions**.
2. En la lista de la izquierda, click en **"Respaldo de la base de datos"**.
3. Botón verde **Run workflow** (arriba a la derecha) → **Run workflow** de nuevo para
   confirmar.
4. Espera uno o dos minutos y refresca — cuando termine va a quedar listo.

## Dónde quedan guardados los respaldos

En la pestaña **Releases** del repositorio
(`github.com/9dstoreco-wq/challenge-dynasty/releases`). Cada respaldo aparece como un
archivo `.dump` que no se abre como un documento normal — es solo para restaurar la base de
datos si algún día algo sale muy mal. Estos archivos quedan guardados para siempre (no se
borran solos como pasaría con otros tipos de respaldo de GitHub).

## Qué SÍ y qué NO queda respaldado

- **SÍ:** todas las tablas de la app — torneos, perfiles, retos, facturación, circuitos de
  puntos, organizaciones, todo lo que ves dentro de Challenge Dynasty.
- **NO:** las cuentas de inicio de sesión (usuario/contraseña de login) — eso lo administra
  Supabase directamente y vive en un lugar separado de la base de datos que no se puede
  restaurar manualmente de todas formas.
- **NO:** los archivos subidos (fotos de perfil, etc.) — esos viven en Supabase Storage,
  aparte de la base de datos.

## Si algún día hay que restaurar un respaldo

No es algo de un solo clic — es un paso técnico (se hace con `pg_restore` contra una base de
datos nueva). Pídeme ayuda a mí (Claude) o a alguien con conocimiento técnico cuando llegue
ese momento; lo importante por ahora es que los datos van a estar guardados y no se van a
perder.
