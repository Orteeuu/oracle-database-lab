-- scripts/lab4/08-reto-literales.sql — reto de la Parte G: sentencias que la aplicación ejecuta con LITERALES
-- Agrupa V$SQL por FORCE_MATCHING_SIGNATURE (misma sentencia salvo los literales) y muestra las firmas
-- con más de 50 cursores distintos. Ejecutar justo después de 08-parse-y-pga.sql (SQLcl · C##OPS_RO · FREE):
--   bash scripts/ops/ro.sh scripts/lab4/08-reto-literales.sql
@scripts/ops/marca
SPOOL docs/bitacora/lab4/evidencia/spool/&marca._08-reto-literales.spool.log
SET SQLFORMAT DEFAULT
SET LINESIZE 200 PAGESIZE 100 FEEDBACK OFF
COLUMN firma FORMAT 99999999999999999999
COLUMN contenedor FORMAT A10
COLUMN ejemplo FORMAT A90
PROMPT == Firmas con más de 50 cursores distintos (candidatas a variables de enlace) ==
SELECT s.force_matching_signature AS firma,
       c.name AS contenedor,
       COUNT(*) AS cursores,
       SUM(s.executions) AS ejecuciones,
       ROUND(SUM(s.sharable_mem) / 1024) AS kb_shared_pool,
       MIN(SUBSTR(s.sql_text, 1, 90)) AS ejemplo
  FROM v$sql s JOIN v$containers c ON c.con_id = s.con_id
 WHERE s.force_matching_signature <> 0
 GROUP BY s.force_matching_signature, c.name
HAVING COUNT(*) > 50
 ORDER BY cursores DESC
 FETCH FIRST 10 ROWS ONLY;
SPOOL OFF
