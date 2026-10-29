# Lab 3: respuestas de comprobación

Rutas de evidencia relativas a `docs/bitacora/evidencia/`.

## Docker

**1. Imagen frente a contenedor (G2 y G4).**
Una imagen es una plantilla de solo lectura formada por capas; un contenedor es una instancia de esa imagen en ejecución, con una capa escribible propia encima. En G2, `docker run hello-world` descargó la imagen y creó un contenedor que imprimió su mensaje y terminó en `Exited (0)`. En G4, `docker run -it --name prueba alpine:3.20 sh` creó otro contenedor distinto a partir de la imagen `alpine:3.20`. De una misma imagen pueden salir tantos contenedores como queramos. Evidencia: `script/20260927T212128Z_03-tutorial-docker.script.log`.

**2. Por qué `nota.txt` desaparece en G5 y no en G6.**
En G5 el archivo se escribió en `/tmp/nota.txt`, dentro de la capa escribible del contenedor; al recrear el contenedor esa capa es nueva y el archivo ya no existe (`cat: can't open '/tmp/nota.txt'`). En G6 se escribió en `/datos/nota.txt`, que es un volumen (`datos-prueba`) gestionado por Docker fuera del contenedor: sobrevive aunque el contenedor se borre (`--rm`). Evidencia: log 03, ejercicios G5 y G6.

**3. `docker ps` frente a `docker ps -a`; `Exited (0)`.**
`docker ps` lista solo los contenedores en marcha; `docker ps -a` lista también los parados. `Exited (0)` significa que el proceso principal del contenedor terminó y que lo hizo sin error (código de salida 0). Evidencia: log 03 (`hello-world ... Exited (0)` y `prueba ... Exited (0)`).

**4. Puertos en `-p 8181:8181` y `-p 80:8080`.**
El formato es `puerto_del_equipo:puerto_del_contenedor`: el primer número es el de mi equipo y el segundo el del contenedor. Con nginx, `-p 80:8080` publicaría el 80 del equipo hacia el 8080 del contenedor, pero nginx escucha en el 80 dentro del contenedor: no respondería nadie (y el 80 del equipo puede estar ocupado o requerir privilegios). Lo correcto fue `-p 8080:80` (log 03, G7: `0.0.0.0:8080->80/tcp`).

**5. Por qué Oracle sigue en marcha y hello-world termina solo.**
Un contenedor vive mientras vive su proceso principal. hello-world imprime un texto y su proceso termina, así que el contenedor pasa a `Exited`. El contenedor de Oracle ejecuta un proceso que mantiene la instancia y el listener en primer plano de forma indefinida. Evidencia: `script/20261029T224003Z_13-verificacion-final.script.log`, bloque 3 (`oralab-26ai Up 5 hours (healthy)`).

**6. Qué es el digest y por qué lo registramos.**
El digest es el hash SHA-256 del contenido de la imagen y la identifica de forma inmutable. `:latest` es una etiqueta móvil que mañana puede apuntar a otra versión. Registrar el digest (`sha256:f988b0c04c4c386cd306a2a914c0d7a9702d83acc31b064a28ad8eb6278a8fba`, evidencias 04 y 13) permite saber exactamente qué versión se instaló y reproducirla o auditarla.

**7. Qué borraría de verdad los datos de Oracle.**
`docker volume rm oralab-26ai-data` (o `docker rm -v` / `docker volume prune` sobre ese volumen). `docker rm oralab-26ai` solo borra el contenedor y su capa escribible: los datos están en el volumen `oralab-26ai-data`, montado en `/opt/oracle/oradata`, que sigue existiendo (evidencias 05 y 13, bloque 4).

## Git, organización y evidencia

**8. Por qué dentro de `oracle-database-lab` con Issue, branch y PR.**
Porque el entorno es infraestructura como código: cada paso queda versionado y trazable (qué se cambió, cuándo y por qué, enlazado al Issue #1), se revisa antes de llegar a `main` y cualquiera puede reproducirlo desde los scripts. Una carpeta suelta no tiene historial, revisión ni trazabilidad.

**9. `source` frente a `bash` con `00-config.sh`.**
`bash 00-config.sh` lo ejecuta en un proceso hijo: las variables y la función `ts` se definen ahí y desaparecen al terminar. `source` lo ejecuta en la shell actual, de modo que `CONT_NAME`, `EVID`, `ts`, etc. quedan disponibles para los comandos y scripts siguientes.

**10. Partes de `20260915T091230Z_02-docker.script.log`.**
`20260915` es la fecha (15/09/2026), `T` separa fecha y hora, `091230` es la hora 09:12:30, `Z` indica UTC (formato ISO 8601 básico, que además se ordena bien alfabéticamente), `_02` es el número del paso, `docker` la descripción y `.script.log` el tipo de evidencia (grabación de terminal; las de SQL son `.spool.log`).

**11. Para qué sirve `.gitattributes`.**
Fija `text eol=lf` para `*.sh`, `*.sql` y `*.md`: Git guarda y entrega esos archivos con finales de línea de Linux aunque se editen en Windows. Evita el error de los CRLF en scripts (`$'\r': command not found`, `bad interpreter`).

**12. Por qué Create a merge commit y no Squash and merge.**
Cada commit de la rama es una Parte con su script y su evidencia y tiene valor propio; un merge commit conserva esa historia paso a paso en `main`. Squash lo aplastaría todo en un único commit y se perdería cuándo y cómo se verificó cada herramienta.

## Seguridad

**13. Las cuatro capas de la estrategia de contraseñas.**
1) `.gitignore` con `config/.env` antes de crear el archivo; 2) plantilla versionada `config/.env.example` con valores de ejemplo; 3) archivo real `config/.env` local, comprobado con `git check-ignore -v config/.env`; 4) los scripts leen la contraseña con `set -a; source config/.env; set +a` y usan `"$ORACLE_PWD"`, sin escribirla nunca. Si me salto la primera, un `git add` puede versionar el `.env` real y la contraseña quedaría en el historial. Evidencia: bloque 9 de la evidencia 13 (`OK: config/.env esta ignorado por Git`) y el escaneo O.2 (0 apariciones).

