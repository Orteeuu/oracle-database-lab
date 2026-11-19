# Lab 4 — Respuestas

Rutas de evidencia relativas a `docs/bitacora/lab4/evidencia/`.

## Sección 8 — Preguntas de comprobación

### Respaldo

**1. ¿Por qué la copia de la Parte B es consistente? ¿Qué pasaría con la base abierta?**
Antes de copiar, `backup-estado.sh` hace `SHUTDOWN IMMEDIATE` y `docker stop`, así que Oracle cierra con un checkpoint: todos los datafiles quedan en el mismo SCN y no hay transacciones a medias, por lo que la copia se abre sin recuperar con redo. Con la base abierta, el `tar` leería los datafiles en momentos distintos mientras DBWn sigue escribiendo, y el resultado sería una copia inconsistente que solo se podría abrir aplicando redo (ARCHIVELOG), y no hay garantía de que funcione.
Evidencia: `script/20261029T224219Z_00-backup-lab3.script.log`, apartado "4. Parada limpia" (`Database closed. Database dismounted. ORACLE instance shut down.`) y la línea `META|base|FREE|log_mode=ARCHIVELOG|scn=6281089`.

**2. ¿Para qué sirven manifiesto.txt y SHA256SUMS? ¿Qué comprueba restaurar-estado.sh antes de tocar nada?**
`manifiesto.txt` dice qué es la copia: etiqueta, fecha UTC, imagen, commit de git y tipo (copia en frío consistente). `SHA256SUMS` lleva la suma de cada archivo de la copia para detectar corrupción o manipulación. `restaurar-estado.sh` ejecuta primero `sha256sum --check --quiet SHA256SUMS`, y solo si pasa enseña el manifiesto y pide escribir el nombre del volumen para confirmar, porque después borra el volumen actual.
Evidencia: `scripts/ops/backup-estado.sh` (apartado 7) y `scripts/ops/restaurar-estado.sh` (apartado 1 "Integridad de la copia (SHA-256)"). La copia es `backups/20261029T224222Z_lab3-final` (609 MB) y no se sube a git.

**3. Define RPO y RTO con los datos de mi propia copia.**
RPO: lo que puedo perder es todo lo hecho en la base desde que se tomó la copia, el 2026-10-29 a las 22:42:22 UTC (la marca de la carpeta). RTO: lo que tarda `restaurar-estado.sh` en dejar el servicio otra vez. En el Lab 4 no restauré, pero la copia pesa 609 MB comprimida (el volumen son 5172 MB) y la base tarda 20 s en quedar healthy. El tiempo total medido lo tengo en el Lab 5 (simulacro 14c): RTO = 256 s con un RPO de 11 s.
Evidencia: `script/20261029T224219Z_00-backup-lab3.script.log` ("Volumen: 5172 MB", "609M", "t=20s docker=healthy") y, de Lab 5, `script/20261030T004245Z_14c-simulacro-restauracion.script.log` (`RTO ... 256 s`).

### Diagnóstico y correcciones

**4. ¿Dónde creó Oracle los datafiles de V000 y por qué? ¿Qué parámetro habría evitado el problema?**
V000 creó los datafiles de los cinco tablespaces de negocio con ruta relativa (`academia01.dbf`...). Como la base no tenía OMF (`db_create_file_dest` vacío), Oracle los puso en `$ORACLE_HOME/dbs`, que es `/opt/oracle/product/26ai/dbhomeFree/dbs/`, y no en `/opt/oracle/oradata/FREE/FREEPDB1/`. En mi contenedor esa carpeta es un enlace simbólico a `/opt/oracle/oradata/dbconfig/FREE/dbs`, dentro del volumen pero en una carpeta no estándar. Habría evitado el problema `db_create_file_dest='/opt/oracle/oradata'`, que es lo que hice en el reto C.
Evidencia: `script/20261029T224545Z_01-diagnostico.script.log`: FILE# 16 a 20 en `.../dbhomeFree/dbs/`, `db_create_file_dest (vacío: sin OMF)` y los `DENTRO del volumen, pero en carpeta no estándar`. Y `config/initFREE_lab4.ora`: `*.db_create_file_dest='/opt/oracle/oradata'`.

