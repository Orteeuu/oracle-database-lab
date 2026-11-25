# Respuestas · Lab 6 · E051

Rutas de evidencia relativas a `docs/bitacora/lab6/evidencia/` (salvo que se indique otra).

## Preguntas de comprobación

### 1. ¿Cuántos errores ORA- tenía tu alert log en 24 h en la Parte B y a qué se debían? ¿Por qué ese número no es una alarma por sí solo?

- Dónde mirar: 01-turno (sección 4)
- RESPUESTA: Salieron 5 ORA- en 24h (avisos ORA-00800 en VKTM/LGWR y fallos ORA-12012/ORA-00001 de un job). Los ORA-65019 y ORA-01536 de las pruebas vinieron despues. Había 0 bloqueos y 0 alertas, pero el job conviene mirarlo.
- Evidencia (archivo y valor): `20261117T224547Z_01-turno.script.log`, `V$DIAG_ALERT_EXT`

### 2. ¿A qué hora empieza y cuánto dura la ventana de mantenimiento de un miércoles en tu base? ¿Qué tareas automáticas corren en ella?

- Dónde mirar: 01-automatizacion (spool/, secciones 1 y 2)
- RESPUESTA: WEDNESDAY_WINDOW va de 22:00 a 02:00 (4h). Los tres clientes automáticos (stats, space advisor y sql tuning advisor) estaban ENABLED, o sea que podían correr, no que todos hicieran trabajo esa noche.
- Evidencia (archivo y valor): `20261117T224555Z_01-automatizacion.spool.log`

### 3. Explica con tu salida de la Parte C la diferencia entre lo que mostraban V$SPPARAMETER y V$PARAMETER tras el SCOPE = SPFILE. ¿Qué habría pasado en el siguiente reinicio sin el RESET?

- Dónde mirar: 02-parametros (sección 5)
- RESPUESTA: db_files estaba a 200 en memoria y sin poner en SPFILE (ISSPECIFIED=FALSE). SCOPE=MEMORY dio ORA-02095; SCOPE=SPFILE puso 250 en V$SPPARAMETER pero V$PARAMETER siguió en 200 hasta reiniciar. Sin RESET habría arrancado con 250.
- Evidencia (archivo y valor): `20261117T225025Z_02-parametros.script.log`

### 4. ¿Por qué RESET fue la vuelta atrás correcta para db_files y no lo habría sido para processes? Cita la línea de tu PFILE que lo demuestra.

