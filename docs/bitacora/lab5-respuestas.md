# Lab 5 — Respuestas

Rutas de evidencia relativas a `docs/bitacora/lab5/evidencia/` (salvo que se indique otra).

## Sección 8 — Preguntas de comprobación

### Punto de partida y banco de medida (A, B)

**1. Compara el paso 6 de la copia lab4-final con el de lab3-final. ¿Qué demuestra la diferencia?**
En las dos copias el paso 6 dice `ninguno: el volumen contiene toda la base de datos`, así que no hay archivos fuera del volumen en ninguna. Lo que cambia es el inventario del paso 2: en lab3-final los cinco datafiles de negocio figuran en `/opt/oracle/product/26ai/dbhomeFree/dbs/academia01.dbf...` (una carpeta no estándar) y en lab4-final están en `/opt/oracle/oradata/FREE/FREEPDB1/academia01.dbf...`. Demuestra que la reubicación del Lab 4 funcionó y que la copia ya contiene todo en su sitio. Además la copia creció de 609 MB a 661 MB y el volumen de 5172 MB a 5371 MB por los datos y migraciones nuevos.
Evidencia: `docs/bitacora/lab4/evidencia/script/20261029T224219Z_00-backup-lab3.script.log` (`FILE|datafile|.../dbs/academia01.dbf`, `609M`) frente a `script/20261029T230946Z_00-backup-lab4.script.log` (`FILE|datafile|/opt/oracle/oradata/FREE/FREEPDB1/academia01.dbf`, `661M`, `Volumen: 5371 MB`).

**2. Calcula el factor de bloqueo (bfr) de CLIENTE y de PEDIDO. ¿Por qué PEDIDO cabe casi el triple de filas por bloque?**
bfr = filas / bloques: CLIENTE = 100 000 / 1517 = 66 filas por bloque y PEDIDO = 1 000 000 / 5320 = 188. Contando de verdad en PEDIDO salen una media de 191,6 filas por bloque. Cabe casi el triple (188 / 66 = 2,85) porque la fila de PEDIDO mide 32 bytes de media y la de CLIENTE 102 bytes (hay textos largos como email, nombre y apellidos). Con bloques de 8 KB, a menos bytes por fila, más filas por bloque.
Evidencia: `script/20261029T235231Z_01-perfil-tiendasur.script.log` (CLIENTE `100000 1517 102 66`; PEDIDO `1000000 5320 32 188`) y `script/20261029T235253Z_01-reto-bfr-pedido.script.log` (`MEDIA 191.6`).

**3. ¿Por qué el banco de medida ejecuta cada sentencia dos veces y mide solo la segunda?**
La primera ejecución incluye trabajo que se hace una sola vez: el análisis duro de la sentencia, la carga de bloques en caché y la limpieza de bloques. Eso distorsiona la medida. En la segunda ya está todo en caliente y mido el coste real de la sentencia. En mi evidencia lo dice el propio banco: "primera ejecución descartada: puede incluir trabajo único, como limpiar el bloque".
Evidencia: `script/20261029T235323Z_02-anatomia-indice.script.log`, apartado 3 (búsqueda por `id_pedido = 4711`, 4 lecturas lógicas y 0 físicas en la medida).

### Anatomía y tipos de índice (C, D)

**4. Evidencia 02: altura, hojas y fan-out real de IX_PED_CLIENTE. ¿Qué altura con mil millones de filas?**
IX_PED_CLIENTE tiene altura 3, 2216 hojas y 6 ramas. El fan-out real es (hojas + ramas - 1) / ramas = (2216 + 6 - 1) / 6 = 370 (el máximo teórico es 543). Con mil millones de filas saldrían 2 208 969 hojas, altura 4, es decir, 5 lecturas para encontrar una fila (altura + tabla). La altura crece con el logaritmo: de un millón a cien mil millones solo se añaden uno o dos niveles.
Evidencia: `script/20261029T235323Z_02-anatomia-indice.script.log`, apartados 1 y 2 (`IX_PED_CLIENTE 3 2216`, `fo = 370`, `1,000,000,000 filas -> 2208969 hojas -> altura 4`).