**5. ¿Por qué ALTER TABLESPACE ... RENAME DATAFILE no basta para mover un archivo?**
`RENAME DATAFILE` solo cambia la ruta que está apuntada en el control file; no copia ni mueve nada en disco. Si el archivo no está ya en la ruta nueva, Oracle no lo encuentra al ponerlo ONLINE. Por eso la secuencia es: tablespace OFFLINE (checkpoint, archivo consistente), copia física con el sistema operativo conservando permisos, `RENAME DATAFILE`, tablespace ONLINE, y solo cuando el ONLINE va bien se borra el original.
Evidencia: `script/20261029T224659Z_03-reubicar-datafiles.script.log`, pasos a) a d) de cada uno de los 5 tablespaces (por ejemplo TBS_ACADEMIA: `.../dbs/academia01.dbf -> /opt/oracle/oradata/FREE/FREEPDB1/academia01.dbf`).

**6. ¿Por qué no se edita V000 y se crea V003? ¿Por qué invalidar una contraseña es mejor que borrarla del archivo?**
Una migración ya aplicada es historia: si la edito, el repositorio deja de reflejar lo que se ejecutó, y cualquier otra copia del repo ya aplicó la V000 original. Lo correcto es una migración nueva (V003) que corrige el estado. Borrar las contraseñas del archivo no sirve porque siguen en el historial de Git para siempre; lo que sí funciona es dejar de aceptarlas. V003 pone `NO AUTHENTICATION` a los cinco ADMIN_*, así que la contraseña de V000 ya no abre nada.
Evidencia: `script/20261029T225217Z_04-migraciones.script.log` (`AUTHENTICATION_TYPE NONE` en los cinco usuarios con `ACCOUNT_STATUS OPEN`) y `script/20261029T225231Z_04-password-antigua.script.log` (`ORA-01017: invalid credential or not authorized`).

**7. ¿Qué demuestra la prueba de persistencia y por qué se ejecuta después de reubicar?**
Demuestra que los datos viven en el volumen y no en la capa del contenedor. Paro con `SHUTDOWN IMMEDIATE`, borro el contenedor y lo recreo con el mismo volumen `oralab-26ai-data`: los cinco tablespaces siguen ONLINE en `/opt/oracle/oradata/FREE/FREEPDB1/` y las tablas son las mismas (3, 3, 2, 3, 3). Se ejecuta después de reubicar porque antes de moverlos los datafiles estaban en una ruta que depende de `$ORACLE_HOME` y esta prueba es la que confirma que la reubicación sirve.
Evidencia: `script/20261029T224732Z_03-prueba-persistencia.script.log`: tablas por esquema idénticas en ANTES y DESPUÉS, `El volumen oralab-26ai-data ya contiene la base FREE: se reutiliza`, `t=20s docker=healthy cdb/pdb=READWRITE/READWRITE`.

### Instancia y arranque

**8. Tres datos de la instancia y tres de la base de datos.**
Instancia (existe mientras está arrancada): `INSTANCE_NAME` FREE; `ARRANCADA` 2026-10-29 22:51:42; el host `fcb0efb17922` (el id del contenedor). Con ella van la SGA y los 62 procesos de background. Base de datos (archivos en disco, existe aunque la instancia esté parada): `DBID` 1509902213; `CREADA` 2026-07-05; `LOG_MODE` ARCHIVELOG. También son de la base los 16 datafiles (4044 MB) y los 2 control files.
Evidencia: `spool/20261029T225303Z_05-instancia-y-base.spool.log` (apartados 1, 2 y 5) y `script/20261029T225312Z_05-instancia-so.script.log` (62 procesos).

**9. ¿Qué lee Oracle en NOMOUNT, MOUNT y OPEN? Relación con ORA-01507 y ORA-01219.**
NOMOUNT: lee el SPFILE, reserva la SGA y arranca los procesos; `v$parameter` ya responde, pero `v$database` da ORA-01507 (database not mounted) porque todavía no se ha leído el control file. MOUNT: abre los control files y conoce la estructura (16 datafiles, redo); `v$database` ya responde, pero `dba_tables` da ORA-01219 porque el diccionario está en los datafiles de SYSTEM, que siguen cerrados. OPEN: abre datafiles y redo logs (y hace recuperación de instancia si hace falta) y ya se puede consultar todo.
Evidencia: `script/20261029T225754Z_06-arranque-por-etapas.script.log` (ORA-01507 tras NOMOUNT, `DATAFILES_CONOCIDOS 16` y ORA-01219 tras MOUNT, `OPEN_MODE READ WRITE` tras OPEN).