- Dónde mirar: 02-parametros y config/*_02-init_desde_spfile.ora (línea processes)
- RESPUESTA: RESET servía en db_files porque no estaba fijado en el SPFILE y volvía a su defecto (200). En processes hay *.processes=200 en el PFILE, así que toca reponer 200. Cambiar processes desde la PDB dio ORA-65040 porque es de CDB.
- Evidencia (archivo y valor): `20261117T225026Z_02-init_desde_spfile.ora`, `20261117T225025Z_02-parametros.script.log`

### 5. Tras el reinicio sin estado guardado, ¿qué error obtuvo C##OPS_RO y por qué la instancia decía «Database opened»?

- Dónde mirar: 02-estados-pdb (sección 4)
- RESPUESTA: C##OPS_RO dio ORA-01109 porque al reiniciar se abrió la CDB FREE pero FREEPDB1 quedó MOUNTED sin SAVE STATE. Que abra la CDB no abre las PDB. Lo de ORA-1035 de otro momento era por modo restringido.
- Evidencia (archivo y valor): `20261117T225051Z_02-estados-pdb.script.log`

### 6. ¿Qué SID, SPID y evento tenía la sesión de la aplicación en tu ejecución? ¿Qué te dicen MODULE, ACTION y CLIENT_IDENTIFIER que no te diría USERNAME?

- Dónde mirar: 03-sesiones
- RESPUESTA: Sesión APP_ACADEMIA: SID 229, SERIAL# 39639, SPID 2473, evento PL/SQL lock timer, servicio academia_app, MODULE=matriculas, ACTION=cierre-periodo y CLIENT_IDENTIFIER=ana.garcia@ucam. Sirven para ver módulo, acción y usuario real más allá del USERNAME técnico.
- Evidencia (archivo y valor): `20261117T225625Z_03-sesiones.script.log`

### 7. Tras CANCEL SQL, ¿cuántas transacciones abiertas tenía la aplicación? ¿Y tras KILL SESSION? ¿En qué estado quedó la fila 101 y por qué?

- Dónde mirar: 03-sesiones
- RESPUESTA: Tras CANCEL SQL quedó 1 transacción abierta (se cortó SLEEP(40), pero el UPDATE no hizo commit ni rollback). Con KILL SESSION '229,39639' IMMEDIATE dio ORA-00031, cerró la sesión, quedó en 0 sesiones vivas y el alumno 101 siguió ACTIVO.
- Evidencia (archivo y valor): `20261117T225625Z_03-sesiones.script.log`

### 8. ¿Qué valor tiene common_user_prefix en tu imagen? ¿Qué implica para el nombre de una cuenta común?

- Dónde mirar: 03-cuenta-app
- RESPUESTA: common_user_prefix vale C##, así que los usuarios comunes de la CDB llevan C## (como C##OPS_RO). APP_ACADEMIA es local de FREEPDB1 y no lo necesita.
- Evidencia (archivo y valor): `SHOW PARAMETER common_user_prefix`, 17/11/2026 23:43:34 UTC

### 9. Completa con tus cifras la tabla de las tres miradas (ALL_TABLES, DBA_USERS, CDB_USERS, V$DATAFILE) y explica una diferencia.

- Dónde mirar: 04-tres-miradas
- RESPUESTA: C##OPS_RO en CDB$ROOT ve varios contenedores; en FREEPDB1 solo lo local. APP_ACADEMIA ve su tabla de negocio (1), pero ORA-00942 en vistas admin es falta de permisos, no cero filas.
- Evidencia (archivo y valor): `20261117T225814Z_04-tres-miradas.script.log`

### 10. Con tu salida de 04-deltas: ¿cuántas lecturas lógicas por recorrido y cuánto DB time costó la carga? ¿Qué indica la relación entre DB time y DB CPU?

- Dónde mirar: 04-deltas
- RESPUESTA: 10 full scans de PEDIDO (1M filas) dieron 53.403 lecturas lógicas (~5.340/vez), DB time 0,40 s, DB CPU 0,37 s y elapsed 0,40 s. Dominó la CPU con pocas esperas; vale solo para esta carga.
- Evidencia (archivo y valor): `20261117T225829Z_04-deltas.script.log`

### 11. Da las tres medidas (asignado, libre, máximo) de TBS_ACADEMIA_HIST antes de la carga y explica cuál usarías para alertar.

- Dónde mirar: 05-almacenamiento
- RESPUESTA: TBS_ACADEMIA_HIST tenía 10 MB (3,9 MB libres) y tope de 40 MB por autoextensión (15,16 % del máximo). Mejor alertar por porcentaje sobre el máximo y margen de crecimiento (umbrales 80 % / 95 %), no solo por los 3,9 MB actuales.
- Evidencia (archivo y valor): `*_05-almacenamiento.script.log`

### 12. ¿Quién insertó y quién «pagó» en el ORA-01950? ¿Por qué ampliar el tablespace no habría resuelto el ORA-01536?

- Dónde mirar: 05-almacenamiento
- RESPUESTA: El INSERT lo lanzó SYSDBA pero el segmento es de CARGA_HIST, que es quien necesita cuota. Sin cuota dio ORA-01950; con 2 MB dio ORA-01536 al pasarse. Autoextender el tablespace no arregla el tope de cuota del usuario.
- Evidencia (archivo y valor): `*_05-almacenamiento.script.log`

### 13. ¿Cuánto tiempo estuvo suspendida la carga reanudable y qué evidencia de ello dejó Oracle en el alert log?

- Dónde mirar: 05-resumable
- RESPUESTA: La carga resumable se pausó con ORA-01536 por cuota de CARGA_HIST (SUSPENDED, TIMEOUT 180 s, 2 s en espera al consultar; 14 s totales entre 23:01:26 y 23:01:40). Al subir cuota a 30 MB siguió y confirmó 20.000 filas (23 MB).
- Evidencia (archivo y valor): `20261117T230125Z_05-resumable.script.log`

### 14. Antes y después del SHRINK: filas, bloques y cuota consumida. ¿Por qué un DELETE no devolvió el espacio?

- Dónde mirar: 05-hwm-shrink
- RESPUESTA: 20.000 filas ocupaban 2.944 bloques (23 MB). Borrar 18.000 filas dejó 2.000 pero mantuvo 2.944 bloques y 23 MB. Con row movement y SHRINK SPACE bajó a 304 bloques y 2,4 MB porque DELETE no baja el HWM y SHRINK sí compacta.
- Evidencia (archivo y valor): `20261117T230141Z_05-hwm-shrink.script.log`

### 15. ¿Qué valores tenía tu perfil DEFAULT? Justifica dos de los límites de PRF_PERSONAS para una persona de secretaría. 103 Administración de Bases de Datos

- Dónde mirar: 06-gobierno-acceso
- RESPUESTA: DEFAULT tenía 10 intentos fallidos, 180d caducidad, 7d gracia, 1d bloqueo, INACTIVE_ACCOUNT_TIME=365 y sin función de complejidad. PRF_PERSONAS bajó a 3 intentos y pidió complejidad (ORA-28003 si menos de 8 chars); el bloqueo de 1 min era de prueba.
- Evidencia (archivo y valor): `*_06-gobierno-acceso.script.log`

### 16. ¿Por qué Ana pudo leer ACA_MATRICULAS si nadie se la concedió por nombre? ¿Qué error obtuvo al cambiar el nombre de un alumno?

- Dónde mirar: 06-probar-acceso
- RESPUESTA: ANA_GARCIA leía ACA_MATRICULAS por ROL_LECTURA_ACADEMIA (lectura de esquema ADMIN_ACADEMIA) y solo podía actualizar ESTADO en ACA_ESTUDIANTES; tocar NOMBRES dio ORA-41900 por mínimo privilegio.
- Evidencia (archivo y valor): `*_06-gobierno-acceso.script.log`, `*_06-sesion-ana.script.log`

### 17. ¿Qué objetos se invalidaron en cada uno de los tres cambios de columna y por qué no se invalidó nada con la columna nueva?

- Dónde mirar: 07-objetos
- RESPUESTA: En ACA_EST_LAB6: añadir TELEFONO no invalidó nada (0); ampliar EMAIL_INSTITUCIONAL invalidó V_CONTACTO_LAB6; ampliar NOMBRES invalidó V_ACTIVOS_LAB6, V_CONTACTO_LAB6 y F_TOTAL_ACTIVOS_LAB6 (por dependencia).
- Evidencia (archivo y valor): `*_07-objetos.script.log`

### 18. Según tus advisors, ¿mejoraría el DB time duplicar la SGA? ¿Y por debajo de qué tamaño la PGA tendría sobreasignaciones?

- Dónde mirar: 07-memoria
- RESPUESTA: SGA en 1.536 MB dio ESTD_DB_TIME_FACTOR=1 y al doblar a 3.072 MB seguía igual (factor 2 sin mejora). PGA en 512 MB tenía 0 sobreasignaciones, igual que en 384 MB; en 256 y 128 MB ya salían 4 sobreasignaciones.
- Evidencia (archivo y valor): `*_07-*`

### 19. ¿Cuántas lecturas lógicas necesitó la consulta de la aplicación según la traza (o tkprof)? ¿Qué línea de la traza lo dice?

- Dónde mirar: 07-adr-trazas
- RESPUESTA: En la traza salía FETCH ... cr=247 (247 lecturas lógicas en el fetch) y en tkprof 249 en total sumando fases; encajan ambos datos y 247 es la del fetch.
- Evidencia (archivo y valor): `20261117T230603Z_07-adr-trazas.script.log`

### 20. Para cada incidente de la guardia: evidencia clave, intervención y validación (una línea por cada uno). 104

- Dónde mirar: 08-diagnostico-inc1/inc2/inc3, 08-inc*-...
- RESPUESTA: INC-601 (enq: TX lock en SID 63,7010): KILL SESSION '63,7010' IMMEDIATE y alumno 101 ACTIVO. INC-602 (ORA-12514): START_SERVICE('academia_app'), guardar estado y ALTER SYSTEM REGISTER; servicio READY y 17.600 alumnos. INC-603 (ORA-28000): ACCOUNT UNLOCK y app conectando bien.
- Evidencia (archivo y valor): `lab6-guardia.md`, `*_08-inc601/602/603-*.script.log`

## Simulacro 1Z0-182 (letra y Parte donde lo comprobé)

### S1. ¿Qué proceso genera las alertas de umbral de espacio de los tablespaces? A. SMON B. MMON C. CJQ0 D. LGWR

- RESPUESTA:
- Parte:

### S2. Un parámetro tiene ISSYS_MODIFIABLE = DEFERRED. ¿Qué ocurre con ALTER SYSTEM SET ... DEFERRED SCOPE = BOTH? A. Cambia para todas las sesiones de inmediato. B. Solo se aplica en el próximo arranque. C. Se aplica a las sesiones que se conecten a partir de ese momento. D. Da ORA-02095.

- RESPUESTA:
- Parte:

### S3. ¿Qué sentencia crea una copia de texto de los parámetros en uso, incluidos los calculados por Oracle? A. CREATE PFILE FROM SPFILE; B. CREATE PFILE FROM MEMORY; C. CREATE SPFILE FROM PFILE; D. ALTER SYSTEM DUMP PARAMETERS;

- RESPUESTA:
- Parte:

### S4. Una PDB está abierta en READ ONLY. ¿Qué dos sentencias la dejan en READ WRITE? (Elige dos.) A. ALTER PLUGGABLE DATABASE pdb OPEN READ WRITE; B. ALTER PLUGGABLE DATABASE pdb OPEN READ WRITE FORCE; C. ALTER PLUGGABLE DATABASE pdb CLOSE IMMEDIATE; seguida de ALTER PLUGGABLE DATABASE pdb OPEN; D. ALTER PLUGGABLE DATABASE pdb SAVE STATE; E. ALTER DATABASE pdb READ WRITE;

- RESPUESTA:
- Parte:

### S5. ¿Qué vista muestra el estado que se guardó para cada PDB? A. V$PDBS B. DBA_PDBS C. DBA_PDB_SAVED_STATES D. V$CONTAINERS

- RESPUESTA:
- Parte:

### S6. Un usuario sin el privilegio RESTRICTED SESSION intenta conectarse a una PDB abierta en modo restringido. ¿Qué obtiene? A. ORA-01109 B. ORA-01035 C. ORA-12514 D. ORA-28000

- RESPUESTA:
- Parte:

### S7. ¿Qué paquete crea y arranca un servicio en una base sin Grid Infrastructure? A. DBMS_SERVICE B. DBMS_SCHEDULER C. DBMS_MONITOR D. DBMS_SESSION

- RESPUESTA:
- Parte:

### S8. ¿Qué columnas unen V$SESSION con V$PROCESS? A. SID = PID B. PADDR = ADDR C. TADDR = ADDR D. SERIAL# = SPID

- RESPUESTA:
- Parte:

### S9. ¿Qué ocurre con la transacción pendiente de una sesión al ejecutar ALTER SYSTEM CANCEL SQL sobre ella? A. Se confirma. B. Se deshace. C. Sigue abierta: solo se cancela la llamada en curso. D. Se convierte en una transacción autónoma.

- RESPUESTA:
- Parte:

### S10. Te conectas como SYSOPER. ¿Qué devuelve SHOW USER? A. SYS B. SYSOPER C. PUBLIC D. SYSTEM

- RESPUESTA:
- Parte:

### S11. Conectado a una PDB, ¿qué vista te da las métricas del último minuto de esa PDB? A. V$SYSMETRIC B. V$CON_SYSMETRIC C. V$METRICNAME D. DBA_HIST_SYSMETRIC_SUMMARY

- RESPUESTA:
- Parte:

### S12. ¿Qué dos componentes suma DB time? (Elige dos.) A. Tiempo de CPU en llamadas a la base B. Tiempo de los procesos de fondo C. Tiempo de espera no Idle de las sesiones de primer plano D. Tiempo de las sesiones inactivas (Idle) E. Tiempo de parse de los procesos de fondo

- RESPUESTA:
- Parte:

### S13. El usuario SYS inserta en la tabla HR.T y recibe ORA-01950 sobre el tablespace USERS. ¿Quién necesita cuota? A. SYS B. HR C. SYSTEM D. Nadie: SYS tiene UNLIMITED TABLESPACE

- RESPUESTA:
- Parte:

### S14. ¿Sobre qué dos tipos de tablespace no se puede conceder cuota (ORA-30041)? (Elige dos.) A. Undo B. SYSAUX C. Temporal D. Bigfile E. De solo lectura

- RESPUESTA:
- Parte:

### S15. Una sesión con RESUMABLE habilitado se queda sin cuota. ¿Qué dos afirmaciones son ciertas? (Elige dos.) A. La sentencia se suspende hasta el timeout. B. La sentencia se deshace inmediatamente. C. La suspensión se ve en DBA_RESUMABLE. D. Oracle amplía la cuota automáticamente. E. La sesión se desconecta.

- RESPUESTA:
- Parte:

### S16. ¿Qué requisito previo tiene ALTER TABLE t SHRINK SPACE? A. Que la tabla esté en un tablespace bigfile. B. ENABLE ROW MOVEMENT y ASSM. C. Que la tabla no tenga índices. D. Que la base esté en NOARCHIVELOG.

- RESPUESTA:
- Parte:

### S17. Un perfil tiene FAILED_LOGIN_ATTEMPTS 3 y PASSWORD_LOCK_TIME 1. Tras tres fallos, ¿qué estado muestra DBA_USERS? A. LOCKED B. LOCKED(TIMED) C. EXPIRED D. EXPIRED(GRACE)

- RESPUESTA:
- Parte:

### S18. A concedió a B un privilegio de sistema que había recibido WITH ADMIN OPTION. El DBA lo revoca a A. ¿Qué pasa con B? A. Lo pierde en cascada. B. Lo conserva. C. Lo pierde solo si A era su creador. D. Queda pendiente de confirmación.

- RESPUESTA:
- Parte:

### S19. ¿Qué dos acciones dejan un índice en estado UNUSABLE? (Elige dos.) A. ALTER TABLE ... MOVE sin UPDATE INDEXES B. ALTER INDEX ... UNUSABLE C. ALTER TABLE ... ADD columna D. GATHER_TABLE_STATS E. ALTER INDEX ... REBUILD ONLINE

- RESPUESTA:
- Parte:

### S20. ¿Qué procedimiento activa la traza de la sesión de otro usuario indicando su SID y SERIAL#? A. DBMS_SESSION.SET_SQL_TRACE B. DBMS_MONITOR.SESSION_TRACE_ENABLE C. DBMS_SYSTEM.KSDWRT D. ALTER SESSION SET SQL_TRACE

- RESPUESTA:
- Parte:

### S21. ¿Qué parámetro fija la raíz del ADR? A. BACKGROUND_DUMP_DEST B. USER_DUMP_DEST C. DIAGNOSTIC_DEST D. AUDIT_FILE_DEST

- RESPUESTA:
- Parte:

### S22. En la guardia, una sesión espera en «enq: TX - row lock contention». ¿Cuál es el primer paso correcto? A. Reiniciar la instancia. B. Terminar la sesión que espera. C. Identificar al bloqueador (BLOCKING_SESSION) y qué está haciendo. D. Aumentar UNDO_RETENTION.

- RESPUESTA:
- Parte:
