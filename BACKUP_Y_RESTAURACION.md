# Guía de Backup y Restauración - La Partideta Golf

## Versión Estable: v1.0-estable (15 Enero 2026)

Esta guía te explica cómo hacer y restaurar copias de seguridad completas de tu aplicación.

**IMPORTANTE:** Esta versión incluye el fix del sistema de cervezas usando ranking global del día.

---

## 📦 ¿Qué incluye una copia completa?

Tu aplicación tiene **2 componentes principales**:

### 1. **Código de la Aplicación (Frontend)**
- Todos los archivos de React/TypeScript
- Componentes, estilos, configuración
- **Guardado en:** Git con el tag `v1.0-estable`

### 2. **Base de Datos (Supabase)**
- Jugadores, rondas, estadísticas
- Campos de golf, configuración
- **Guardado en:** Supabase (en la nube)

---

## 💾 Cómo descargar una copia completa

### Opción 1: Descargar código + exportar base de datos (RECOMENDADO)

#### Paso 1: Descargar el código
```bash
# Si estás trabajando localmente
zip -r golf-app-backup-15-enero-2026.zip . -x "node_modules/*" ".git/*"
```

Esto crea un archivo `golf-app-backup-15-enero-2026.zip` con todo el código.

#### Paso 2: Exportar la base de datos desde Supabase