**10. ¿Por qué FREEPDB1 se abre sola tras ALTER DATABASE OPEN? ¿Qué haría si no lo hiciera?**
Porque tiene el estado guardado (SAVE STATE): Oracle recuerda que estaba en READ WRITE y la reabre al abrir la CDB. El script lo comprueba y escribe `FREEPDB1 abierta sola en READ WRITE: el estado guardado funciona`. Si se quedara en MOUNTED, ejecutaría `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;` y después `ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE;` para que el próximo arranque la abra sola.
Evidencia: `script/20261029T225754Z_06-arranque-por-etapas.script.log` (apartado 4) y `script/20261029T225831Z_06-alert-log.script.log` (`Completed: Pluggable database FREEPDB1 opened read write`).

**11. ORA-00800 y ORA-20013 del alert log: ¿alerta real o ruido conocido?**
Son ruido conocido, y por eso se clasifican y se excluyen de las alertas, no se ignoran. ORA-00800 `[Set Priority Failed]` para VKTM y LGWR: Oracle intenta subir la prioridad de esos procesos y el contenedor no se lo permite (falta CAP_SYS_NICE); es un aviso "soft" y la base funciona. Sale en cada arranque, y ninguno de los dos arranques que tengo termina en error. ORA-20013 (DBMS_QOPATCH) es que el inventario de parches no se puede leer en una imagen de contenedor, y tampoco afecta al funcionamiento. Cualquier otro ORA- se investiga.
Evidencia: `script/20261029T225831Z_06-alert-log.script.log`: aparece ORA-00800 de VKTM y LGWR en los dos `Starting ORACLE instance`, seguido de `Successful mount`, `Successful open` y `Completed: ALTER DATABASE OPEN`. (ORA-20013 no aparece en mi captura, solo ORA-00800.)

### Parámetros

**12. Diferencia entre v$parameter y v$spparameter con db_files.**
`v$parameter` es el valor efectivo en la instancia en marcha; `v$spparameter` es lo que está escrito en el SPFILE y se aplicará al próximo arranque. Con `db_files`: tras `ALTER SYSTEM SET db_files = 300 SCOPE = SPFILE` mi evidencia muestra `EN_MEMORIA 200` y `EN_SPFILE 300`. Cuando hice `RESET`, el SPFILE pasó a `(no especificado)` y la memoria siguió en 200.
Evidencia: `script/20261029T225906Z_07-parametros-cambios.script.log`, apartado 3.

**13. ¿Qué hace SCOPE=BOTH y cuál es el SCOPE por defecto con SPFILE?**
`SCOPE=BOTH` cambia el valor en memoria (efecto inmediato) y lo escribe en el SPFILE (sobrevive al reinicio). Si la instancia arrancó con SPFILE y no pongo SCOPE, el valor por defecto es BOTH. En mi prueba, `open_cursors` pasó a `EN_MEMORIA 500 / EN_SPFILE 500` con el comentario `Lab4: prueba SCOPE=BOTH`; con `SCOPE=MEMORY` había quedado 400 en memoria y 300 en el SPFILE.
Evidencia: `script/20261029T225906Z_07-parametros-cambios.script.log`, apartados 1 y 2.

**14. ¿Por qué PROCESSES rechaza el cambio en memoria aunque v$parameter lo marque IMMEDIATE?**
`PROCESSES` dimensiona estructuras que se reservan al arrancar la instancia (SGA, semáforos, y de él derivan `sessions`...), así que no se puede cambiar en caliente aunque la columna `ISSYS_MODIFIABLE` diga IMMEDIATE en esta versión (26ai Free). El resultado es el error que obtuve; el cambio solo vale en el SPFILE más un reinicio.
Evidencia: `spool/20261029T225904Z_07-parametros-lectura.spool.log` (`processes 200 ... IMMEDIATE`) frente a `script/20261029T225906Z_07-parametros-cambios.script.log`, apartado 4: `ALTER SYSTEM SET processes = 250 SCOPE = MEMORY` -> `ORA-02097` y `ORA-02095`.

