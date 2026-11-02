CREATE OR REPLACE PACKAGE BODY PKG_TURISMO_UQ AS

    -- FUNCION: fn_valor_estadia
FUNCTION fn_valor_estadia(
    p_id_habitacion IN NUMBER,
    p_fecha_in      IN DATE,
    p_fecha_out     IN DATE
) RETURN NUMBER IS
    v_total      NUMBER := 0;
    v_noches     NUMBER;
    v_fecha_act  DATE;
    v_mes        NUMBER;
    v_tarifa     NUMBER;
BEGIN
    IF p_fecha_in IS NULL OR p_fecha_out IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Las fechas de entrada y salida son obligatorias.');
    END IF;

    IF TRUNC(p_fecha_out) <= TRUNC(p_fecha_in) THEN
        RAISE_APPLICATION_ERROR(-20002, 'La fecha de salida debe ser mayor que la de entrada.');
    END IF;

    v_noches := TRUNC(p_fecha_out) - TRUNC(p_fecha_in);

    FOR i IN 0..(v_noches - 1) LOOP
        v_fecha_act := TRUNC(p_fecha_in) + i;
        v_mes := EXTRACT(MONTH FROM v_fecha_act);

        BEGIN
            SELECT t.precio_noche INTO v_tarifa
              FROM TARIFA t
              JOIN TEMPORADA tmp ON t.id_temporada = tmp.id_temporada
             WHERE t.id_habitacion = p_id_habitacion
               AND tmp.mes = v_mes;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003,
                    'No hay tarifa registrada para la habitación ' || p_id_habitacion ||
                    ' en el mes ' || v_mes || ' (noche del ' || TO_CHAR(v_fecha_act, 'YYYY-MM-DD') || ').');
        END;

        v_total := v_total + v_tarifa;
    END LOOP;

    RETURN v_total;
