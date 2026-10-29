-- scripts/lab4/03-reto-omf.sql — reto de la Parte C: que un CREATE TABLESPACE sin ruta no vuelva a dejar
-- archivos fuera de su sitio. Activa Oracle Managed Files (OMF) con destino dentro del volumen.
-- Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
-- Idempotente: fijar el mismo valor otra vez no cambia nada; el tablespace de prueba se borra al final.
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET LINESIZE 160 PAGESIZE 100 FEEDBACK ON
COLUMN name FORMAT A22
COLUMN en_memoria FORMAT A24
COLUMN en_spfile FORMAT A24
COLUMN file_name FORMAT A100
PROMPT == 1. Antes: sin destino OMF ==
SELECT p.name, NVL(p.value, '(vacío)') AS en_memoria, NVL(s.value, '(no especificado)') AS en_spfile
  FROM v$parameter p JOIN v$spparameter s ON s.name = p.name
 WHERE p.name = 'db_create_file_dest';
PROMPT == 2. Cambio: SCOPE = BOTH (dinámico; efecto inmediato y persistente tras reiniciar) ==
ALTER SYSTEM SET db_create_file_dest = '/opt/oracle/oradata' COMMENT = 'Lab4 reto C: OMF dentro del volumen' SCOPE = BOTH;
SELECT p.name, p.value AS en_memoria, s.value AS en_spfile
  FROM v$parameter p JOIN v$spparameter s ON s.name = p.name
 WHERE p.name = 'db_create_file_dest';
PROMPT == 3. Prueba: CREATE TABLESPACE sin cláusula DATAFILE en FREEPDB1 ==
ALTER SESSION SET CONTAINER = FREEPDB1;
DECLARE n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_tablespaces WHERE tablespace_name = 'TBS_OMF_PRUEBA';
  IF n > 0 THEN EXECUTE IMMEDIATE 'DROP TABLESPACE tbs_omf_prueba INCLUDING CONTENTS AND DATAFILES'; END IF;
END;
/
CREATE TABLESPACE tbs_omf_prueba;
SELECT tablespace_name, file_name, ROUND(bytes / 1048576) AS mb, autoextensible
  FROM dba_data_files WHERE tablespace_name = 'TBS_OMF_PRUEBA';
PROMPT == 4. Limpieza: con OMF, DROP TABLESPACE borra también el archivo ==
DROP TABLESPACE tbs_omf_prueba INCLUDING CONTENTS AND DATAFILES;
SELECT COUNT(*) AS tbs_omf_prueba_restantes FROM dba_tablespaces WHERE tablespace_name = 'TBS_OMF_PRUEBA';
EXIT
