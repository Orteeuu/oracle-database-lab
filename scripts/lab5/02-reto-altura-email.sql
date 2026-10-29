-- scripts/lab5/02-reto-altura-email.sql — reto de la Parte C: comprobar la altura calculada de UX_CLI_EMAIL
-- VALIDATE STRUCTURE rellena INDEX_STATS solo en la sesión que lo ejecuta (y bloquea la tabla: solo en laboratorio).
-- Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET LINESIZE 170 PAGESIZE 100 FEEDBACK OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
PROMPT == Diccionario: BLEVEL (altura - 1), hojas y claves distintas ==
SELECT index_name, blevel, blevel + 1 AS altura, leaf_blocks, distinct_keys, num_rows
  FROM dba_indexes WHERE owner = 'TIENDASUR' AND index_name IN ('UX_CLI_EMAIL', 'IX_PED_CLIENTE');
ANALYZE INDEX tiendasur.ux_cli_email VALIDATE STRUCTURE;
PROMPT == INDEX_STATS de UX_CLI_EMAIL: la medida que confirma (o no) el cálculo a mano ==
SELECT name, height, lf_rows, lf_blks, ROUND(lf_rows / lf_blks) AS entradas_por_hoja,
       br_blks, ROUND(lf_rows_len / lf_rows, 1) AS bytes_por_entrada, pct_used
  FROM index_stats;
EXIT
