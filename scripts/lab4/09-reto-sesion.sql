-- scripts/lab4/09-reto-sesion.sql — reto de la Parte H: la sesión que más consume ahora mismo
-- SID, SPID en Linux y PGA usada de las sesiones de usuario activas (SQLcl · C##OPS_RO · servicio FREE).
-- Ejecútalo mientras otra sesión lanza una consulta larga: bash scripts/ops/ro.sh scripts/lab4/09-reto-sesion.sql
@scripts/ops/marca
SPOOL docs/bitacora/lab4/evidencia/spool/&marca._09-reto-sesion.spool.log
SET SQLFORMAT DEFAULT
SET LINESIZE 200 PAGESIZE 100 FEEDBACK OFF
COLUMN username FORMAT A12
COLUMN contenedor FORMAT A10
COLUMN spid FORMAT A8
COLUMN sql_text FORMAT A70
PROMPT == Sesiones de usuario ACTIVAS ordenadas por PGA (la primera es la que más consume) ==
SELECT s.sid, s.serial#, s.username, c.name AS contenedor, p.spid,
       ROUND(p.pga_used_mem / 1048576, 1) AS pga_usada_mb,
       ROUND(p.pga_alloc_mem / 1048576, 1) AS pga_asignada_mb,
       s.last_call_et AS segundos_activa,
       SUBSTR(q.sql_text, 1, 70) AS sql_text
  FROM v$session s
  JOIN v$process p ON p.addr = s.paddr
  JOIN v$containers c ON c.con_id = s.con_id
  LEFT JOIN v$sql q ON q.sql_id = s.sql_id AND q.child_number = s.sql_child_number
 WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND s.sid <> SYS_CONTEXT('USERENV', 'SID')
 ORDER BY p.pga_used_mem DESC;
SPOOL OFF
