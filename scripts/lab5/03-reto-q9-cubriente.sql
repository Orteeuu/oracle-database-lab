-- scripts/lab5/03-reto-q9-cubriente.sql — reto de la Parte D: ¿haría cubriente a IX_PED_FECHA para Q9?
-- Mide Q9 (los 20 pedidos más recientes con todas sus columnas) tal como está y compara tamaños.
-- Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET LINESIZE 170 PAGESIZE 200 FEEDBACK OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON FORMAT WRAPPED
PROMPT == Q9 tal como está (IX_PED_FECHA + acceso a la tabla por ROWID) ==
EXEC lab_tools.medir.consulta('Q9 últimos 20', q'[SELECT * FROM tiendasur.pedido ORDER BY fecha_pedido DESC FETCH FIRST 20 ROWS ONLY]')
PROMPT == Tamaños: un índice cubriente con TODAS las columnas sería casi una copia de la tabla ==
COLUMN segment_name FORMAT A16
SELECT segment_name, segment_type, ROUND(bytes / 1048576, 1) AS mb, blocks
  FROM dba_segments WHERE owner = 'TIENDASUR' AND segment_name IN ('PEDIDO', 'IX_PED_FECHA') ORDER BY 1;
EXIT