END fn_valor_estadia;

    -- PROCEDIMIENTO: sp_crear_reserva
    PROCEDURE sp_crear_reserva(
        p_id_cliente       IN NUMBER,
        p_id_habitacion    IN NUMBER,
        p_fecha_in         IN DATE,
        p_fecha_out        IN DATE,
        p_numero_personas  IN NUMBER,
        p_id_reserva       OUT NUMBER
    ) IS

        v_capacidad     HABITACION.capacidad%TYPE;
        v_solapamientos NUMBER;
        v_valor         NUMBER;

    BEGIN

        -- 1. Validar fechas
        IF p_fecha_in IS NULL
           OR p_fecha_out IS NULL
           OR TRUNC(p_fecha_out) <= TRUNC(p_fecha_in) THEN

            RAISE_APPLICATION_ERROR(
                -20100,
                'La fecha de checkout debe ser posterior al checkin.'
            );
        END IF;

        -- 2. Validar número de personas
        IF p_numero_personas IS NULL OR p_numero_personas <= 0 THEN
            RAISE_APPLICATION_ERROR(
                -20104,
                'El número de personas debe ser mayor que cero.'
            );
        END IF;

        -- 3. Consultar y bloquear habitación
        BEGIN
            SELECT capacidad
            INTO v_capacidad
            FROM HABITACION
            WHERE id_habitacion = p_id_habitacion
            FOR UPDATE;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20103,
                    'No existe la habitación con ID ' || p_id_habitacion
                );
        END;

        -- 4. Validar capacidad
        IF p_numero_personas > v_capacidad THEN
            RAISE_APPLICATION_ERROR(
                -20101,
                'Capacidad excedida. La habitación admite máximo '
                || v_capacidad || ' personas.'
            );
        END IF;

        -- 5. Validar disponibilidad
        SELECT COUNT(*)
        INTO v_solapamientos
        FROM RESERVA_HABITACION rh
        JOIN RESERVA r
          ON r.id_reserva = rh.id_reserva
        WHERE rh.id_habitacion = p_id_habitacion
          AND r.estado IN ('CONFIRMADA', 'PENDIENTE')
          AND p_fecha_in < r.fecha_salida
          AND p_fecha_out > r.fecha_entrada;

        IF v_solapamientos > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20102,
                'La habitación no está disponible en el rango de fechas solicitado.'
            );
        END IF;

        -- 6. Calcular valor
        v_valor := fn_valor_estadia(
            p_id_habitacion,
            p_fecha_in,
            p_fecha_out
        );

        -- 7. Insertar reserva
        INSERT INTO RESERVA (
            id_reserva,
            fecha_reserva,
            fecha_entrada,
            fecha_salida,
            numero_personas,
            estado,
            valor_total,
            id_cliente
        ) VALUES (
            seq_reserva.NEXTVAL,
            TRUNC(SYSDATE),
            TRUNC(p_fecha_in),
            TRUNC(p_fecha_out),
            p_numero_personas,
            'CONFIRMADA',
            v_valor,
            p_id_cliente
        )
        RETURNING id_reserva INTO p_id_reserva;

        -- 8. Relacionar habitación
        INSERT INTO RESERVA_HABITACION (
            id_reserva,
            id_habitacion
        ) VALUES (
            p_id_reserva,
            p_id_habitacion
        );

    END sp_crear_reserva;

    -- PROCEDIMIENTO: sp_editar_reserva
    PROCEDURE sp_editar_reserva(
        p_id_reserva       IN NUMBER,
        p_id_cliente       IN NUMBER,
        p_id_habitacion    IN NUMBER,
        p_fecha_in         IN DATE,
        p_fecha_out        IN DATE,
        p_numero_personas  IN NUMBER
    ) IS

        v_estado          RESERVA.estado%TYPE;
        v_capacidad       HABITACION.capacidad%TYPE;
        v_solapamientos   NUMBER;
        v_pagos           NUMBER;
        v_valor           NUMBER;

    BEGIN

        -- 1. Buscar y bloquear la reserva
        BEGIN
            SELECT estado
            INTO v_estado
            FROM RESERVA
            WHERE id_reserva = p_id_reserva
            FOR UPDATE;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20110,
                    'No existe la reserva indicada.'
                );
        END;

        -- 2. Validar estado de la reserva
        IF v_estado NOT IN ('PENDIENTE', 'CONFIRMADA') THEN
            RAISE_APPLICATION_ERROR(
                -20111,
                'No se puede editar una reserva cancelada o finalizada.'
            );
        END IF;

        -- 3. Validar pagos confirmados
        SELECT COUNT(*)
        INTO v_pagos
        FROM PAGO
        WHERE id_reserva = p_id_reserva
          AND confirmado = 'SI';

        IF v_pagos > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20112,
                'No se puede editar una reserva que tiene pagos confirmados.'
            );
        END IF;

        -- 4. Validar fechas
        IF p_fecha_in IS NULL
           OR p_fecha_out IS NULL
           OR TRUNC(p_fecha_out) <= TRUNC(p_fecha_in) THEN

            RAISE_APPLICATION_ERROR(
                -20113,
                'La fecha de salida debe ser posterior a la entrada.'
            );
        END IF;

        -- 5. Validar número de personas
        IF p_numero_personas IS NULL OR p_numero_personas <= 0 THEN
            RAISE_APPLICATION_ERROR(
                -20114,
                'El número de personas debe ser mayor que cero.'
            );
        END IF;

        -- 6. Consultar y bloquear habitación
        BEGIN
            SELECT capacidad
            INTO v_capacidad
            FROM HABITACION
            WHERE id_habitacion = p_id_habitacion
            FOR UPDATE;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20115,
                    'No existe la habitación indicada.'
                );
        END;

        -- 7. Validar capacidad
        IF p_numero_personas > v_capacidad THEN
            RAISE_APPLICATION_ERROR(
                -20116,
                'La capacidad de la habitación es insuficiente.'
            );
        END IF;

        -- 8. Validar disponibilidad
        SELECT COUNT(*)
        INTO v_solapamientos
        FROM RESERVA_HABITACION rh
        JOIN RESERVA r
          ON r.id_reserva = rh.id_reserva
        WHERE rh.id_habitacion = p_id_habitacion
          AND r.id_reserva <> p_id_reserva
          AND r.estado IN ('CONFIRMADA', 'PENDIENTE')
          AND TRUNC(p_fecha_in) < TRUNC(r.fecha_salida)
          AND TRUNC(p_fecha_out) > TRUNC(r.fecha_entrada);

        IF v_solapamientos > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20117,
                'La habitación no está disponible en las fechas solicitadas.'
            );
        END IF;

        -- 9. Calcular nuevamente el valor de la estadía
        v_valor := fn_valor_estadia(
            p_id_habitacion,
            p_fecha_in,
            p_fecha_out
        );

        -- 10. Actualizar datos de la reserva
        UPDATE RESERVA
        SET id_cliente = p_id_cliente,
            fecha_entrada = TRUNC(p_fecha_in),
            fecha_salida = TRUNC(p_fecha_out),
            numero_personas = p_numero_personas,
            valor_total = v_valor
        WHERE id_reserva = p_id_reserva;

        -- 11. Actualizar habitación relacionada
        DELETE FROM RESERVA_HABITACION
        WHERE id_reserva = p_id_reserva;

        INSERT INTO RESERVA_HABITACION (
            id_reserva,
            id_habitacion
        ) VALUES (
            p_id_reserva,
            p_id_habitacion
        );

    END sp_editar_reserva;

    -- PROCEDIMIENTO: sp_liquidacion_mensual
    PROCEDURE sp_liquidacion_mensual(
        p_anio IN NUMBER,
        p_mes  IN NUMBER
    ) IS

        CURSOR c_liquidacion (
            cp_anio NUMBER,
            cp_mes NUMBER
        ) IS

            WITH reservas_mes AS (
                SELECT DISTINCT
                    h.id_alojamiento,
                    r.id_reserva,
                    r.valor_total
                FROM RESERVA r
                JOIN RESERVA_HABITACION rh
                  ON rh.id_reserva = r.id_reserva
                JOIN HABITACION h
                  ON h.id_habitacion = rh.id_habitacion
                WHERE r.estado IN ('CONFIRMADA', 'FINALIZADA')
                  AND r.fecha_entrada >= ADD_MONTHS(
                      TO_DATE(cp_anio || '-01-01', 'YYYY-MM-DD'),
                      cp_mes - 1
                  )
                  AND r.fecha_entrada < ADD_MONTHS(
                      TO_DATE(cp_anio || '-01-01', 'YYYY-MM-DD'),
                      cp_mes
                  )
            ),

            pagos AS (
                SELECT
                    id_reserva,
                    SUM(valor) AS pagado
                FROM PAGO
                WHERE confirmado = 'SI'
                GROUP BY id_reserva
            )

            SELECT
                a.id_alojamiento,
                a.nombre AS alojamiento,
                m.nombre AS municipio,
                temp.tipo AS temporada,
                COUNT(*) AS total_reservas,
                SUM(rm.valor_total) AS ingresos,
                SUM(NVL(p.pagado, 0)) AS pagado
            FROM reservas_mes rm
            JOIN ALOJAMIENTO a
              ON a.id_alojamiento = rm.id_alojamiento
            JOIN MUNICIPIO m
              ON m.id_municipio = a.id_municipio
            LEFT JOIN pagos p
              ON p.id_reserva = rm.id_reserva
            JOIN TEMPORADA temp ON temp.mes = cp_mes
            GROUP BY
                a.id_alojamiento,
                a.nombre,
                m.nombre,
                temp.tipo
            ORDER BY ingresos DESC;

        v_reg   c_liquidacion%ROWTYPE;
        v_filas NUMBER := 0;

    BEGIN

        IF p_mes NOT BETWEEN 1 AND 12 THEN
            RAISE_APPLICATION_ERROR(
                -20300,
                'El mes debe estar entre 1 y 12.'
            );
        END IF;

        DELETE FROM LIQUIDACION_MENSUAL
        WHERE anio = p_anio
          AND mes = p_mes;

        DBMS_OUTPUT.PUT_LINE(
            'LIQUIDACIÓN MENSUAL - ' || p_mes || '/' || p_anio
        );

        OPEN c_liquidacion(p_anio, p_mes);

        LOOP
            FETCH c_liquidacion INTO v_reg;
            EXIT WHEN c_liquidacion%NOTFOUND;

            INSERT INTO LIQUIDACION_MENSUAL (
                anio,
                mes,
                id_alojamiento,
                total_reservas,
                ingresos,
                pagado,
                saldo_pendiente,
                temporada
            ) VALUES (
                p_anio,
                p_mes,
                v_reg.id_alojamiento,
                v_reg.total_reservas,
                v_reg.ingresos,
                v_reg.pagado,
                v_reg.ingresos - v_reg.pagado,
                v_reg.temporada
            );

            DBMS_OUTPUT.PUT_LINE(
                RPAD(v_reg.alojamiento, 30) || ' | ' ||
                RPAD(v_reg.municipio, 15) || ' | ' ||
                'Temporada: ' || RPAD(v_reg.temporada, 6) || ' | ' ||
                'Reservas: ' || LPAD(v_reg.total_reservas, 5) || ' | ' ||
                'Ingresos: ' ||
                TO_CHAR(v_reg.ingresos, '999,999,999,990') || ' | ' ||
                'Pagado: ' ||
                TO_CHAR(v_reg.pagado, '999,999,999,990')
            );

            v_filas := v_filas + 1;

        END LOOP;

        CLOSE c_liquidacion;

        COMMIT;

        DBMS_OUTPUT.PUT_LINE(
            v_filas || ' alojamientos liquidados.'
        );

    EXCEPTION
        WHEN OTHERS THEN

            IF c_liquidacion%ISOPEN THEN
                CLOSE c_liquidacion;
            END IF;

            ROLLBACK;
            RAISE;

    END sp_liquidacion_mensual;

    -- PROCEDIMIENTO: sp_liquidacion_temporada
    PROCEDURE sp_liquidacion_temporada(
        p_anio IN NUMBER
    ) IS

        CURSOR c_temporada (
            cp_anio NUMBER
        ) IS

            WITH reservas_anio AS (
                SELECT DISTINCT
                    h.id_alojamiento,
                    r.id_reserva,
                    r.valor_total,
                    t.tipo AS temporada
                FROM RESERVA r
                JOIN RESERVA_HABITACION rh
                  ON rh.id_reserva = r.id_reserva
                JOIN HABITACION h
                  ON h.id_habitacion = rh.id_habitacion
                JOIN TEMPORADA t
                  ON t.mes = EXTRACT(MONTH FROM r.fecha_entrada)
                WHERE r.estado IN ('CONFIRMADA', 'FINALIZADA')
                  AND r.fecha_entrada >= TO_DATE(cp_anio || '-01-01', 'YYYY-MM-DD')
                  AND r.fecha_entrada <  TO_DATE((cp_anio + 1) || '-01-01', 'YYYY-MM-DD')
            ),

            pagos AS (
                SELECT
                    id_reserva,
                    SUM(valor) AS pagado
                FROM PAGO
                WHERE confirmado = 'SI'
                GROUP BY id_reserva
            )

            SELECT
                ra.temporada,
                a.id_alojamiento,
                a.nombre AS alojamiento,
                m.nombre AS municipio,
                COUNT(*) AS total_reservas,
                SUM(ra.valor_total) AS ingresos,
                SUM(NVL(p.pagado, 0)) AS pagado
            FROM reservas_anio ra
            JOIN ALOJAMIENTO a
              ON a.id_alojamiento = ra.id_alojamiento
            JOIN MUNICIPIO m
              ON m.id_municipio = a.id_municipio
            LEFT JOIN pagos p
              ON p.id_reserva = ra.id_reserva
            GROUP BY
                ra.temporada,
                a.id_alojamiento,
                a.nombre,
                m.nombre
            ORDER BY ra.temporada, ingresos DESC;

        v_reg   c_temporada%ROWTYPE;
        v_filas NUMBER := 0;

    BEGIN

        IF p_anio IS NULL OR p_anio NOT BETWEEN 2000 AND 2100 THEN
            RAISE_APPLICATION_ERROR(
                -20301,
                'El año de la liquidación no es válido.'
            );
        END IF;

        DELETE FROM LIQUIDACION_TEMPORADA
        WHERE anio = p_anio;

        DBMS_OUTPUT.PUT_LINE(
            'LIQUIDACIÓN POR TEMPORADA - ' || p_anio
        );

        OPEN c_temporada(p_anio);

        LOOP
            FETCH c_temporada INTO v_reg;
            EXIT WHEN c_temporada%NOTFOUND;

            INSERT INTO LIQUIDACION_TEMPORADA (
                anio,
                temporada,
                id_alojamiento,
                total_reservas,
                ingresos,
                pagado,
                saldo_pendiente
            ) VALUES (
                p_anio,
                v_reg.temporada,
                v_reg.id_alojamiento,
                v_reg.total_reservas,
                v_reg.ingresos,
                v_reg.pagado,
                v_reg.ingresos - v_reg.pagado
            );

            DBMS_OUTPUT.PUT_LINE(
                RPAD(v_reg.temporada, 6) || ' | ' ||
                RPAD(v_reg.alojamiento, 30) || ' | ' ||
                RPAD(v_reg.municipio, 15) || ' | ' ||
                'Reservas: ' || LPAD(v_reg.total_reservas, 5) || ' | ' ||
                'Ingresos: ' ||
                TO_CHAR(v_reg.ingresos, '999,999,999,990') || ' | ' ||
                'Pagado: ' ||
                TO_CHAR(v_reg.pagado, '999,999,999,990')
            );

            v_filas := v_filas + 1;

        END LOOP;

        CLOSE c_temporada;

        COMMIT;

        DBMS_OUTPUT.PUT_LINE(
            v_filas || ' filas liquidadas (temporada y alojamiento).'
        );

    EXCEPTION
        WHEN OTHERS THEN

            IF c_temporada%ISOPEN THEN
                CLOSE c_temporada;
            END IF;

            ROLLBACK;
            RAISE;

    END sp_liquidacion_temporada;

END PKG_TURISMO_UQ;
/