**5. En el volcado de la hoja de PK_CLIENTE, descompón el ROWID de una entrada. ¿Por qué no aparece el número de archivo?**
La primera entrada de la hoja es `row#0 ... data:(6): 00 00 03 1b 00 00` con clave `col 0: c1 02` (ID_CLIENTE = 1). Los 6 bytes son 4 de bloque más 2 de ranura: `00 00 03 1b` = 0x31B = bloque 795 y `00 00` = fila (ranura) 0. La siguiente, `00 00 03 1b 00 01` con clave `c1 03` (ID 2), es la ranura 1 del mismo bloque. No aparece el archivo porque TBS_TIENDASUR es un tablespace bigfile (`BIG = YES`) con un único datafile, y dentro del índice basta bloque + ranura.
Evidencia: `config/20261029T235323Z_02-volcado-indice.trc.txt` (línea del `Leaf block dump`, `row#0[1200] ... data:(6): 00 00 03 1b 00 00`) y `script/20261029T235253Z_01-reto-bfr-pedido.script.log` (`TBS_TIENDASUR YES 8192`).

**6. Tres pruebas de la Parte D y por qué un tipo de índice gana al otro.**
(a) UNIQUE sobre DNI (Q13): sin índice 1486 lecturas lógicas con `TABLE ACCESS FULL`; con `UX_CLI_DNI` solo 3, y además la base rechaza el duplicado con ORA-00001. (b) Compuesto y cubriente (Q7): `ix_ped_cliente` 15 lecturas; `(id_cliente, fecha)` 7, y sin SORT; el cubriente 3, porque ni toca la tabla. (c) Bitmap (Q14, almacén): sin bitmaps 4073 lecturas y con 4 bitmaps 528, y ocupan mucho menos que el B-tree equivalente, pero bloquean rangos de filas al escribir, así que valen para un almacén que se carga de noche y no para OLTP.
Evidencia: `script/20261029T235355Z_03-tipos-indice.script.log`, apartados 1, 3 y 6.

### Agrupamiento, equilibrio y sargabilidad (E, F)

**7. ¿Por qué IX_PED_FECHA tiene un CF cercano al número de bloques e IX_PED_CLIENTE cercano al de filas? ¿Lo arreglaría un REBUILD?**
Las filas de PEDIDO se insertaron en orden de fecha, así que recorrer el índice por fecha va leyendo bloques contiguos de la tabla: CF = 5220 con 5320 bloques. Los clientes de los pedidos están desperdigados al azar, y recorrer el índice por cliente salta de bloque en cada entrada: CF = 999 041 con 1 000 000 de filas. Un REBUILD no lo arregla, porque el CF depende de cómo están ordenadas las filas de la tabla y no del índice; para mejorarlo habría que reordenar la tabla.
Evidencia: `script/20261029T235542Z_04-agrupamiento-equilibrio.script.log`, apartados 1 y 2 (`IX_PED_FECHA 5220 BUENO`, `IX_PED_CLIENTE 999041 MALO`).

**8. Según mi curva, ¿a partir de qué porcentaje deja de compensar cada índice? Compárala con la fórmula de la Unidad 3.**
El índice de CF malo gana hasta el 0,5 % (4875 lecturas frente a 5232 de la tabla entera) y ya pierde en el 1 % (9920). El de CF bueno sigue ganando hasta el 50 % (3938) y solo pierde en el 100 % (7875). La fórmula k/r < (1/bfr) × (c_sec/c_aleat) da 1/188 = 0,53 % en lecturas lógicas y 0,11 % en disco con c_sec/c_aleat = 1/5, lo que cuadra con mi cruce medido entre el 0,5 % y el 1 %.
Evidencia: `script/20261029T235542Z_04-agrupamiento-equilibrio.script.log`, apartado 3 y `script/20261029T235649Z_04-reto-curva.script.log`.

**9. ¿Por qué Q4b ('Gonz%') usa el índice y aun así lee más bloques que un recorrido completo?**
`LIKE 'Gonz%'` es sargable: es un rango por el principio de la cadena y el B-tree lo puede usar (`INDEX RANGE SCAN IX_CLI_APELLIDOS`). Pero devuelve 2056 filas, el 2,1 % de la tabla, muy por encima del punto de equilibrio de 0,53 %, y esas filas están repartidas por muchos bloques, así que cada una cuesta casi una lectura. Resultado: 2024 lecturas lógicas por el índice frente a 1523 de leer la tabla entera (Q4a).
Evidencia: `script/20261029T235611Z_05-sargabilidad.script.log`, regla 4 (`Q4a ... 1523`, `Q4b ... 2024`) y el 2,1 % de `script/20261029T235231Z_01-perfil-tiendasur.script.log` (`apellidos LIKE Gonz% 2.1`).

