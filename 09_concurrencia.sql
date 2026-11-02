-- Experimento de concurrencia: dos sesiones reservando la misma habitación al tiempo.
-- Los dos procedimientos hacen lo mismo; la única diferencia es el SELECT ... FOR UPDATE.
-- Entre el INSERT y el COMMIT esperan unos segundos (DBMS_SESSION.SLEEP) para simular
-- el tiempo de procesar la reserva y que las dos sesiones alcancen a cruzarse.

-- SIN BLOQUEO: las dos sesiones validan, ninguna ve la reserva sin confirmar de la otra,
-- y la habitación queda reservada dos veces.
CREATE OR REPLACE PROCEDURE sp_reservar_sin_bloqueo(
    p_id_cliente      IN  NUMBER,
    p_id_habitacion   IN  NUMBER,
    p_fecha_in        IN  DATE,
    p_fecha_out       IN  DATE,
    p_numero_personas IN  NUMBER,
    p_segundos_espera IN  NUMBER,
    p_id_reserva      OUT NUMBER,
    p_ms_bloqueo      OUT NUMBER
) IS
    v_cruces NUMBER;
    v_valor  NUMBER;
BEGIN
    p_ms_bloqueo := 0;

    -- 1. Validar disponibilidad con una lectura normal (no bloquea nada)
    SELECT COUNT(*)
      INTO v_cruces
      FROM RESERVA_HABITACION rh
      JOIN RESERVA r ON r.id_reserva = rh.id_reserva
     WHERE rh.id_habitacion = p_id_habitacion
       AND r.estado IN ('CONFIRMADA', 'PENDIENTE')
       AND p_fecha_in  < r.fecha_salida
       AND p_fecha_out > r.fecha_entrada;

    IF v_cruces > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20102,
            'La habitación no está disponible en el rango de fechas solicitado.'
        );
    END IF;

    -- 2. Registrar la reserva
    v_valor := PKG_TURISMO_UQ.fn_valor_estadia(p_id_habitacion, p_fecha_in, p_fecha_out);

    INSERT INTO RESERVA (
        id_reserva, fecha_reserva, fecha_entrada, fecha_salida,
        numero_personas, estado, valor_total, id_cliente
    ) VALUES (
        seq_reserva.NEXTVAL, TRUNC(SYSDATE), TRUNC(p_fecha_in), TRUNC(p_fecha_out),
        p_numero_personas, 'CONFIRMADA', v_valor, p_id_cliente
    )
    RETURNING id_reserva INTO p_id_reserva;

    INSERT INTO RESERVA_HABITACION (id_reserva, id_habitacion)
    VALUES (p_id_reserva, p_id_habitacion);

    -- 3. Tiempo de procesamiento antes de confirmar
    DBMS_SESSION.SLEEP(LEAST(GREATEST(NVL(p_segundos_espera, 5), 1), 15));

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_reservar_sin_bloqueo;
/

-- CON BLOQUEO: la primera sesión bloquea la fila de la habitación con FOR UPDATE.
-- La segunda queda esperando en ese SELECT hasta que la primera hace COMMIT;
-- entonces valida, ya ve la reserva confirmada y la rechaza.
CREATE OR REPLACE PROCEDURE sp_reservar_con_bloqueo(
    p_id_cliente      IN  NUMBER,
    p_id_habitacion   IN  NUMBER,
    p_fecha_in        IN  DATE,
    p_fecha_out       IN  DATE,
    p_numero_personas IN  NUMBER,
    p_segundos_espera IN  NUMBER,
    p_id_reserva      OUT NUMBER,
    p_ms_bloqueo      OUT NUMBER
) IS
    v_cruces     NUMBER;
    v_valor      NUMBER;
    v_habitacion HABITACION.id_habitacion%TYPE;
    v_inicio     TIMESTAMP WITH TIME ZONE;
    v_espera     INTERVAL DAY TO SECOND;
BEGIN
    -- 1. Bloquear la habitación (aquí espera la segunda sesión)
    v_inicio := SYSTIMESTAMP;

    BEGIN
        SELECT id_habitacion
          INTO v_habitacion
          FROM HABITACION
         WHERE id_habitacion = p_id_habitacion
           FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20103, 'No existe la habitación con ID ' || p_id_habitacion);
    END;

    v_espera     := SYSTIMESTAMP - v_inicio;
    p_ms_bloqueo := ROUND(EXTRACT(MINUTE FROM v_espera) * 60000 + EXTRACT(SECOND FROM v_espera) * 1000);

    -- 2. Validar disponibilidad (ya con la habitación bloqueada)
    SELECT COUNT(*)
      INTO v_cruces
      FROM RESERVA_HABITACION rh
      JOIN RESERVA r ON r.id_reserva = rh.id_reserva
     WHERE rh.id_habitacion = p_id_habitacion
       AND r.estado IN ('CONFIRMADA', 'PENDIENTE')
       AND p_fecha_in  < r.fecha_salida
       AND p_fecha_out > r.fecha_entrada;

    IF v_cruces > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20102,
            'La habitación no está disponible en el rango de fechas solicitado.'
        );
    END IF;

    -- 3. Registrar la reserva
    v_valor := PKG_TURISMO_UQ.fn_valor_estadia(p_id_habitacion, p_fecha_in, p_fecha_out);

    INSERT INTO RESERVA (
        id_reserva, fecha_reserva, fecha_entrada, fecha_salida,
        numero_personas, estado, valor_total, id_cliente
    ) VALUES (
        seq_reserva.NEXTVAL, TRUNC(SYSDATE), TRUNC(p_fecha_in), TRUNC(p_fecha_out),
        p_numero_personas, 'CONFIRMADA', v_valor, p_id_cliente
    )
    RETURNING id_reserva INTO p_id_reserva;

    INSERT INTO RESERVA_HABITACION (id_reserva, id_habitacion)
    VALUES (p_id_reserva, p_id_habitacion);

    -- 4. Tiempo de procesamiento antes de confirmar (la habitación sigue bloqueada)
    DBMS_SESSION.SLEEP(LEAST(GREATEST(NVL(p_segundos_espera, 5), 1), 15));

    COMMIT;   -- libera el bloqueo

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;   -- también libera el bloqueo
        RAISE;
END sp_reservar_con_bloqueo;
/

-- Borra las reservas de una prueba (misma habitación y mismas fechas exactas)
-- para poder repetir el experimento.
CREATE OR REPLACE PROCEDURE sp_limpiar_prueba_concurrencia(
    p_id_habitacion IN  NUMBER,
    p_fecha_in      IN  DATE,
    p_fecha_out     IN  DATE,
    p_borradas      OUT NUMBER
) IS
BEGIN
    p_borradas := 0;

    FOR x IN (SELECT r.id_reserva
                FROM RESERVA r
                JOIN RESERVA_HABITACION rh ON rh.id_reserva = r.id_reserva
               WHERE rh.id_habitacion = p_id_habitacion
                 AND r.fecha_entrada  = TRUNC(p_fecha_in)
                 AND r.fecha_salida   = TRUNC(p_fecha_out)) LOOP
        DELETE FROM RESERVA_SERVICIO   WHERE id_reserva = x.id_reserva;
        DELETE FROM PAGO               WHERE id_reserva = x.id_reserva;
        DELETE FROM RESERVA_HABITACION WHERE id_reserva = x.id_reserva;
        DELETE FROM RESERVA            WHERE id_reserva = x.id_reserva;
        p_borradas := p_borradas + 1;
    END LOOP;

    COMMIT;
END sp_limpiar_prueba_concurrencia;
/