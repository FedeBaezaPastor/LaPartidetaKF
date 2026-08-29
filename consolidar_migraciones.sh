#!/bin/bash

################################################################################
# Script para Consolidar Migraciones SQL
# La Partideta Golf V1
#
# Este script concatena todas las migraciones SQL en orden cronológico
# en un único archivo que puede ejecutarse en Supabase.
#
# Uso: ./consolidar_migraciones.sh
# Salida: schema_completo.sql (en la raíz del proyecto)
################################################################################

echo "🏌️ Consolidando migraciones de La Partideta Golf..."
echo ""

# Verificar que estamos en la raíz del proyecto
if [ ! -d "supabase/migrations" ]; then
    echo "❌ Error: No se encuentra el directorio supabase/migrations"
    echo "   Asegúrate de ejecutar este script desde la raíz del proyecto"
    exit 1
fi

# Archivo de salida
OUTPUT_FILE="schema_completo.sql"

# Limpiar archivo anterior si existe
if [ -f "$OUTPUT_FILE" ]; then
    rm "$OUTPUT_FILE"
fi

# Encabezado del archivo
cat > "$OUTPUT_FILE" << 'EOF'
-- ============================================================
-- LA PARTIDETA GOLF - ESQUEMA COMPLETO
-- ============================================================
--
-- Este archivo contiene todas las migraciones SQL consolidadas
-- en orden cronológico para recrear la base de datos completa.
--
-- Generado automáticamente desde supabase/migrations/
-- Fecha de generación: $(date)
--
-- INSTRUCCIONES:
-- 1. Crea un proyecto nuevo en Supabase
-- 2. Ve a SQL Editor
-- 3. Copia y pega todo este archivo
-- 4. Ejecuta el script
-- 5. Verifica que no hay errores
--
-- IMPORTANTE:
-- - Este script asume una base de datos limpia
-- - Si ya tienes datos, haz backup primero
-- - Algunas migraciones pueden fallar si ya existen objetos
--
-- ============================================================

EOF

echo "📝 Añadiendo encabezado..."

# Contador de migraciones
count=0

# Iterar sobre las migraciones en orden
for file in $(ls -1 supabase/migrations/*.sql | sort); do
    count=$((count + 1))
    filename=$(basename "$file")

    echo "   [$count] $filename"

    # Añadir separador y nombre de migración
    cat >> "$OUTPUT_FILE" << EOF

-- ============================================================
-- MIGRACIÓN: $filename
-- ============================================================

EOF

    # Añadir contenido de la migración
    cat "$file" >> "$OUTPUT_FILE"

    # Añadir separador final
    echo "" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
done

echo ""
echo "✅ ¡Completado!"
echo ""
echo "📊 Estadísticas:"
echo "   - Migraciones procesadas: $count"
echo "   - Archivo generado: $OUTPUT_FILE"
echo "   - Tamaño: $(wc -c < "$OUTPUT_FILE" | awk '{print int($1/1024)}') KB"
echo ""
echo "📋 Próximos pasos:"
echo "   1. Revisa el archivo $OUTPUT_FILE"
echo "   2. Ábrelo en el SQL Editor de Supabase"
echo "   3. Ejecuta el script completo"
echo "   4. Verifica que todas las tablas se crearon correctamente"
echo ""
echo "🔗 Documentación completa: GUIA_MIGRACION_V1.md"
echo ""