### Coste de escritura y mantenimiento (G, H)

**10. Bloques modificados por INSERT con 4, 9 y 5 índices. ¿Qué índices del compañero rechacé y con qué dato?**
Con 4 índices, 2000 INSERT modifican 20 291 bloques (10,1 por fila); con 9 índices, 40 320 (20,2 por fila); con los 5 de V005, 24 214 (12,1 por fila). Cada índice añade unos 2 bloques por inserción. Rechacé IX_PED_CANAL (3 valores, 33,3 % por valor) e IX_PED_ESTADO (4 valores, 25 %), que no son viables para igualdad y que sustituí por el parcial IX_PED_PENDIENTES (2 % de las filas); IX_PED_FEC_CLI, que no se usa (`USA = NO`); e IX_PED_CLIENTE e IX_PED_IMPORTE, que no se usaban o estaban cubiertos por IX_PED_CLI_FEC. IX_PED_IMPORTE lo pasé por INVISIBLE antes de borrarlo, y V005 lo elimina.
Evidencia: `script/20261030T000346Z_06-indices.script.log` (escenarios hoy, compañero y V005; preguntas 1, 2, 4 y 5) y `spool/20261029T235200Z_01-V004__banco_tiendasur.spool.log` junto con `spool/20261030T000415Z_06-V005__indices_tiendasur.spool.log` (los 5 índices finales de PEDIDO).

**11. Con mis gráficos de la Parte H: divisiones 50/50, 90/10 y patrón cola.**
IX_AZAR (claves al azar): 595 divisiones 50/50 y 0 de tipo 90/10, hojas al 75,4 % (336 entradas por hoja) y 14 hojas por debajo del 50 %. IX_CRECIENTE (secuencia): 398 divisiones y todas 90/10, hojas llenas al 99,9 % (501 por hoja). IX_COLA (se inserta por un extremo y se borra por el otro): 425 hojas, 70 745 entradas borradas, solo un 47,1 % de ocupación viva, 224 hojas vacías y la búsqueda del siguiente mensaje cuesta 226 lecturas frente a 2 de un índice sano.
Evidencia: `script/20261030T000449Z_07a-crecimiento.script.log`, `..._07a-grafico-IX_AZAR/IX_CRECIENTE.script.log`, `..._07b-patron-cola.script.log` y `..._07b-grafico-IX_COLA-antes.script.log`.

**12. ¿Qué remedio elegiría para el patrón cola en producción, en horario de servicio, y por qué?**
`ALTER INDEX ... COALESCE`: se hace en línea, sin bloquear, y en mi medida bajó de 425 a 201 hojas, de 70 745 borradas a 0 y de 226 a 2 lecturas para el siguiente mensaje. Si además necesitara devolver espacio al tablespace usaría SHRINK SPACE, que también es en línea (el segmento pasó de 4 a 1,69 MB). El REBUILD ONLINE necesita espacio doble y genera mucho redo, así que solo con una causa concreta y medida. La cura de verdad es de diseño: particionar por fecha.
Evidencia: `script/20261030T000449Z_07c-remedios.script.log` (tabla de pasos 0 a 3) y `..._07c-grafico-IX_COLA-despues.script.log` (223 hojas, 89,7 %).

### SCN, control files, redo y FRA (I a L)

**13. Evidencia 08: ¿qué valores compara Oracle al abrir para decidir si hace falta recuperación?**
Compara el SCN del último checkpoint guardado en el control file con el SCN de la cabecera de cada datafile. Si coinciden, el archivo está sincronizado y no necesita recuperación. En mi evidencia, `CKPT_CONTROL_FILE = 6347891` y `CKPT_CABECERA = 6347891` para system01, sysaux01 y academia01: `sincronizado`. Tras el checkpoint forzado los dos pasan a 6352935. PDB$SEED se queda en 2098101 porque está en solo lectura y su checkpoint no avanza.
Evidencia: `script/20261030T000549Z_08-scn-checkpoint.script.log`, apartados 2 y 3.

