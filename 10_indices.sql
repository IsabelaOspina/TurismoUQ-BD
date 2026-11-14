-- Índices: plan de ejecución y tiempo promedio antes y después de crear cada índice.
SET LINESIZE 200
SET PAGESIZE 100
SET SERVEROUTPUT ON
SET VERIFY OFF

-- Datos de las consultas: SQL Developer los pide una sola vez al ejecutar el script (F5).
-- Valores de ejemplo: 2025-07-15, Cliente1500@TurismoUQ.com, 2025-07-01 y EFECTIVO.
ACCEPT fecha_llegada CHAR PROMPT 'Consulta 1 - Fecha de llegada (AAAA-MM-DD): '
ACCEPT correo        CHAR PROMPT 'Consulta 2 - Correo del cliente: '
ACCEPT fecha_pago    CHAR PROMPT 'Consulta 3 - Fecha del pago (AAAA-MM-DD): '
ACCEPT metodo        CHAR PROMPT 'Consulta 4 - Método de pago (EFECTIVO, TARJETA, TRANSFERENCIA o PSE): '

-- Borra los índices de esta prueba si ya existen (por ejemplo, si se usó antes
-- la pantalla Rendimiento de consultas), para que el script se pueda repetir.
BEGIN
    FOR i IN (SELECT index_name
                FROM user_indexes
               WHERE index_name IN ('IDX_RESERVA_ENTRADA_ESTADO', 'IDX_CLIENTE_CORREO_UPPER',
                                    'IDX_PAGO_FECHA_VALOR', 'IDX_RESERVA_ESTADO', 'IDX_PAGO_METODO')) LOOP
        EXECUTE IMMEDIATE 'DROP INDEX ' || i.index_name;
    END LOOP;
END;
/


-- 1. Llegadas de un día por estado · índice COMPUESTO
EXPLAIN PLAN SET STATEMENT_ID = 'C1_ANTES' FOR
SELECT estado, COUNT(*) AS reservas
  FROM RESERVA
 WHERE fecha_entrada = DATE '&&fecha_llegada'
 GROUP BY estado;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C1_ANTES', 'TYPICAL'));

-- Tiempo: C1 sin índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT estado, COUNT(*) AS reservas FROM RESERVA WHERE fecha_entrada = DATE '&&fecha_llegada' GROUP BY estado) LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT estado, COUNT(*) AS reservas FROM RESERVA WHERE fecha_entrada = DATE '&&fecha_llegada' GROUP BY estado) LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C1 sin índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/

CREATE INDEX idx_reserva_entrada_estado ON RESERVA (fecha_entrada, estado);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'RESERVA', cascade => TRUE);

EXPLAIN PLAN SET STATEMENT_ID = 'C1_DESPUES' FOR
SELECT estado, COUNT(*) AS reservas
  FROM RESERVA
 WHERE fecha_entrada = DATE '&&fecha_llegada'
 GROUP BY estado;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C1_DESPUES', 'TYPICAL'));

-- Tiempo: C1 con índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT estado, COUNT(*) AS reservas FROM RESERVA WHERE fecha_entrada = DATE '&&fecha_llegada' GROUP BY estado) LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT estado, COUNT(*) AS reservas FROM RESERVA WHERE fecha_entrada = DATE '&&fecha_llegada' GROUP BY estado) LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C1 con índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/


-- 2. Cliente por correo sin importar mayúsculas · índice BASADO EN FUNCIÓN
EXPLAIN PLAN SET STATEMENT_ID = 'C2_ANTES' FOR
SELECT id_cliente, nombre, cedula, correo
  FROM CLIENTE
 WHERE UPPER(correo) = UPPER('&&correo');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C2_ANTES', 'TYPICAL'));

-- Tiempo: C2 sin índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT id_cliente, nombre, cedula, correo FROM CLIENTE WHERE UPPER(correo) = UPPER('&&correo')) LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT id_cliente, nombre, cedula, correo FROM CLIENTE WHERE UPPER(correo) = UPPER('&&correo')) LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C2 sin índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/

