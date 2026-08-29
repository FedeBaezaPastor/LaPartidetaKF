# Quick Start - La Partideta Golf V1

**Guía rápida para desplegar en 30 minutos**

---

## 🚀 Paso 1: Configurar Supabase (10 min)

1. Ve a [supabase.com](https://supabase.com) y crea una cuenta
2. Click **New Project**
3. Completa:
   - Name: `La Partideta Golf`
   - Database Password: (guárdala)
   - Region: (elige la más cercana)
4. Espera 2 minutos mientras se crea

### Ejecutar Migraciones

**Opción A - Script Automático (Recomendado)**:
```bash
# Desde la raíz del proyecto
./consolidar_migraciones.sh

# Copia el contenido de schema_completo.sql
# Pégalo en Supabase SQL Editor y ejecútalo
```

**Opción B - Manual**:
1. Ve a **SQL Editor** en Supabase
2. Ejecuta cada archivo de `supabase/migrations/` en orden
3. Comienza con `20251129032653_create_golf_schema.sql`
4. Termina con `20260111223959_add_abandoned_to_scores.sql`

### Obtener Credenciales

1. Ve a **Settings** → **API**
2. Copia:
   - `Project URL` → Esta será tu `VITE_SUPABASE_URL`
   - `anon public` key → Esta será tu `VITE_SUPABASE_ANON_KEY`

---

## 📝 Paso 2: Configurar Variables de Entorno (2 min)

Crea un archivo `.env` en la raíz del proyecto:

```env
VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
VITE_SUPABASE_ANON_KEY=tu_clave_anon_aqui
VITE_ADMIN_EMAIL=tu@email.com
VITE_ADMIN_PIN=2248
```

**⚠️ Reemplaza** los valores con tus credenciales reales.

---

## 💻 Paso 3: Test Local (5 min)

```bash
# Instalar dependencias
npm install

# Verificar que compila
npm run build

# Probar localmente
npm run dev
```

Abre [http://localhost:5173](http://localhost:5173) y verifica que funciona:
- Crea una Partideta Rápida
- Añade jugadores
- Ingresa puntuaciones

---

## 🌐 Paso 4: Desplegar a Internet (10 min)

### Opción A - Vercel (Recomendado)

1. Sube tu código a GitHub:
```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/TU_USUARIO/TU_REPO.git
git push -u origin main
```

2. Ve a [vercel.com](https://vercel.com)
3. Conecta con GitHub
4. Importa tu repositorio
5. **IMPORTANTE**: Añade las variables de entorno:
   - Settings → Environment Variables
   - Añade las 4 variables del archivo `.env`
6. Deploy

### Opción B - Netlify

1. Sube tu código a GitHub (igual que arriba)
2. Ve a [netlify.com](https://netlify.com)
3. Conecta con GitHub
4. Importa tu repositorio
5. Configura:
   - Build command: `npm run build`
   - Publish directory: `dist`
6. **IMPORTANTE**: Añade las variables de entorno:
   - Site settings → Environment variables
   - Añade las 4 variables del archivo `.env`
7. Deploy

---

## ✅ Paso 5: Verificar (3 min)

Abre tu URL de producción y verifica:

- [ ] La página carga sin errores
- [ ] Puedes crear una Partideta Rápida
- [ ] Puedes añadir jugadores
- [ ] Las puntuaciones se guardan
- [ ] El leaderboard se actualiza

Si todo funciona: **¡Felicidades! 🎉**

---

## 🔧 Problemas Comunes

### "Missing environment variables"
- Verifica que las variables están en Vercel/Netlify
- Deben tener el prefijo `VITE_`
- Redeploy después de añadirlas

### "Failed to fetch"
- Verifica que `VITE_SUPABASE_URL` es correcta
- Verifica que las migraciones se ejecutaron
- Revisa la consola del navegador

### Build falla
- Corre `npm run build` localmente
- Revisa los logs de error
- Asegúrate de que Node.js >= 18

---

## 📚 Próximos Pasos

1. Lee [GUIA_MIGRACION_V1.md](./GUIA_MIGRACION_V1.md) para detalles técnicos
2. Personaliza el PIN de admin en la base de datos
3. Configura un dominio personalizado (opcional)
4. Comparte la URL con tus amigos

---

## 🆘 Ayuda

Si tienes problemas:
1. Revisa la [Guía Completa](./GUIA_MIGRACION_V1.md)
2. Verifica la sección "Problemas Comunes"
3. Revisa los logs de Vercel/Netlify
4. Revisa la consola de Supabase

---

**Tiempo total estimado**: 30 minutos
**Costo**: $0 (usando tiers gratuitos)

¡Buena suerte! 🏌️