**14. ¿Qué protege la multiplexación del control file en el mismo volumen y qué no? ¿Cómo se haría en producción?**
Protege contra la pérdida o corrupción de un solo archivo: en el simulacro B borré `control03.ctl`, la base no montó (ORA-00205) y la reparé copiando `control01.ctl` y continuando desde NOMOUNT. No protege contra la pérdida del disco o del volumen entero, porque las tres copias (`control01/02/03.ctl`) viven en el mismo sitio. En producción cada copia iría en un disco o controladora distintos (y la FRA aparte), y se haría con `control_files` en el SPFILE y reinicio.
Evidencia: `script/20261030T001302Z_09-multiplexar-controlfile.script.log` (tres copias tras el arranque) y `script/20261030T004155Z_14b-perdida-controlfile.script.log` (`ORA-00205`, `ORA-00202 ... control03.ctl`, reparado).

**15. Estados CURRENT, ACTIVE e INACTIVE (evidencia 10) y por qué Oracle rechaza los tres borrados del paso 4.**
CURRENT: el grupo donde LGWR escribe ahora (grupo 3, secuencia 15). ACTIVE: ya no se escribe en él pero aún hace falta para la recuperación de instancia porque su checkpoint no ha terminado. INACTIVE: ya no hace falta (los grupos 1 y 2, secuencias 13 y 14). Oracle rechaza borrar el grupo CURRENT (ORA-01623), un miembro del CURRENT (ORA-01609) y otro grupo si eso dejara uno solo, porque el grupo 1 hace falta para la recuperación de instancia (ORA-01624): en los tres casos se rompería la recuperación.
Evidencia: `script/20261030T001905Z_10-redo.script.log` (apartados 1, 3 y 4).

**16. Cadena de causas de la FRA llena, desde ORA-19815 hasta que la base deja de aceptar cambios.**
Reduje la FRA y generé redo con un UPDATE de 20 000 filas. El alert log avisa primero con ORA-19815 al 89,55 % y luego al 100 %, con 0 bytes libres. Entonces ARCn no puede archivar el log: ORA-19809 (límite excedido) y ORA-16038 (la secuencia 19 no se puede archivar). Los grupos 1 y 2 quedan con `ARC = NO`; LGWR no puede reutilizar un grupo que no está archivado, las sesiones se quedan esperando en el cambio de log y la base deja de aceptar cambios. La solución inmediata es devolver espacio a la FRA y ARCn reintenta solo.
Evidencia: `script/20261030T002545Z_11-fra-llena.script.log`, apartados 3, 4 y 5.

### Undo, WAL y simulacros (M a P)

**17. Con los pasos 1 a 4 de la evidencia 12, explica "lectores no bloquean a escritores".**
La sesión A hace un UPDATE de la fila 101 a EGRESADO sin COMMIT. La sesión B la lee y ve ACTIVO (el valor confirmado, reconstruido con el undo): el paso 1 no espera. En el paso 2 se ve que la transacción de A ya usa 1 bloque y 1 registro de undo, y en el paso 3 sus bloqueos TM (modo 3) y TX (modo 6). Solo cuando B intenta bloquear la misma fila con `FOR UPDATE WAIT 3` (paso 4) recibe ORA-00054: un escritor sí bloquea a otro escritor, pero un lector nunca bloquea ni es bloqueado.
Evidencia: `script/20261030T002613Z_12-lectura-consistente.script.log`, pasos [B] 1 a 4.

**18. ¿Por qué un DELETE genera más undo que un INSERT? ¿Por qué el ROLLBACK también genera redo?**
Para deshacer un INSERT basta guardar "borra este ROWID"; para deshacer un DELETE hay que guardar la fila entera y sus entradas de índice. En mi medida, 10 000 filas: INSERT 142 bloques de undo (1136 KB), UPDATE 71 y DELETE 427 (3416 KB). El ROLLBACK genera redo porque deshacer es aplicar cambios a bloques, y todo cambio, incluido el del undo, se protege con redo: el rollback del INSERT generó 355 KB de redo y el del DELETE 4701 KB.
Evidencia: `script/20261030T002644Z_12-undo-y-redo.script.log`.

**19. Evidencia 13: ¿dónde está la garantía de durabilidad justo después del COMMIT? ¿Y después del checkpoint?**
Después del COMMIT la garantía está en el redo log online: LGWR escribió 1779 KB de redo (2 escrituras, 1 commit), mientras DBWn no había escrito ningún bloque (0) y quedaban 231 bloques sucios en caché. Después de `ALTER SYSTEM CHECKPOINT`, DBWn vuelca 353 bloques a los datafiles y los bloques sucios de la tabla bajan a 0: ahora la garantía también está en los datafiles.
Evidencia: `script/20261030T002806Z_13-lgwr-dbwn.script.log`, tabla de resultados (pasos 1 y 2).

