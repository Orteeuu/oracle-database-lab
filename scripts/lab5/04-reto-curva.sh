#!/usr/bin/env bash
# scripts/lab5/04-reto-curva.sh — reto de la Parte E: dibuja en la terminal la curva del punto de equilibrio
# Lee la sección 3 de la última evidencia 04 y pinta, en escala logarítmica, las lecturas lógicas de cada ruta.
# Uso: bash scripts/lab5/04-reto-curva.sh | tee "$EVID_LAB5/script/$(ts)_04-reto-curva.script.log"
set -euo pipefail
source scripts/deployment/env/00-config.sh
EV=$(find "$EVID_LAB5/script" -name '*_04-agrupamiento-equilibrio.script.log' | sort | tail -1)
[ -n "$EV" ] || { echo "Falta la evidencia 04: ejecuta antes 04-agrupamiento-equilibrio.sql" >&2; exit 2; }
echo "Fuente: $EV"
echo "Escala: cada '#' = 0,1 en log10(lecturas lógicas)   (B = índice CF bueno, M = índice CF malo, T = tabla entera)"
awk '
  /^[0-9.]+ %/ {
    k = $1; b = $4; m = $5; t = $6
    printf "k=%-5s %%  B %-46s %d\n", k, barra(b), b
    printf "          M %-46s %d%s\n", barra(m), m, (m > t ? "   <- peor que la tabla" : "")
    printf "          T %-46s %d\n", barra(t), t
  }
  function barra(v,   n, s, i) { n = int(log(v) / log(10) * 10); s = ""; for (i = 0; i < n; i++) s = s "#"; return s }
' "$EV"
echo "Cruce del índice de CF malo con la tabla: entre el 0,5 % y el 1 % de las filas; el de CF bueno no cruza hasta el 10 %."