1. Ve a tu proyecto en [Supabase Dashboard](https://supabase.com/dashboard)
2. Haz clic en **Database** → **Backups** (panel izquierdo)
3. Haz clic en **"Create backup"** o descarga el backup automático más reciente
4. Guarda el archivo `.sql` en lugar seguro

**Alternativa manual:**
1. Ve a **SQL Editor** en Supabase
2. Ejecuta este comando para exportar datos:

```sql
-- Exportar jugadores
COPY (SELECT * FROM players) TO STDOUT WITH CSV HEADER;

-- Exportar rondas archivadas
COPY (SELECT * FROM archived_rounds) TO STDOUT WITH CSV HEADER;

-- Exportar rankings
COPY (SELECT * FROM daily_rankings) TO STDOUT WITH CSV HEADER;

-- (Repetir para cada tabla importante)
```

3. Guarda cada resultado en archivos CSV

---

### Opción 2: Solo código (más rápido pero sin datos)

```bash
# Comprimir solo el código
zip -r golf-app-codigo.zip . -x "node_modules/*" ".git/*" "*.env"
```

---

## 🔄 Cómo restaurar desde un backup

### Restaurar el Código

```bash
# 1. Descomprimir
unzip golf-app-backup-15-enero-2026.zip -d golf-app-restaurado

# 2. Entrar al directorio
cd golf-app-restaurado

# 3. Instalar dependencias
npm install

# 4. Configurar variables de entorno
cp .env.example .env
# Editar .env con tus credenciales de Supabase

# 5. Arrancar la aplicación
npm run dev
```

### Restaurar la Base de Datos

#### Opción A: Desde backup de Supabase
1. Ve a **Database** → **Backups** en Supabase Dashboard
2. Selecciona el backup que quieres restaurar
3. Haz clic en **"Restore"**
4. Confirma la restauración

#### Opción B: Desde SQL manual
1. Ve a **SQL Editor** en Supabase
2. Ejecuta las migraciones en orden (carpeta `supabase/migrations/`)
3. Si tienes un dump SQL, ejecútalo:
   - Haz clic en **"New query"**
   - Pega el contenido del archivo `.sql`
   - Haz clic en **"Run"**

---

## 📋 Versiones guardadas

### v1.0-estable (15 Enero 2026)
- **Tag Git:** `v1.0-estable`
- **Commit:** `f27936f`
- **Estado:** Rey del Bosque funcionando, todas las estadísticas verificadas
- **Migraciones:** Hasta `20260115112925_fix_rey_del_bosque_include_triple_bogey_plus.sql`

Para volver a esta versión:
```bash
git checkout v1.0-estable
```

---

## 🆘 Problemas comunes

### "No tengo Git instalado"
Simplemente copia toda la carpeta del proyecto a otro lugar seguro (USB, Dropbox, etc.)

### "Perdí los datos de Supabase"
Si no tienes backup de Supabase:
1. Las migraciones recrearán la estructura vacía
2. Tendrás que volver a introducir los datos manualmente
3. **Por eso es importante hacer backups regulares**

### "¿Con qué frecuencia debo hacer backups?"
- **Código:** Cada vez que funcione bien algo importante
- **Base de datos:**
  - Automático: Supabase hace backups diarios
  - Manual: Antes de cambios grandes o cada semana

---

## 💡 Mejores Prácticas

1. **Antes de hacer cambios grandes:** Crear un tag git nuevo
2. **Después de cada partida importante:** Exportar datos de Supabase
3. **Usar múltiples copias:** Local + nube (Dropbox, Google Drive, etc.)
4. **Nombrar claramente:** Incluir fecha en nombre del backup
5. **Probar restauración:** De vez en cuando, probar que los backups funcionan

---

## 📞 Comandos Rápidos de Referencia

```bash
# Crear nuevo tag de versión
git tag -a v1.1-nombre -m "Descripción de la versión"

# Ver todas las versiones
git tag -l

# Volver a una versión anterior
git checkout v1.0-estable

# Crear backup del código (ZIP)
zip -r backup-$(date +%Y%m%d).zip . -x "node_modules/*" ".git/*"

# Ver qué cambió desde la última versión
git diff v1.0-estable
```

---

## ✅ Checklist de Backup Completo

- [ ] Código comprimido en ZIP
- [ ] Base de datos exportada desde Supabase
- [ ] Archivo `.env.example` actualizado
- [ ] Tag de Git creado con nombre descriptivo
- [ ] Backup guardado en 2 lugares diferentes
- [ ] Fecha del backup anotada
- [ ] Probado que se puede restaurar

---

## 🔧 Sección Técnica: Archivos SQL Maestros

### Archivos principales del proyecto

#### 1. `01_structure_and_logic_master.sql`
**Descripción:** Estructura completa de la base de datos y lógica de negocio

**Contiene:**
- DDL completo (CREATE TABLE)
- Índices para optimización
- Row Level Security (RLS) con políticas públicas
- Todas las funciones RPC (get_divend_statistics, get_detailed_player_statistics, etc.)
- Triggers automáticos (calculate_daily_ranking, update_player_name, etc.)

**Cuándo usarlo:**
- Para recrear la base de datos desde cero
- Para migrar a un nuevo proyecto de Supabase
- Cuando faltan funciones o tablas

#### 2. `02_clean_data_seeds.sql`
**Descripción:** Datos iniciales de campos de golf

**Contiene:**
- 4 campos de golf (Costa Azahar Verde, Rojo, Mediterráneo, Panorámica)
- Todos los hoyos de cada campo (72 hoyos en total)
- Tees con slopes configurados
- 22 jugadores del grupo DIVEND con handicaps

**Cuándo usarlo:**
- Después de ejecutar `01_structure_and_logic_master.sql`
- Para resetear los datos a valores iniciales conocidos

#### 3. `backup_completo_15_enero_2026.sql`
**Descripción:** Backup básico con datos actuales

**Contiene:**
- Grupo DIVEND
- Jugadores con handicaps actualizados al 15/01/2026
- Configuración de administrador

**Cuándo usarlo:**
- Para restaurar jugadores con handicaps correctos
- Para añadir datos sobre una estructura ya creada

#### 4. `backup_datos_15_enero_2026.sql`
**Descripción:** Backup completo de datos históricos

**Contiene:**
- Todas las partidas archivadas con resultados completos
- Rankings diarios calculados
- Historial de cambios de handicap
- Estadísticas de jugadores

**Cuándo usarlo:**
- Para restaurar el historial completo de partidas
- Para recuperar estadísticas y rankings históricos

### Orden de ejecución para restauración completa

```bash
# PASO 1: Crear estructura vacía
# Ejecutar: 01_structure_and_logic_master.sql

# PASO 2: Insertar datos de campos y jugadores iniciales
# Ejecutar: 02_clean_data_seeds.sql

# PASO 3 (Opcional): Actualizar jugadores con handicaps correctos
# Ejecutar: backup_completo_15_enero_2026.sql

# PASO 4 (Opcional): Restaurar partidas históricas
# Ejecutar: backup_datos_15_enero_2026.sql
```

### Verificación post-restauración

```sql
-- 1. Contar tablas
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema = 'public';
-- Debería devolver: 15 tablas

-- 2. Contar funciones RPC
SELECT COUNT(*) FROM information_schema.routines
WHERE routine_schema = 'public' AND routine_type = 'FUNCTION';
-- Debería devolver: ~15-20 funciones

-- 3. Verificar jugadores
SELECT COUNT(*) FROM players;
-- Debería devolver: 22 jugadores

-- 4. Verificar campos de golf
SELECT COUNT(*) FROM golf_courses;
-- Debería devolver: 4 campos

-- 5. Verificar hoyos
SELECT COUNT(*) FROM golf_holes;
-- Debería devolver: 72 hoyos (4 campos × 18 hoyos)

-- 6. Verificar que las funciones críticas existen
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
  'calculate_daily_ranking',
  'get_divend_statistics',
  'get_detailed_player_statistics',
  'get_driver_oro_ranking',
  'get_maquina_ranking'
);
-- Debería devolver las 5 funciones

-- 7. Verificar RLS activado
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND rowsecurity = true;
-- Todas las tablas deberían tener RLS activado
```

### Notas Importantes

- **NUNCA** ejecutes `01_structure_and_logic_master.sql` en producción sin backup previo (elimina TODAS las tablas)
- Los archivos SQL están ordenados: primero estructura, luego datos
- El sistema de cervezas usa ranking global del día (corregido el 15/01/2026)
- Todos los triggers se recrean automáticamente con el archivo de estructura

---

**Última actualización:** 15 de Enero de 2026
**Versión estable actual:** v1.0-estable
**Fix incluido:** Sistema de cervezas con ranking global diario