**20. Simulacro A: roll forward y roll back con las filas 102 y 103 y las líneas del alert log.**
Antes del `SHUTDOWN ABORT` confirmé 102 -> EGRESADO y dejé 103 -> INACTIVO sin confirmar. Al arrancar, el roll forward rehace con el redo todo lo que no estaba en los datafiles, también lo no confirmado (`read 1773 KB redo, 286 data blocks need recovery`, `Completed redo application of 1.03MB`). Después el roll back deshace con el undo lo no confirmado. Resultado: 102 sigue EGRESADO (confirmado) y 103 vuelve a ACTIVO. El alert log lo cierra con `Completed crash recovery` y `Thread 1 opened at log sequence 26`.
Evidencia: `script/20261030T004057Z_14a-caida-instancia.script.log`, apartados 3 y 4.

**21. Simulacros C y D: mi RTO y mi RPO en cada uno. ¿Por qué son tan distintos?**
C (borrado de tabla con `DROP ... PURGE`, restaurando la copia completa): RTO = 256 s y RPO = 11 s, es decir, todo lo hecho entre la copia y el fallo. D (pérdida del datafile 16): RTO = 19 s (21 s desde el fallo) y RPO = 0. Son tan distintos porque C restaura el volumen entero (la copia pesa 1,4 GB) y vuelve al punto de la copia, mientras que D restaura solo un archivo (la copia RMAN del tablespace pesa 38 MB), y como la base está en ARCHIVELOG, RECOVER aplica el redo archivado posterior (`media recovery complete, elapsed time: 00:00:01`) y no se pierde nada: la fila 104 sigue EGRESADO. El RTO de C es unas 13 veces mayor (256 / 19) y crece con el tamaño de la base.
Evidencia: `script/20261030T004245Z_14c-simulacro-restauracion.script.log` (`RPO ... 11 s`, `RTO ... 256 s`, `1.4G`) y `script/20261030T010137Z_14d-perdida-datafile.script.log` (`RPO 0`, `RTO ... 19 s; desde el fallo: 21 s`).

**22. Clasifica cada error ORA- del bloque 5 de mi runbook.**
ORA-00800 `[Set Priority Failed]` (VKTM y LGWR, a las 00:56 y a las 01:00): ruido conocido, el contenedor no deja subir la prioridad y la base funciona. ORA-205 y ORA-00202 sobre `control03.ctl` (00:42): efecto del laboratorio, es el simulacro B donde borré ese control file. ORA-63999, ORA-01110 del datafile 16 y ORA-01113 (01:02): efecto del laboratorio, es el simulacro D donde borré `academia01.dbf` y Oracle cerró la PDB. Ningún incidente real: los que no son ruido los provoqué yo y están reparados.
Evidencia: `spool/20261030T010324Z_15-healthcheck.spool.log`, apartado 5.

## Simulacro de examen 1Z0-182