**15. ¿Para qué sirve versionar el PFILE? Configuration drift.**
El SPFILE es binario y no se puede revisar; el PFILE es una copia legible en texto que puedo meter en git. Así cada cambio de configuración queda en un diff con autor y fecha, y puedo volver a un estado conocido con `CREATE SPFILE FROM PFILE`. "Configuration drift" es que la configuración real de la base se va separando de la que creemos tener documentada porque alguien hizo un `ALTER SYSTEM` sin dejar rastro; comparar el PFILE versionado con el actual lo detecta.
Evidencia: `config/initFREE_lab4.ora` y `config/initFREE_lab4_memoria.ora`; el primero ya recoge mi cambio `*.db_create_file_dest='/opt/oracle/oradata'#Lab4 reto C: OMF dentro del volumen`, que en el diagnóstico inicial estaba vacío.

### Memoria y procesos

**16. ¿Qué modelo de gestión de memoria usa mi instancia? Tres parámetros.**
ASMM: SGA con gestión automática y PGA aparte. Lo justifican `memory_target = 0` y `memory_size = 0` (no hay gestión conjunta de SGA y PGA, que sería AMM), `sga_target = 1536M` (con `sga_max_size = 1536M`) y `pga_aggregate_target = 512M` (PGA automática). Además `db_cache_size` y `shared_pool_size` están a 0, es decir, Oracle reparte el tamaño entre componentes: buffer cache 992 MB y shared pool 496 MB.
Evidencia: `spool/20261029T225940Z_08-memoria.spool.log`, apartados 1, 3 y 4.

**17. Explica las cifras de mi experimento de caché.**
Vacié la caché y ejecuté la misma consulta dos veces. Ronda 1 (caché fría): 357 lecturas lógicas y 261 físicas, es decir, una tasa de acierto de 1 - 261/357 = 26,9 %: casi todo viene de disco. Ronda 2 (caché caliente): 247 lecturas lógicas y 0 físicas, tasa de acierto del 100 %: todo sale de memoria. Las lógicas bajan de 357 a 247 porque en la ronda 1 había además trabajo de preparación (análisis y diccionario) que en la 2 ya no se repite. La tabla `ACA_ESTUDIANTES` ocupa 244 bloques y tras la consulta hay 245 de ellos en el buffer cache.
Evidencia: `script/20261029T225943Z_08-experimento-cache.script.log`, apartados 1 a 4.

**18. ¿Por qué no se suma el RSS de los procesos para saber la memoria de la instancia?**
Porque la SGA es memoria compartida: cada proceso de Oracle la tiene mapeada y el RSS de cada uno la cuenta entera (o la parte que ha tocado). Sumar los RSS cuenta la misma memoria varias veces. Con nueve procesos clave, la suma de mis RSS ya da unos 1037 MB (82 + 94 + 99 + 98 + 82 + 105 + 118 + 276 + 83), cuando la memoria total del contenedor es 2,053 GiB. La cifra real sale de `v$sga` y `v$pgastat`.
Evidencia: `script/20261029T230031Z_09-procesos-so.script.log` (columna RSS) y `script/20261029T225312Z_05-instancia-so.script.log` (`2.053GiB / 5.788GiB`).

**19. Relaciona el SPID de LGWR con el PID de /proc. ¿Por qué docker top muestra otro número?**
El SPID 716 de LGWR en `v$process` es el PID del proceso Linux dentro del contenedor, y coincide con el de `/proc` (`716 ... db_lgwr_FREE`). `docker top` se ejecuta desde el host, que ve los mismos procesos con otro PID por los espacios de nombres de PID: por ejemplo PMON es 668 dentro y 26235 con `docker top`.
Evidencia: `spool/20261029T230028Z_09-procesos.spool.log` (LGWR `716`), `script/20261029T230031Z_09-procesos-so.script.log` (apartado 4: `716 ... db_lgwr_FREE`) y `script/20261029T225312Z_05-instancia-so.script.log` (`26235 ... db_pmon_FREE`).

**20. ¿Qué hace PMON y qué hace SMON? Un ejemplo de cada uno.**
PMON limpia después de procesos que mueren: si una sesión cae sin cerrarse, PMON hace rollback de su transacción, libera sus bloqueos y recursos. SMON hace la recuperación de la instancia al arrancar (aplica redo y deshace lo no confirmado) y limpia segmentos temporales. Ejemplo de SMON en mi evidencia: al abrir la base, el alert log registra `Crash Recovery excluding pdb 2 which was cleanly closed` y `Successful open of redo thread 1`. Mis PMON y SMON eran los procesos 668 y 720.
Evidencia: `script/20261029T225831Z_06-alert-log.script.log` y `script/20261029T230031Z_09-procesos-so.script.log`.

