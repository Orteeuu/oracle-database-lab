#!/usr/bin/env bash
# scripts/lab5/12-reto-coste-fra.sh — reto de la Parte M: cuánto crece la FRA por el redo de 12-undo-y-redo.sql
# Mide space_used de la FRA, repite el experimento de undo/redo, fuerza el archivado y vuelve a medir.
# Uso: bash scripts/lab5/12-reto-coste-fra.sh | tee "$EVID_LAB5/script/$(ts)_12-reto-coste-fra.script.log"
set -euo pipefail
source scripts/deployment/env/00-config.sh
usado() {
  printf "SET HEADING OFF FEEDBACK OFF PAGESIZE 0\nALTER SYSTEM ARCHIVE LOG CURRENT;\nSELECT ROUND(space_used / 1024) FROM v\$recovery_file_dest;\nEXIT\n" \
    | docker exec -i "$CONT_NAME" sqlplus -s -L / as sysdba | tr -dc '0-9'
}
ANTES=$(usado)
echo "FRA usada antes (tras archivar el log actual): ${ANTES} KB"
echo "== Repetición de 12-undo-y-redo.sql (INSERT, UPDATE y DELETE de 10 000 pedidos, con sus ROLLBACK) =="
bash scripts/ops/sysdba.sh scripts/lab5/12-undo-y-redo.sql | grep -E 'redo|ROLLBACK' || true
DESPUES=$(usado)
echo "FRA usada después de ARCHIVE LOG CURRENT: ${DESPUES} KB"
echo "Crecimiento de la FRA: $(( (DESPUES - ANTES) / 1024 )) MB ($((DESPUES - ANTES)) KB)"
echo "(Compáralo con la suma de la columna 'redo total' y 'redo generado al deshacer' de arriba: todo ese redo acaba archivado)"