| Pregunta | Letra | Parte | Justificación |
|---|---|---|---|
| O1 | B | O | Tras un corte de luz, SMON rehace el redo y deshace lo no confirmado y la base abre sin intervención (simulacro A). |
| S1 | B | E | Un CF cercano al número de filas significa que casi cada entrada del índice salta a un bloque distinto (IX_PED_CLIENTE, CF = 999 041). |
| S2 | A, C | F | Un índice basado en función sobre UPPER(email), o reescribir comparando con el dato en minúsculas, devuelve el índice a la consulta. |
| S3 | B | F | Oracle aplica TO_NUMBER a la columna VARCHAR2 y el índice no se puede usar (regla 3, Q3). |
| S4 | B | D | El bitmap vale para pocos valores en un almacén que se carga de noche (Q14). |
| S5 | B | D | Sin el prefijo izquierdo, Oracle puede hacer INDEX SKIP SCAN (Q6). |
| S6 | B | G | INVISIBLE permite observar con marcha atrás inmediata (IX_PED_IMPORTE). |
| S7 | A, C | H | COALESCE y SHRINK SPACE son en línea y no bloquean (07c). |
| S8 | B | H | REVERSE reparte las inserciones pero deja de servir para rangos (rango con REVERSE: 878 lecturas con FULL SCAN). |
| S9 | C | G | Un UPDATE de una columna sin índice no toca ningún índice. |
| S10 | B | C | La altura depende del factor de ramificación, que depende del tamaño de la clave (fo = 370 en IX_PED_CLIENTE). |
| S11 | A, C | D | En un IOT las filas se guardan en el índice y no hay salto a la tabla (Q15: 3 lecturas frente a 4). |
| S12 | B | I | Oracle compara el SCN de checkpoint del control file con el de la cabecera del datafile. |
| S13 | C | I | CKPT registra el checkpoint en el control file y en las cabeceras. |
| S14 | B, E | I | En NOMOUNT solo responden v$instance y v$parameter (v$database exige MOUNT: ORA-01507). |
| S15 | B | K | ARCHIVELOG se activa con la base montada: SHUTDOWN, STARTUP MOUNT, ALTER DATABASE ARCHIVELOG, OPEN. |
| S16 | B | J | Un grupo INACTIVE ya archivado se recrea con CLEAR LOGFILE GROUP n. |
| S17 | A, C | M | El undo sirve para lectura consistente y para flashback query. |
| S18 | B | M | Los bloques de undo también se protegen con redo, para poder rehacerlos antes de deshacer. |
| S19 | A | N | Tras "Commit complete" lo garantizado es que el redo está en el redo log online. |
| S20 | A | I | Un MTTR objetivo menor implica checkpoints incrementales más frecuentes y recuperación más rápida. |
| S21 | B | L | ARCn no puede archivar, por ejemplo con la FRA llena (ORA-19815, ORA-16038). |
| S22 | B | O | Primero se pone el datafile OFFLINE para mantener el resto del servicio (simulacro D). |
| S23 | B | O | SYSTEM obliga a cerrar la base: MOUNT, RESTORE, RECOVER, OPEN (no lo probé: solo practiqué un datafile de aplicación). |
| S24 | B | O | En NOARCHIVELOG solo se restaura la copia en frío y se pierde lo posterior (simulacro C, RPO 11 s). |
| S25 | B, D | M | Subir UNDO_RETENTION y el tamaño de undo, y RETENTION GUARANTEE si es crítica (undo_retention = 900). |
| S26 | A | K | V$RECOVERY_AREA_USAGE da el uso de la FRA por tipo de archivo. |

## Tabla RTO/RPO de los cuatro simulacros

| Simulacro | Fallo | RTO medido | RPO real |
|---|---|---|---|
| A (14a) | Caída de instancia (`SHUTDOWN ABORT`) | No cronometrado: tras el STARTUP, healthy en la primera sonda (t=0 s) | 0: lo confirmado (102) sobrevive y lo no confirmado (103) se deshace |
| B (14b) | Pérdida de un control file (`control03.ctl`) | No cronometrado: copia de `control01.ctl` y arranque desde NOMOUNT, healthy en t=0 s | 0: no se perdió ningún dato |
| C (14c) | `DROP TABLE ... PURGE`, restauro la copia completa | 256 s | 11 s |
| D (14d) | Pérdida del datafile 16 (`academia01.dbf`) | 19 s (21 s desde el fallo) | 0 |

## Retrospectiva sin culpables

**A — Caída de instancia.** Qué me sorprendió: que el redo scan lee también cambios no confirmados (286 bloques, 1773 KB) y que luego se deshacen solos, sin que yo haga nada. Qué cambiaría: cronometrar el RTO en el propio script, porque ahora solo tengo la sonda de salud.

**B — Pérdida de un control file.** Qué me sorprendió: que el fallo salga al MONTAR (ORA-00205) y no al arrancar la instancia, y que el alert log diga exactamente qué archivo falta. Qué cambiaría: cronometrar este simulacro y poner las copias del control file en volúmenes distintos, porque con las tres en el mismo no se protegen del disco.

**C — Borrado de tabla.** Qué me sorprendió: los 256 s de RTO frente a los 19 s de D; restaurar todo para recuperar una tabla es muy caro y encima pierde lo hecho después de la copia (11 s). Qué cambiaría: usar siempre primero `FLASHBACK TABLE` (papelera) y restringir el `PURGE`; para casos graves, una copia más reciente o recuperación hasta un punto en el tiempo con ARCHIVELOG.

**D — Pérdida de un datafile.** Qué me sorprendió: que Oracle cerrara la PDB (ORA-63999) y hubiera que reparar con ella montada y reabrirla después. Qué cambiaría: dejar el runbook `docs/runbooks/perdida-datafile.md` accesible para quien esté de guardia y comprobar que hay copia RMAN antes de que haga falta (el healthcheck ya lo vigila en el apartado 7).
