-- Índices: plan de ejecución y tiempo promedio antes y después de crear cada índice.
SET LINESIZE 200
SET PAGESIZE 100
SET SERVEROUTPUT ON

-- Borra los índices de esta prueba si ya existen (por ejemplo, si se usó antes
-- la pantalla Rendimiento de consultas), para que el script se pueda repetir.
BEGIN
    FOR i IN (SELECT index_name
                FROM user_indexes
               WHERE index_name IN ('IDX_RESERVA_ENTRADA_ESTADO', 'IDX_CLIENTE_CORREO_UPPER',
                                    'IDX_PAGO_FECHA_VALOR', 'IDX_RESERVA_ESTADO')) LOOP
        EXECUTE IMMEDIATE 'DROP INDEX ' || i.index_name;
    END LOOP;
END;
/


-- 1. Llegadas de un día por estado · índice COMPUESTO
EXPLAIN PLAN SET STATEMENT_ID = 'C1_ANTES' FOR
SELECT estado, COUNT(*) AS reservas
  FROM RESERVA
 WHERE fecha_entrada = DATE '2025-07-15'
 GROUP BY estado;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C1_ANTES', 'TYPICAL'));

-- Tiempo: C1 sin índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT estado, COUNT(*) AS reservas FROM RESERVA WHERE fecha_entrada = DATE '2025-07-15' GROUP BY estado) LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT estado, COUNT(*) AS reservas FROM RESERVA WHERE fecha_entrada = DATE '2025-07-15' GROUP BY estado) LOOP NULL; END LOOP;
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
 WHERE fecha_entrada = DATE '2025-07-15'
 GROUP BY estado;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C1_DESPUES', 'TYPICAL'));

-- Tiempo: C1 con índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT estado, COUNT(*) AS reservas FROM RESERVA WHERE fecha_entrada = DATE '2025-07-15' GROUP BY estado) LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT estado, COUNT(*) AS reservas FROM RESERVA WHERE fecha_entrada = DATE '2025-07-15' GROUP BY estado) LOOP NULL; END LOOP;
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
 WHERE UPPER(correo) = UPPER('Cliente1500@TurismoUQ.com');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C2_ANTES', 'TYPICAL'));

-- Tiempo: C2 sin índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT id_cliente, nombre, cedula, correo FROM CLIENTE WHERE UPPER(correo) = UPPER('Cliente1500@TurismoUQ.com')) LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT id_cliente, nombre, cedula, correo FROM CLIENTE WHERE UPPER(correo) = UPPER('Cliente1500@TurismoUQ.com')) LOOP NULL; END LOOP;
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
 WHERE UPPER(correo) = UPPER('Cliente1500@TurismoUQ.com');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C2_DESPUES', 'TYPICAL'));

-- Tiempo: C2 con índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT id_cliente, nombre, cedula, correo FROM CLIENTE WHERE UPPER(correo) = UPPER('Cliente1500@TurismoUQ.com')) LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT id_cliente, nombre, cedula, correo FROM CLIENTE WHERE UPPER(correo) = UPPER('Cliente1500@TurismoUQ.com')) LOOP NULL; END LOOP;
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
 WHERE fecha = DATE '2025-07-01';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C3_ANTES', 'TYPICAL'));

-- Tiempo: C3 sin índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO WHERE fecha = DATE '2025-07-01') LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO WHERE fecha = DATE '2025-07-01') LOOP NULL; END LOOP;
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
 WHERE fecha = DATE '2025-07-01';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C3_DESPUES', 'TYPICAL'));

-- Tiempo: C3 con índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO WHERE fecha = DATE '2025-07-01') LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT COUNT(*) AS pagos, SUM(valor) AS recaudado FROM PAGO WHERE fecha = DATE '2025-07-01') LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C3 con índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/


-- 4. Índice que NO ayuda: FINALIZADA es la gran mayoría de las reservas,
--    así que leer la tabla completa es más barato que usar el índice.
EXPLAIN PLAN SET STATEMENT_ID = 'C4_ANTES' FOR
SELECT COUNT(*) AS reservas, SUM(valor_total) AS ingresos
  FROM RESERVA
 WHERE estado = 'FINALIZADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C4_ANTES', 'TYPICAL'));

-- Tiempo: C4 sin índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT COUNT(*) AS reservas, SUM(valor_total) AS ingresos FROM RESERVA WHERE estado = 'FINALIZADA') LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT COUNT(*) AS reservas, SUM(valor_total) AS ingresos FROM RESERVA WHERE estado = 'FINALIZADA') LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C4 sin índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/

CREATE INDEX idx_reserva_estado ON RESERVA (estado);
-- Histograma: sin él Oracle supone que los 4 estados se reparten por igual (25 % cada uno)
-- y elegiría el índice; con él sabe que FINALIZADA es la mayoría.
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'RESERVA', cascade => TRUE, method_opt => 'FOR ALL INDEXED COLUMNS SIZE 254');

-- El plan no cambia: el optimizador ignora el índice
EXPLAIN PLAN SET STATEMENT_ID = 'C4_DESPUES' FOR
SELECT COUNT(*) AS reservas, SUM(valor_total) AS ingresos
  FROM RESERVA
 WHERE estado = 'FINALIZADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C4_DESPUES', 'TYPICAL'));

-- Tiempo: C4 con índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT COUNT(*) AS reservas, SUM(valor_total) AS ingresos FROM RESERVA WHERE estado = 'FINALIZADA') LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT COUNT(*) AS reservas, SUM(valor_total) AS ingresos FROM RESERVA WHERE estado = 'FINALIZADA') LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C4 con índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/

-- Forzando el índice el costo sube
EXPLAIN PLAN SET STATEMENT_ID = 'C4_FORZADO' FOR
SELECT /*+ INDEX(r idx_reserva_estado) */ COUNT(*) AS reservas, SUM(valor_total) AS ingresos
  FROM RESERVA r
 WHERE estado = 'FINALIZADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'C4_FORZADO', 'TYPICAL'));

-- Tiempo: C4 forzando el índice
DECLARE
    v_inicio TIMESTAMP WITH TIME ZONE;
    v_tiempo INTERVAL DAY TO SECOND;
BEGIN
    FOR r IN (SELECT /*+ INDEX(r idx_reserva_estado) */ COUNT(*) AS reservas, SUM(valor_total) AS ingresos FROM RESERVA r WHERE estado = 'FINALIZADA') LOOP NULL; END LOOP;   -- calentamiento
    v_inicio := SYSTIMESTAMP;
    FOR i IN 1 .. 50 LOOP
        FOR r IN (SELECT /*+ INDEX(r idx_reserva_estado) */ COUNT(*) AS reservas, SUM(valor_total) AS ingresos FROM RESERVA r WHERE estado = 'FINALIZADA') LOOP NULL; END LOOP;
    END LOOP;
    v_tiempo := SYSTIMESTAMP - v_inicio;
    DBMS_OUTPUT.PUT_LINE('C4 forzando el índice: '
        || ROUND((EXTRACT(MINUTE FROM v_tiempo) * 60 + EXTRACT(SECOND FROM v_tiempo)) * 1000 / 50, 3)
        || ' ms promedio (50 ejecuciones)');
END;
/

-- No sirve y hace más lentos los INSERT de RESERVA: se elimina
DROP INDEX idx_reserva_estado;