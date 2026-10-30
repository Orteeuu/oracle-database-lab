-- scripts/lab5/10-reto-dimensionar-redo.sql — reto de la Parte K: ¿cuántos cambios de log provocó la carga de TiendaSur?
-- Regla habitual: dimensionar los grupos para unos 4 cambios por hora en la carga de pico (uno cada 15 min).
-- Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET LINESIZE 150 PAGESIZE 100 FEEDBACK OFF
PROMPT == Cambios de log por hora de hoy (v$log_history) ==
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS hora, COUNT(*) AS cambios
  FROM v$log_history WHERE first_time > SYSDATE - 1
 GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD HH24') ORDER BY 1;
PROMPT == Tamaño actual de cada grupo ==
SELECT group#, ROUND(bytes / 1048576) AS mb, members, status FROM v$log ORDER BY group#;
PROMPT == Redo generado por hora (archivados): base para proponer el tamaño ==
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS hora, COUNT(*) AS archivados,
       ROUND(SUM(blocks * block_size) / 1048576) AS mb_redo,
       CEIL(SUM(blocks * block_size) / 1048576 / 4) AS mb_por_grupo_para_4_cambios_hora
  FROM v$archived_log WHERE first_time > SYSDATE - 1 AND name IS NOT NULL
 GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD HH24') ORDER BY 1;
EXIT