CREATE INDEX idx_cliente_correo_upper ON CLIENTE (UPPER(correo));
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTE', cascade => TRUE, method_opt => 'FOR ALL HIDDEN COLUMNS SIZE 1');

EXPLAIN PLAN SET STATEMENT_ID = 'C2_DESPUES' FOR
SELECT id_cliente, nombre, cedula, correo
  FROM CLIENTE
 WHERE UPPER(correo) = UPPER('&&correo');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C2_DESPUES', 'TYPICAL'));

-- Tiempo: C2 con índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT id_cliente, nombre, cedula, correo FROM CLIENTE WHERE UPPER(correo) = UPPER('&&correo')) LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT id_cliente, nombre, cedula, correo FROM CLIENTE WHERE UPPER(correo) = UPPER('&&correo')) LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C2 con índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/


-- 3. Pagos recibidos en un día · índice COMPUESTO
EXPLAIN PLAN SET STATEMENT_ID = 'C3_ANTES' FOR
SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado
  FROM PAGO
 WHERE fecha = DATE '&&fecha_pago';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C3_ANTES', 'TYPICAL'));

-- Tiempo: C3 sin índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO WHERE fecha = DATE '&&fecha_pago') LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO WHERE fecha = DATE '&&fecha_pago') LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C3 sin índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/

CREATE INDEX idx_pago_fecha_valor ON PAGO (fecha, valor);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'PAGO', cascade => TRUE);

EXPLAIN PLAN SET STATEMENT_ID = 'C3_DESPUES' FOR
SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado
  FROM PAGO
 WHERE fecha = DATE '&&fecha_pago';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C3_DESPUES', 'TYPICAL'));

-- Tiempo: C3 con índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO WHERE fecha = DATE '&&fecha_pago') LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO WHERE fecha = DATE '&&fecha_pago') LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C3 con índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/


-- 4. Índice que NO ayuda: solo hay 4 métodos de pago (cada uno es cerca del 25 %)
--    y esos pagos están repartidos por toda la tabla. Leer la tabla completa de forma
--    secuencial es más barato que saltar fila por fila desde el índice.
EXPLAIN PLAN SET STATEMENT_ID = 'C4_ANTES' FOR
SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado
  FROM PAGO
 WHERE metodo_pago = UPPER('&&metodo');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C4_ANTES', 'TYPICAL'));

-- Tiempo: C4 sin índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO WHERE metodo_pago = UPPER('&&metodo')) LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO WHERE metodo_pago = UPPER('&&metodo')) LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C4 sin índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/

CREATE INDEX idx_pago_metodo ON PAGO (metodo_pago);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'PAGO', cascade => TRUE);

-- El plan no cambia: el optimizador ignora el índice
EXPLAIN PLAN SET STATEMENT_ID = 'C4_DESPUES' FOR
SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado
  FROM PAGO
 WHERE metodo_pago = UPPER('&&metodo');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C4_DESPUES', 'TYPICAL'));

-- Tiempo: C4 con índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO WHERE metodo_pago = UPPER('&&metodo')) LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO WHERE metodo_pago = UPPER('&&metodo')) LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C4 con índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/

-- Forzando el índice el costo sube
EXPLAIN PLAN SET STATEMENT_ID = 'C4_FORZADO' FOR
SELECT /*+ INDEX(p idx_pago_metodo) */ COUNT(*) AS pagos, SUM(valor) AS recaudado
  FROM PAGO p
 WHERE metodo_pago = UPPER('&&metodo');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C4_FORZADO', 'TYPICAL'));

-- Tiempo: C4 forzando el índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT /*+ INDEX(p idx_pago_metodo) */ COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO p WHERE metodo_pago = UPPER('&&metodo')) LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT /*+ INDEX(p idx_pago_metodo) */ COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO p WHERE metodo_pago = UPPER('&&metodo')) LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C4 forzando el índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/

-- No sirve y hace más lentos los INSERT de PAGO: se elimina
DROP INDEX idx_pago_metodo;

-- Libera los datos para que la próxima ejecución los vuelva a pedir
UNDEFINE fecha_llegada
UNDEFINE correo
UNDEFINE fecha_pago
UNDEFINE metodo