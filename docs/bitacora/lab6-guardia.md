# Guardia nocturna · Lab 6 · E051

## INC-601 · La pantalla de secretaría se queda colgada
- Detección: Secretaría avisa de que la pantalla de matrículas no responde; al revisar el turno hay sesiones esperando por un bloqueo de fila (enq: TX - row lock contention).
- Impacto: Las operaciones de la aplicación sobre ACA_ESTUDIANTES quedan en espera y el personal de secretaría no puede trabajar.
- Diagnóstico: Con `08-diagnostico.sql` se identificó la sesión bloqueadora (SID 177, SERIAL# 36494) con una transacción abierta sin confirmar, y las sesiones que esperaban detrás de ella.
- Causa raíz: Una sesión de la aplicación dejó un UPDATE sin COMMIT y mantuvo el bloqueo de fila; al cerrarla, la siguiente sesión de la cola tomó el bloqueo (SID 210, SERIAL# 13736).
- Intervención: `ALTER SYSTEM KILL SESSION '177,36494' IMMEDIATE`; como otra sesión de la cola volvió a bloquear, `ALTER SYSTEM KILL SESSION '210,13736' IMMEDIATE`. El UPDATE se deshizo.
- Validación: 0 sesiones bloqueadas, la fila 101 sigue en ACTIVO y la aplicación responde con normalidad.
- Acción preventiva: Transacciones cortas con COMMIT/ROLLBACK, límite de inactividad en el perfil de la cuenta de aplicación y revisión de bloqueos en la lista de turno.

## INC-602 · La aplicación no conecta: ORA-12514
- Detección: La aplicación recibe ORA-12514 (el listener no conoce el servicio) tras un reinicio de la instancia.
- Impacto: Ninguna conexión por el servicio academia_app: la aplicación está caída aunque la instancia dice estar abierta.
- Diagnóstico: Con `08-diagnostico.sql` y `lsnrctl services`, la PDB FREEPDB1 estaba abierta sin estado guardado tras el reinicio y el servicio no aparecía en el listener; `START_SERVICE` respondió ORA-44305 porque ya estaba en marcha.
- Causa raíz: Tras el reinicio la PDB no se abrió sola por no tener el estado guardado (SAVE STATE), así que el servicio no se registró en el listener.
- Intervención: `DBMS_SERVICE.START_SERVICE('academia_app')` y `ALTER PLUGGABLE DATABASE freepdb1 SAVE STATE`.
- Validación: El servicio academia_app figura READY en el listener, la aplicación conecta y devuelve 17.600 alumnos activos.
- Acción preventiva: Ejecutar SAVE STATE tras cada cambio de estado de la PDB y pasar `validar-arranque.sql` después de cualquier reinicio.

## INC-603 · La aplicación no entra: ORA-28000
- Detección: La aplicación recibe ORA-28000 (cuenta bloqueada) al conectarse como APP_ACADEMIA.
- Impacto: La aplicación no puede entrar a la base, aunque el servicio y la PDB están bien.
- Diagnóstico: En `DBA_USERS` la cuenta APP_ACADEMIA aparecía bloqueada tras varios intentos fallidos.
- Causa raíz: La cuenta se bloqueó por superar los intentos fallidos permitidos por su perfil (credencial incorrecta repetida desde algún cliente).
- Intervención: `ALTER USER app_academia ACCOUNT UNLOCK` en FREEPDB1.
- Validación: La cuenta pasa a OPEN y la aplicación conecta y lee datos.
- Acción preventiva: Localizar el cliente que falla (credencial antigua), usar un perfil de cuenta de servicio con límites adecuados y alertar de los bloqueos de cuenta.