**14. Por qué no escribir la contraseña en `docker run`.**
Porque lo que se teclea queda en `~/.bash_history` en texto plano, se ve con `ps` mientras se ejecuta y aparece en `docker inspect` (variables de entorno). Además el script se copia y se comparte. Con `"$ORACLE_PWD"` solo queda el nombre de la variable.

**15. Si la contraseña está en un commit ya publicado.**
No basta con borrarla en un commit nuevo: sigue en el historial. Hay que dar el secreto por comprometido y rotarlo (cambiarlo en `config/.env` y en la base, recreando el contenedor si hace falta), avisar al docente y, si la política lo exige, limpiar el historial de la rama.

## Oracle y herramientas

**16. Por qué no SPOOL ni `@archivo.sql` con sqlplus dentro del contenedor.**
sqlplus se ejecuta dentro del contenedor: un SPOOL escribiría el archivo en el sistema de archivos del contenedor, no en el repositorio, y `@archivo.sql` buscaría el script dentro del contenedor, donde no existe (SP2-0310). En su lugar se envía el SQL por la entrada estándar (`docker exec -i ... < archivo.sql`) y se guarda la salida en el equipo con `tee` (evidencias 07 y 08). Con SQLcl, instalado en Linux, sí usamos SPOOL (evidencia 10).

**17. `WHENEVER SQLERROR EXIT SQL.SQLCODE` en V000 y V001.**
Hace que sqlplus termine en cuanto una sentencia falla, devolviendo el código del error. Así `08-aplicar-migraciones.sh` detecta el fallo y se detiene. Sin esa línea sqlplus seguiría ejecutando el resto, dejando la migración a medias y el script daría un falso éxito.

**18. Qué es una migración y por qué no editar V000 y V001.**
Una migración es un cambio de esquema versionado y numerado que se aplica una vez y en orden. Una vez aplicada forma parte de la historia de todas las bases que la ejecutaron: si la edito, el archivo ya no describe lo que tienen esas bases y los entornos divergen. Los cambios se hacen con una migración nueva (así lo hace el Lab 4 con V003). Evidencia: `spool/*_08-V000*` y `spool/*_08-V001*`.

**19. Por qué FREEPDB1 en SQL Developer.**
FREE es el servicio del CDB raíz (CDB$ROOT) y un SID identifica la instancia; los esquemas de negocio viven en la PDB FREEPDB1, y la forma de llegar a una PDB por red es su nombre de servicio. Evidencia: captura 11 (`Nombre del Servicio: FREEPDB1`, `Estado: Correcto`).

**20. SQLcl frente a SQL*Plus.**
SQLcl es el cliente moderno en Java: corre en mi equipo, tiene historial, autocompletado, `SQLFORMAT`, formatos de salida, scripting y Liquibase, y permite SPOOL al repositorio. SQL*Plus está instalado en todo servidor Oracle y es el que se usa dentro del contenedor, en scripts de arranque y en recuperación; un DBA necesita los dos. Evidencias 09, 10 y 13 (SQLcl 26.3).

## Entorno de trabajo

**21. Por qué pasar de Git Bash a Ubuntu en WSL 2.**
Git Bash es una emulación: convierte rutas como `/opt/...` en rutas de Windows y rompe argumentos de Docker, necesita `winpty` para terminales interactivas, no trae `free`, `ss`, `htop` y otras utilidades de administración, y las herramientas Java fallan al pedir contraseñas. En WSL 2 es Linux real, igual que los servidores y los contenedores. Evidencia: `script/*_01-requisitos.script.log`.

**22. Por qué `~/oracle-database-lab` y no `/mnt/c`, y por qué bash.**
El sistema de archivos de Windows montado en `/mnt/c` es mucho más lento desde WSL y no respeta bien permisos, ejecutables ni finales de línea; en `~` el repositorio vive en el sistema de archivos Linux. bash es la shell por defecto de prácticamente todos los servidores y la del shebang `#!/usr/bin/env bash`: así lo que escribo a mano y lo que corre en un script se comportan igual. zsh difiere en detalles (arrays, globbing, expansión de variables).
