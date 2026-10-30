-- scripts/lab5/01-reto-bfr-pedido.sql — reto de la Parte B: filas por bloque de TIENDASUR.PEDIDO, contadas con DBMS_ROWID
-- Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET LINESIZE 160 PAGESIZE 100 FEEDBACK OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
PROMPT == Filas por bloque REALES (agrupando por archivo y bloque del ROWID) ==
SELECT COUNT(*) AS bloques_con_filas, MIN(n) AS minimo, ROUND(AVG(n), 1) AS media, MAX(n) AS maximo
  FROM (SELECT DBMS_ROWID.ROWID_RELATIVE_FNO(ROWID, 'BIGFILE') AS f,
               DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE') AS b, COUNT(*) AS n
          FROM tiendasur.pedido GROUP BY DBMS_ROWID.ROWID_RELATIVE_FNO(ROWID, 'BIGFILE'),
                                         DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE'));
PROMPT == Lo que dicen las estadísticas: NUM_ROWS / BLOCKS (bloques bajo la HWM, también los vacíos) ==
SELECT num_rows, blocks, ROUND(num_rows / blocks, 1) AS filas_por_bloque_estadistica, avg_row_len, pct_free
  FROM dba_tables WHERE owner = 'TIENDASUR' AND table_name = 'PEDIDO';
SELECT tablespace_name, bigfile, block_size FROM dba_tablespaces
 WHERE tablespace_name = (SELECT tablespace_name FROM dba_tables WHERE owner = 'TIENDASUR' AND table_name = 'PEDIDO');
EXIT
