-- scripts/lab5/08-reto-mttr.sql — reto de la Parte I: el MTTR estimado bajo carga
-- Mismo UPDATE que el paso 1 de 13-lgwr-dbwn.sql (20 000 filas, sin cambiar el valor), SIN checkpoint:
-- el redo pendiente de aplicar en una recuperación (actual_redo_blks) y el MTTR estimado crecen.
-- Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET LINESIZE 150 PAGESIZE 100 FEEDBACK OFF
COLUMN momento FORMAT A28
PROMPT == 0. Partimos de un checkpoint para que la comparación sea limpia ==
ALTER SYSTEM CHECKPOINT;
SELECT 'antes del UPDATE' AS momento, estimated_mttr, actual_redo_blks, target_redo_blks FROM v$instance_recovery;
PROMPT == 1. UPDATE de 20 000 filas + COMMIT (sin checkpoint) ==
ALTER SESSION SET CONTAINER = FREEPDB1;
UPDATE admin_academia.aca_estudiantes SET estado = estado;
COMMIT;
ALTER SESSION SET CONTAINER = CDB$ROOT;
SELECT 'después del UPDATE' AS momento, estimated_mttr, actual_redo_blks, target_redo_blks FROM v$instance_recovery;
PROMPT (actual_redo_blks = bloques de redo que habría que aplicar si la instancia cayera ahora; estimated_mttr en segundos)
EXIT
