-- scripts/lab4/13-reto-matriculas.sql — reto de la Parte L: datos medidos de ACA_MATRICULAS para contrastar
-- la predicción de la fórmula de la Unidad 3 (bfr = floor((B-96)·(1-PCTFREE)/R), b = ceil(r/bfr)).
-- SQLcl · C##OPS_RO · servicio FREEPDB1: bash scripts/ops/ro.sh scripts/lab4/13-reto-matriculas.sql FREEPDB1
@scripts/ops/marca
SPOOL docs/bitacora/lab4/evidencia/spool/&marca._13-reto-matriculas.spool.log
SET SQLFORMAT DEFAULT
SET LINESIZE 180 PAGESIZE 100 FEEDBACK OFF
COLUMN table_name FORMAT A16
PROMPT == Estadísticas del optimizador (DBMS_STATS de V002) ==
SELECT table_name, num_rows, avg_row_len, blocks, empty_blocks, pct_free,
       FLOOR((8192 - 96) * (1 - pct_free / 100) / avg_row_len) AS bfr_formula,
       CEIL(num_rows / FLOOR((8192 - 96) * (1 - pct_free / 100) / avg_row_len)) AS bloques_formula
  FROM dba_tables
 WHERE owner = 'ADMIN_ACADEMIA' AND table_name IN ('ACA_ESTUDIANTES', 'ACA_MATRICULAS')
 ORDER BY table_name;
-- (C##OPS_RO no lee filas de negocio: mínimo privilegio. El recuento por DBMS_ROWID se hace como SYSDBA en 13-capacidad.sql)
PROMPT == Segmento (incluye cabecera y bloques por encima de la HWM) ==
SELECT segment_name, blocks, extents, ROUND(bytes / 1048576, 2) AS mb
  FROM dba_segments WHERE owner = 'ADMIN_ACADEMIA' AND segment_name = 'ACA_MATRICULAS';
SPOOL OFF
