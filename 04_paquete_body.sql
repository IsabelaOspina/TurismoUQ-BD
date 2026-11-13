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

        -- 9. Calcular nuevamente el valor: estadía + servicios ya contratados
        v_valor := fn_valor_estadia(
            p_id_habitacion,
            p_fecha_in,
            p_fecha_out
        );

        SELECT v_valor + NVL(SUM(subtotal), 0)
          INTO v_valor
          FROM RESERVA_SERVICIO
         WHERE id_reserva = p_id_reserva;

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
                    r.valor_total,
                    r.estado
                FROM RESERVA r
                JOIN RESERVA_HABITACION rh
                  ON rh.id_reserva = r.id_reserva
                JOIN HABITACION h
                  ON h.id_habitacion = rh.id_habitacion
                WHERE r.estado IN ('CONFIRMADA', 'FINALIZADA', 'CANCELADA')
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
                -- Las canceladas no cuentan como reserva; solo aportan el dinero retenido
                COUNT(CASE WHEN rm.estado <> 'CANCELADA' THEN 1 END) AS total_reservas,
                SUM(CASE WHEN rm.estado = 'CANCELADA' THEN NVL(p.pagado, 0)
                         ELSE rm.valor_total END) AS ingresos,
                SUM(NVL(p.pagado, 0)) AS pagado
            FROM reservas_mes rm
            JOIN ALOJAMIENTO a
              ON a.id_alojamiento = rm.id_alojamiento
            JOIN MUNICIPIO m
              ON m.id_municipio = a.id_municipio
            LEFT JOIN pagos p
              ON p.id_reserva = rm.id_reserva
            JOIN TEMPORADA temp ON temp.mes = cp_mes
            WHERE rm.estado <> 'CANCELADA' OR p.pagado > 0
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
                    r.estado,
                    t.tipo AS temporada
                FROM RESERVA r
                JOIN RESERVA_HABITACION rh
                  ON rh.id_reserva = r.id_reserva
                JOIN HABITACION h
                  ON h.id_habitacion = rh.id_habitacion
                JOIN TEMPORADA t
                  ON t.mes = EXTRACT(MONTH FROM r.fecha_entrada)
                WHERE r.estado IN ('CONFIRMADA', 'FINALIZADA', 'CANCELADA')
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
                -- Las canceladas no cuentan como reserva; solo aportan el dinero retenido
                COUNT(CASE WHEN ra.estado <> 'CANCELADA' THEN 1 END) AS total_reservas,
                SUM(CASE WHEN ra.estado = 'CANCELADA' THEN NVL(p.pagado, 0)
                         ELSE ra.valor_total END) AS ingresos,
                SUM(NVL(p.pagado, 0)) AS pagado
            FROM reservas_anio ra
            JOIN ALOJAMIENTO a
              ON a.id_alojamiento = ra.id_alojamiento
            JOIN MUNICIPIO m
              ON m.id_municipio = a.id_municipio
            LEFT JOIN pagos p
              ON p.id_reserva = ra.id_reserva
            WHERE ra.estado <> 'CANCELADA' OR p.pagado > 0
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

    -- PROCEDIMIENTO: sp_reservar_y_pagar
    PROCEDURE sp_reservar_y_pagar(
        p_id_cliente         IN  NUMBER,
        p_id_habitacion      IN  NUMBER,
        p_fecha_in           IN  DATE,
        p_fecha_out          IN  DATE,
        p_numero_personas    IN  NUMBER,
        p_valor_pago         IN  NUMBER,
        p_metodo_pago        IN  VARCHAR2,
        p_id_servicio        IN  NUMBER,
        p_cantidad_servicio  IN  NUMBER,
        p_id_reserva         OUT NUMBER,
        p_id_pago            OUT NUMBER,
        p_resultado_servicio OUT VARCHAR2,
        p_detalle_servicio   OUT VARCHAR2,
        p_valor_total        OUT NUMBER
    ) IS

        v_aloj_habitacion HABITACION.id_alojamiento%TYPE;
        v_aloj_servicio   SERVICIO.id_alojamiento%TYPE;
        v_precio_servicio SERVICIO.precio%TYPE;
        v_subtotal        RESERVA_SERVICIO.subtotal%TYPE;
        v_minimo          NUMBER;

    BEGIN

        SAVEPOINT sp_inicio;

        -- 1. Crear la reserva (valor_total = valor de la estadía)
        sp_crear_reserva(
            p_id_cliente,
            p_id_habitacion,
            p_fecha_in,
            p_fecha_out,
            p_numero_personas,
            p_id_reserva
        );

        SAVEPOINT sp_reserva_creada;

        -- 2. Servicio adicional (opcional): suma su subtotal al valor de la reserva
        IF p_id_servicio IS NULL THEN

            p_resultado_servicio := 'SIN_SERVICIO';

        ELSE

            BEGIN

                IF p_cantidad_servicio IS NULL OR p_cantidad_servicio NOT BETWEEN 1 AND 10 THEN
                    RAISE_APPLICATION_ERROR(
                        -20403,
                        'La cantidad del servicio debe estar entre 1 y 10.'
                    );
                END IF;

                BEGIN
                    SELECT id_alojamiento, precio
                      INTO v_aloj_servicio, v_precio_servicio
                      FROM SERVICIO
                     WHERE id_servicio = p_id_servicio;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        RAISE_APPLICATION_ERROR(
                            -20402,
                            'No existe el servicio con ID ' || p_id_servicio || '.'
                        );
                END;

                SELECT id_alojamiento
                  INTO v_aloj_habitacion
                  FROM HABITACION
                 WHERE id_habitacion = p_id_habitacion;

                IF v_aloj_servicio <> v_aloj_habitacion THEN
                    RAISE_APPLICATION_ERROR(
                        -20402,
                        'El servicio no pertenece al alojamiento de la habitación.'
                    );
                END IF;

                v_subtotal := p_cantidad_servicio * v_precio_servicio;

                INSERT INTO RESERVA_SERVICIO (
                    id_servicio,
                    id_reserva,
                    cantidad,
                    subtotal
                ) VALUES (
                    p_id_servicio,
                    p_id_reserva,
                    p_cantidad_servicio,
                    v_subtotal
                );

                UPDATE RESERVA
                   SET valor_total = valor_total + v_subtotal
                 WHERE id_reserva = p_id_reserva;

                p_resultado_servicio := 'AGREGADO';

            EXCEPTION
                WHEN OTHERS THEN
                    -- Rollback parcial: se deshacen el servicio y la suma al valor;
                    -- la reserva se conserva
                    ROLLBACK TO SAVEPOINT sp_reserva_creada;
                    p_resultado_servicio := 'REVERTIDO';
                    p_detalle_servicio   := SQLERRM;
            END;

        END IF;

        SELECT valor_total
          INTO p_valor_total
          FROM RESERVA
         WHERE id_reserva = p_id_reserva;

        -- 3. Validar y registrar el pago sobre el valor total de la reserva
        IF p_valor_pago IS NULL OR p_valor_pago <= 0 OR p_valor_pago > p_valor_total THEN
            RAISE_APPLICATION_ERROR(
                -20400,
                'El pago debe ser mayor que cero y no puede superar el valor de la reserva ('
                || TO_CHAR(p_valor_total, 'FM999G999G999G990') || ').'
            );
        END IF;

        v_minimo := CEIL(p_valor_total * c_pago_minimo);

        IF p_valor_pago < v_minimo THEN
            RAISE_APPLICATION_ERROR(
                -20404,
                'El pago mínimo es el ' || (c_pago_minimo * 100) || ' % del valor de la reserva ('
                || TO_CHAR(v_minimo, 'FM999G999G999G990') || ').'
            );
        END IF;

        IF p_metodo_pago IS NULL
           OR p_metodo_pago NOT IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA', 'PSE') THEN
            RAISE_APPLICATION_ERROR(
                -20401,
                'El método de pago debe ser EFECTIVO, TARJETA, TRANSFERENCIA o PSE.'
            );
        END IF;

        INSERT INTO PAGO (
            id_pago,
            fecha,
            valor,
            confirmado,
            metodo_pago,
            id_reserva
        ) VALUES (
            seq_pago.NEXTVAL,
            TRUNC(SYSDATE),
            p_valor_pago,
            'SI',
            p_metodo_pago,
            p_id_reserva
        )
        RETURNING id_pago INTO p_id_pago;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            -- Rollback total: no queda ni la reserva ni el servicio
            ROLLBACK TO SAVEPOINT sp_inicio;
            RAISE;

    END sp_reservar_y_pagar;

    -- PROCEDIMIENTO: sp_cancelar_reserva
    -- Cancela la reserva. Los pagos de hace 7 días o menos se devuelven
    -- (quedan con confirmado = 'NO'); los más antiguos no se devuelven.
    PROCEDURE sp_cancelar_reserva(
        p_id_reserva     IN  NUMBER,
        p_valor_devuelto OUT NUMBER,
        p_valor_retenido OUT NUMBER
    ) IS
        v_estado RESERVA.estado%TYPE;
    BEGIN

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
                    'No existe la reserva con ID ' || p_id_reserva || '.'
                );
        END;

        IF v_estado NOT IN ('PENDIENTE', 'CONFIRMADA') THEN
            RAISE_APPLICATION_ERROR(
                -20405,
                'Solo se pueden cancelar reservas pendientes o confirmadas (estado actual: '
                || v_estado || ').'
            );
        END IF;

        SELECT NVL(SUM(CASE WHEN fecha + c_dias_devolucion >= TRUNC(SYSDATE) THEN valor END), 0),
               NVL(SUM(CASE WHEN fecha + c_dias_devolucion <  TRUNC(SYSDATE) THEN valor END), 0)
          INTO p_valor_devuelto, p_valor_retenido
          FROM PAGO
         WHERE id_reserva = p_id_reserva
           AND confirmado = 'SI';

        UPDATE PAGO
           SET confirmado = 'NO'
         WHERE id_reserva = p_id_reserva
           AND confirmado = 'SI'
           AND fecha + c_dias_devolucion >= TRUNC(SYSDATE);

        UPDATE RESERVA
           SET estado = 'CANCELADA'
         WHERE id_reserva = p_id_reserva;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END sp_cancelar_reserva;

    -- Último día en que una cancelación devuelve el dinero: fecha del pago + 7 días
    FUNCTION fn_fecha_limite_devolucion(
        p_id_pago IN NUMBER
    ) RETURN DATE IS
        v_fecha PAGO.fecha%TYPE;
    BEGIN
        SELECT fecha
          INTO v_fecha
          FROM PAGO
         WHERE id_pago = p_id_pago;

        RETURN v_fecha + c_dias_devolucion;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END fn_fecha_limite_devolucion;

END PKG_TURISMO_UQ;
/