### Seguridad y trabajo profesional

**21. ¿Por qué C##OPS_RO y no SYSTEM para observar? ¿Qué no puede hacer C##OPS_RO?**
Por mínimo privilegio: SYSTEM puede hacer casi todo (cambiar datos, crear o borrar objetos), y una cuenta con tanto poder no debería usarse para solo mirar ni tener su contraseña repartida. `C##OPS_RO` es una cuenta común (existe en CDB$ROOT y en FREEPDB1) con el atributo CONTAINER_DATA, así que ve `v$` de todos los contenedores, y solo tiene permisos de lectura, entre ellos SELECT sobre `V_$DIAG_ALERT_EXT` para leer el alert log. No puede escribir ni modificar datos, ni hacer DDL, ni parar la base, ni usar privilegios ANY de escritura (0 en la verificación final).
Evidencia: `script/20261029T224622Z_02-cuenta-observabilidad.script.log` (`COM YES` en los dos contenedores), `script/20261029T230150Z_10-que-ve-cada-usuario.script.log`, apartado 6 (`DEFAULT_ATTR Y, ALL_CONTAINERS Y`), `script/20261029T230326Z_11-ampliar-ops-ro.script.log` y `script/20261029T230709Z_16-verificacion-final.script.log` (`C##OPS_RO sin privilegios ANY de escritura (0)`).

**22. ¿Qué dos vías de exposición de contraseñas corrige este laboratorio respecto al Lab 3?**
(1) Las contraseñas de los cinco propietarios en V000, que quedan en el historial de Git para siempre: V003 las invalida con `NO AUTHENTICATION`. (2) La contraseña de SYS en la línea de comandos de `08-aplicar-migraciones.sh` (`sys/<contraseña>`), visible con `ps` y guardada en el historial de la shell: ahora entra por la entrada estándar. De propina, `05-crear-contenedor.sh` v2 ya no pasa contraseñas si el volumen ya tiene una base (menos secretos en `docker inspect`) y deja de publicar el puerto 8181.
Evidencia: `script/20261029T225217Z_04-migraciones.script.log`, `script/20261029T225231Z_04-password-antigua.script.log` (ORA-01017) y `script/20261029T224732Z_03-prueba-persistencia.script.log` (`se reutiliza (sin contraseñas)` y solo 1521 publicado).

## Preguntas tipo examen

| Pregunta | Letra | Justificación |
|---|---|---|
| P1 | A, D | Tras SHUTDOWN IMMEDIATE la base se cierra limpia (rollback y checkpoint), así que la copia es consistente y se abre con STARTUP sin recuperar con redo. |
| P2 | B | En Standard Edition no hay MOVE DATAFILE online: se pone el tablespace OFFLINE, se copia el archivo con el SO, se hace RENAME DATAFILE y se pasa a ONLINE. |
| P3 | A, C | STARTUP_TIME cambia en cada arranque de la instancia; CREATED es la fecha de creación de la base, no del arranque. |
| P4 | A, C | En NOMOUNT solo existe la instancia: `v$parameter` se lee de memoria y se puede recrear el control file. |
| P5 | B | ALTER DATABASE ARCHIVELOG exige la base montada (MOUNT) y no abierta. |
| P6 | B | Con SPFILE el SCOPE por defecto es BOTH: se aplica en memoria y en el SPFILE. |
| P7 | C | PROCESSES es un parámetro de toda la instancia y no se puede modificar desde un PDB (ORA-65040, que obtuve en la evidencia 07). |
| P8 | A, C | Arrancar con un PFILE bueno y regenerar el SPFILE con CREATE SPFILE FROM PFILE. |
| P9 | B | Con SGA_TARGET fijado (ASMM), DB_CACHE_SIZE actúa como mínimo del buffer cache. |
| P10 | A, D | El sort area y la memoria de sesión son PGA; shared pool, log buffer y buffer cache son SGA. |
| P11 | C | LGWR debe escribir el redo del COMMIT antes de devolver el control. |
| P12 | B, D | PMON y SMON son procesos obligatorios (junto a DBWn, LGWR y CKPT, que aquí no aparecen como opción). |
