# Runbook: pérdida de un datafile de negocio (oralab-26ai)

Para la persona de guardia que no ha hecho el Lab 5. Probado en el simulacro D
(`docs/bitacora/lab5/evidencia/script/*_14d-perdida-datafile.script.log`): RPO 0 y RTO de 21 s desde el fallo.

## 1. Síntoma
Las consultas a las tablas del tablespace afectado fallan con:
- `ORA-01116: error in opening database file <n>`
- `ORA-01110: data file <n>: '<ruta>'`
- `ORA-27041: unable to open file` (`Linux-x86_64 Error: 2: No such file or directory`)

Si el alert log muestra `ORA-63999`, Oracle **ha cerrado la PDB entera** (FREEPDB1 en MOUNTED): no solo ese
tablespace está caído, toda la PDB lo está.

## 2. Comprobaciones previas (antes de tocar nada)
Como SYSDBA (`docker exec -it oralab-26ai sqlplus / as sysdba`):
1. ¿Qué archivo? `SELECT file#, name, status FROM v$datafile WHERE file# = <n>;` y el alert log
   (`bash scripts/lab4/06-alert-log.sh`).
2. ¿La base está en ARCHIVELOG? `SELECT log_mode FROM v$database;`. Si dice NOARCHIVELOG, **para**: este runbook
   no sirve; solo queda restaurar la copia en frío completa (`scripts/ops/restaurar-estado.sh`) y se pierde lo
   posterior a ella.
3. ¿Hay copia RMAN del archivo? `docker exec -i oralab-26ai rman target /` y después `LIST BACKUP OF DATAFILE <n>;`.
   Si no hay ninguna, para y escala.
4. ¿Estado de la PDB? `SELECT name, open_mode FROM v$pdbs;` (READ WRITE o MOUNTED).

## 3. Reparación
Si la PDB sigue **READ WRITE**, aísla el archivo para que el resto de la PDB siga dando servicio:
```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE <n> OFFLINE;
```
Si está **cerrándose**, espera a que quede completamente **MOUNTED** antes de lanzar RMAN: un RESTORE durante el
cierre falla.

En RMAN (`rman target /`):
```
RESTORE DATAFILE <n>;
RECOVER DATAFILE <n>;
```
Después, como SYSDBA:
```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE <n> ONLINE;
-- solo si estaba MOUNTED:
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
```

## 4. Verificación
- `SELECT name, open_mode FROM v$pdbs;`: FREEPDB1 en READ WRITE.
- Una consulta a una tabla del tablespace responde (en el simulacro, `aca_estudiantes`: 20 000 filas).
- Un cambio confirmado **después** de la copia sigue ahí (en el simulacro, la fila 104 = EGRESADO): RECOVER ha
  aplicado el redo archivado y el redo en línea → RPO 0.
- `bash scripts/ops/esperar-healthy.sh` termina en `READWRITE/READWRITE`.

## 5. Cuándo escalar
- NOARCHIVELOG, o falta algún redo archivado (`RMAN-06054`, `RMAN-06025`): no es posible un RPO 0.
- No hay copia RMAN del archivo.
- El archivo afectado es de SYSTEM o de UNDO: la reparación exige la base en MOUNT y afecta a toda la instancia.
- `RESTORE` o `RECOVER` fallan dos veces con el mismo error.

## 6. Después
- Haz una copia nueva: `BACKUP TABLESPACE FREEPDB1:<tablespace>;` o `bash scripts/ops/backup-estado.sh <etiqueta>`.
- Registra en el informe: hora del fallo, hora de la reparación (RTO), datos perdidos (RPO) y la causa.
