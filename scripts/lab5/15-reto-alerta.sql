-- scripts/lab5/15-reto-alerta.sql — reto de la Parte P: un umbral que dispare una alerta
-- Devuelve UNA fila solo cuando hay que despertar a alguien: FRA por encima del 85 % o ninguna copia RMAN en 24 h.
-- Sin filas = todo bien. Es la forma de conectar el runbook a un sistema de alertas (cron, Prometheus, OEM...).
-- SQLcl · C##OPS_RO · servicio FREE: bash scripts/ops/ro.sh scripts/lab5/15-reto-alerta.sql
@scripts/ops/marca
SPOOL docs/bitacora/lab5/evidencia/spool/&marca._15-reto-alerta.spool.log
SET SQLFORMAT DEFAULT
SET LINESIZE 160 PAGESIZE 50 FEEDBACK ON
COLUMN alerta FORMAT A120
PROMPT == Alerta (sin filas = no hay que despertar a nadie) ==
SELECT 'ALERTA: ' ||
       CASE WHEN f.pct > 85 THEN 'FRA al ' || f.pct || ' % (límite ' || f.limite_mb || ' MB). ' END ||
       CASE WHEN b.ultima IS NULL OR b.ultima < SYSDATE - 1
            THEN 'Sin copia RMAN en 24 h (última: ' || NVL(TO_CHAR(b.ultima, 'YYYY-MM-DD HH24:MI'), 'nunca') || ').' END AS alerta
  FROM (SELECT ROUND(100 * space_used / NULLIF(space_limit, 0), 1) AS pct, ROUND(space_limit / 1048576) AS limite_mb
          FROM v$recovery_file_dest) f,
       (SELECT MAX(completion_time) AS ultima FROM v$backup_set) b
 WHERE f.pct > 85 OR b.ultima IS NULL OR b.ultima < SYSDATE - 1;
PROMPT == Los dos valores medidos, para la evidencia ==
SELECT ROUND(100 * space_used / NULLIF(space_limit, 0), 1) AS fra_pct_usada FROM v$recovery_file_dest;
SELECT TO_CHAR(MAX(completion_time), 'YYYY-MM-DD HH24:MI') AS ultima_copia_rman FROM v$backup_set;
SPOOL OFF
