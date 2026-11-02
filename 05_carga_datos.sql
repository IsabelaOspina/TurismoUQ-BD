SET SERVEROUTPUT ON

EXEC DBMS_RANDOM.SEED(2026);

-- 1. MUNICIPIOS (12)
INSERT INTO MUNICIPIO VALUES (seq_municipio.NEXTVAL, 'Armenia',    'Capital del Quindío');
INSERT INTO MUNICIPIO VALUES (seq_municipio.NEXTVAL, 'Buenavista', 'Mirador del Quindío');
INSERT INTO MUNICIPIO VALUES (seq_municipio.NEXTVAL, 'Calarcá',    'Ciudad de los balcones');
INSERT INTO MUNICIPIO VALUES (seq_municipio.NEXTVAL, 'Circasia',   'Tierra de artesanos');
INSERT INTO MUNICIPIO VALUES (seq_municipio.NEXTVAL, 'Córdoba',    'Municipio tranquilo');
INSERT INTO MUNICIPIO VALUES (seq_municipio.NEXTVAL, 'Filandia',   'Pueblo patrimonio');
INSERT INTO MUNICIPIO VALUES (seq_municipio.NEXTVAL, 'Génova',     'Tierra cafetera');
INSERT INTO MUNICIPIO VALUES (seq_municipio.NEXTVAL, 'La Tebaida', 'Cerca del aeropuerto');
INSERT INTO MUNICIPIO VALUES (seq_municipio.NEXTVAL, 'Montenegro', 'Corazón cafetero');
INSERT INTO MUNICIPIO VALUES (seq_municipio.NEXTVAL, 'Pijao',      'Pueblo sin prisa');
INSERT INTO MUNICIPIO VALUES (seq_municipio.NEXTVAL, 'Quimbaya',   'Tierra de la guadua');
INSERT INTO MUNICIPIO VALUES (seq_municipio.NEXTVAL, 'Salento',    'Puerta del Valle de Cocora');
COMMIT;

-- 2. TIPOS DE ALOJAMIENTO (4)
INSERT INTO TIPO_ALOJAMIENTO VALUES (seq_tipo_aloj.NEXTVAL, 'Finca Cafetera', 'Finca tradicional cafetera');
INSERT INTO TIPO_ALOJAMIENTO VALUES (seq_tipo_aloj.NEXTVAL, 'Hotel',          'Hotel urbano o rural');
INSERT INTO TIPO_ALOJAMIENTO VALUES (seq_tipo_aloj.NEXTVAL, 'Glamping',       'Camping de lujo');
INSERT INTO TIPO_ALOJAMIENTO VALUES (seq_tipo_aloj.NEXTVAL, 'Hostal',         'Alojamiento económico');
COMMIT;

-- 3. TEMPORADAS (una por mes)
INSERT INTO TEMPORADA VALUES (seq_temporada.NEXTVAL, 'Enero',      1,  'ALTA');
INSERT INTO TEMPORADA VALUES (seq_temporada.NEXTVAL, 'Febrero',    2,  'BAJA');
INSERT INTO TEMPORADA VALUES (seq_temporada.NEXTVAL, 'Marzo',      3,  'BAJA');
INSERT INTO TEMPORADA VALUES (seq_temporada.NEXTVAL, 'Abril',      4,  'ALTA');
INSERT INTO TEMPORADA VALUES (seq_temporada.NEXTVAL, 'Mayo',       5,  'MEDIA');
INSERT INTO TEMPORADA VALUES (seq_temporada.NEXTVAL, 'Junio',      6,  'ALTA');
INSERT INTO TEMPORADA VALUES (seq_temporada.NEXTVAL, 'Julio',      7,  'ALTA');
INSERT INTO TEMPORADA VALUES (seq_temporada.NEXTVAL, 'Agosto',     8,  'BAJA');
INSERT INTO TEMPORADA VALUES (seq_temporada.NEXTVAL, 'Septiembre', 9,  'BAJA');
INSERT INTO TEMPORADA VALUES (seq_temporada.NEXTVAL, 'Octubre',    10, 'MEDIA');
INSERT INTO TEMPORADA VALUES (seq_temporada.NEXTVAL, 'Noviembre',  11, 'BAJA');
INSERT INTO TEMPORADA VALUES (seq_temporada.NEXTVAL, 'Diciembre',  12, 'ALTA');
COMMIT;

-- 4. PROPIETARIOS (15)
BEGIN
    FOR i IN 1..15 LOOP
        INSERT INTO PROPIETARIO VALUES (
            seq_propietario.NEXTVAL,
            'Propietario ' || i,
            'CED' || LPAD(i, 8, '0'),
            'propietario' || i || '@turismouq.com'
        );
    END LOOP;
    COMMIT;
END;
/

-- 5. CLIENTES (3.000)
BEGIN
    FOR i IN 1..3000 LOOP
        INSERT INTO CLIENTE VALUES (
            seq_cliente.NEXTVAL,
            'Cliente ' || i,
            'CLI' || LPAD(i, 10, '0'),
            'cliente' || i || '@turismouq.com'
        );
    END LOOP;
    COMMIT;
END;
/

-- 6. ALOJAMIENTOS (60): 5 por municipio, tipo y propietario rotando
BEGIN
    FOR i IN 1..60 LOOP
        INSERT INTO ALOJAMIENTO (
            id_alojamiento, nombre, descripcion, direccion, capacidad,
            telefono, correo, id_propietario, id_tipo_alojamiento, id_municipio
        ) VALUES (
            seq_alojamiento.NEXTVAL,
            'Alojamiento ' || i,
            'Descripción del alojamiento ' || i,
            'Calle ' || i || ' # ' || MOD(i, 50) || '-01',
            1,
            '300' || LPAD(i, 7, '0'),
            'alojamiento' || i || '@turismouq.com',
            MOD(i, 15) + 1,
            MOD(i, 4) + 1,
            MOD(i, 12) + 1
        );
    END LOOP;
    COMMIT;
END;
/

-- 7. HABITACIONES (400): la habitación i pertenece al alojamiento MOD(i,60)+1
BEGIN
    FOR i IN 1..400 LOOP
        INSERT INTO HABITACION VALUES (
            seq_habitacion.NEXTVAL,
            'H' || LPAD(i, 4, '0'),
            CASE MOD(i, 3) WHEN 0 THEN 1 WHEN 1 THEN 2 ELSE ROUND(DBMS_RANDOM.VALUE(4, 6)) END,
            ROUND(DBMS_RANDOM.VALUE(80000, 600000), -3),
            CASE MOD(i, 3) WHEN 0 THEN 'SENCILLA' WHEN 1 THEN 'DOBLE' ELSE 'FAMILIAR' END,
            MOD(i, 60) + 1
        );
    END LOOP;
    COMMIT;
END;
/

UPDATE ALOJAMIENTO a
   SET capacidad = (SELECT SUM(h.capacidad) FROM HABITACION h WHERE h.id_alojamiento = a.id_alojamiento);
COMMIT;

-- 8. TARIFAS (4.800 = 400 habitaciones x 12 meses)
INSERT INTO TARIFA (id_habitacion, id_temporada, precio_noche)
SELECT h.id_habitacion,
       t.id_temporada,
       ROUND(h.precio_base * CASE t.tipo WHEN 'ALTA' THEN 1.3 WHEN 'MEDIA' THEN 1 ELSE 0.85 END, -3)
  FROM HABITACION h
 CROSS JOIN TEMPORADA t;
COMMIT;

-- 9. SERVICIOS (180 = 3 por alojamiento)
BEGIN
    FOR a IN 1..60 LOOP
        FOR s IN 1..3 LOOP
            INSERT INTO SERVICIO VALUES (
                seq_servicio.NEXTVAL,
                CASE s WHEN 1 THEN 'Desayuno' WHEN 2 THEN 'Lavandería' ELSE 'Tour cafetero' END,
                'Servicio adicional del alojamiento',
                ROUND(DBMS_RANDOM.VALUE(10000, 150000), -3),
                a
            );
        END LOOP;
    END LOOP;
    COMMIT;
END;
/

-- 10. USUARIOS DEL SISTEMA (5)
INSERT INTO USUARIO_SISTEMA VALUES (seq_usuario.NEXTVAL, 'Admin General', 'admin@turismouq.com', 'ACTIVO',   'ADM001', 'hash_admin');
INSERT INTO USUARIO_SISTEMA VALUES (seq_usuario.NEXTVAL, 'Operador 1',    'op1@turismouq.com',   'ACTIVO',   'OP0001', 'hash_op1');
INSERT INTO USUARIO_SISTEMA VALUES (seq_usuario.NEXTVAL, 'Operador 2',    'op2@turismouq.com',   'ACTIVO',   'OP0002', 'hash_op2');
INSERT INTO USUARIO_SISTEMA VALUES (seq_usuario.NEXTVAL, 'Consulta 1',    'cons1@turismouq.com', 'ACTIVO',   'CON001', 'hash_cons1');
INSERT INTO USUARIO_SISTEMA VALUES (seq_usuario.NEXTVAL, 'Consulta 2',    'cons2@turismouq.com', 'INACTIVO', 'CON002', 'hash_cons2');
COMMIT;

-- 11. RESERVAS (25.000) y RESERVA_HABITACION, SIN SOLAPAMIENTOS
DECLARE
    c_inicio   CONSTANT DATE        := DATE '2024-01-01';
    c_dias     CONSTANT PLS_INTEGER := DATE '2027-01-01' - DATE '2024-01-01';
    c_total    CONSTANT PLS_INTEGER := 25000;
    c_lineas   CONSTANT PLS_INTEGER := 360;
    v_hoy      DATE := TRUNC(SYSDATE);
    v_linea    PLS_INTEGER := 0;
    v_cuantas  PLS_INTEGER;
    v_franja   PLS_INTEGER;
    v_hab1     NUMBER;
    v_hab2     NUMBER;
    v_dos      BOOLEAN;
    v_entrada  DATE;
    v_salida   DATE;
    v_estado   VARCHAR2(20);
    v_cap      NUMBER;
    v_id       NUMBER;
    v_azar     NUMBER;
    v_creadas  PLS_INTEGER := 0;
BEGIN
    FOR h IN 1..400 LOOP
        CONTINUE WHEN h BETWEEN 61 AND 100;

        v_linea   := v_linea + 1;
        v_cuantas := CASE WHEN v_linea <= c_total - 69 * c_lineas THEN 70 ELSE 69 END;
        v_franja  := TRUNC(c_dias / v_cuantas);

        FOR k IN 0 .. v_cuantas - 1 LOOP
            v_entrada := c_inicio + k * v_franja + TRUNC(DBMS_RANDOM.VALUE(0, v_franja - 7));
            v_salida  := v_entrada + TRUNC(DBMS_RANDOM.VALUE(1, 8));

            IF h <= 40 THEN
                v_dos := DBMS_RANDOM.VALUE < 0.35;
                IF v_dos THEN
                    v_hab1 := h;
                    v_hab2 := h + 60;
                ELSE
                    v_hab1 := CASE WHEN DBMS_RANDOM.VALUE < 0.5 THEN h ELSE h + 60 END;
                    v_hab2 := NULL;
                END IF;
            ELSE
                v_hab1 := h;
                v_hab2 := NULL;
            END IF;

            v_azar := DBMS_RANDOM.VALUE;
            IF v_salida <= v_hoy THEN
                v_estado := CASE WHEN v_azar < 0.10 THEN 'CANCELADA' ELSE 'FINALIZADA' END;
            ELSIF v_entrada <= v_hoy THEN
                v_estado := 'CONFIRMADA';
            ELSE
                v_estado := CASE WHEN v_azar < 0.15 THEN 'CANCELADA'
                                 WHEN v_azar < 0.45 THEN 'PENDIENTE'
                                 ELSE 'CONFIRMADA' END;
            END IF;

            SELECT SUM(capacidad) INTO v_cap
              FROM HABITACION
             WHERE id_habitacion IN (v_hab1, v_hab2);

            INSERT INTO RESERVA (id_reserva, fecha_reserva, fecha_entrada, fecha_salida,
                                 numero_personas, estado, valor_total, id_cliente)
            VALUES (seq_reserva.NEXTVAL,
                    LEAST(v_entrada - TRUNC(DBMS_RANDOM.VALUE(1, 61)), v_hoy),
                    v_entrada,
                    v_salida,
                    TRUNC(DBMS_RANDOM.VALUE(1, v_cap + 1)),
                    v_estado,
                    0,
                    TRUNC(DBMS_RANDOM.VALUE(1, 3001)))
            RETURNING id_reserva INTO v_id;

            INSERT INTO RESERVA_HABITACION (id_reserva, id_habitacion) VALUES (v_id, v_hab1);
            IF v_hab2 IS NOT NULL THEN
                INSERT INTO RESERVA_HABITACION (id_reserva, id_habitacion) VALUES (v_id, v_hab2);
            END IF;

            v_creadas := v_creadas + 1;
            IF MOD(v_creadas, 2000) = 0 THEN
                COMMIT;
            END IF;
        END LOOP;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE(v_creadas || ' reservas creadas.');
END;
/

-- 12. RESERVA_SERVICIO (40.000): servicios del alojamiento de la reserva
DECLARE
    v_cant NUMBER;
BEGIN
    FOR r IN (SELECT rh.id_reserva, MIN(h.id_alojamiento) AS id_alojamiento
                FROM RESERVA_HABITACION rh
                JOIN HABITACION h ON h.id_habitacion = rh.id_habitacion
               GROUP BY rh.id_reserva) LOOP

        v_cant := TRUNC(DBMS_RANDOM.VALUE(1, 5));
        INSERT INTO RESERVA_SERVICIO (id_servicio, id_reserva, cantidad, subtotal)
        SELECT id_servicio, r.id_reserva, v_cant, v_cant * precio
          FROM SERVICIO
         WHERE id_alojamiento = r.id_alojamiento
           AND nombre = CASE MOD(r.id_reserva, 3) WHEN 0 THEN 'Desayuno'
                                                  WHEN 1 THEN 'Lavandería'
                                                  ELSE 'Tour cafetero' END;

        IF MOD(r.id_reserva, 5) < 3 THEN
            v_cant := TRUNC(DBMS_RANDOM.VALUE(1, 5));
            INSERT INTO RESERVA_SERVICIO (id_servicio, id_reserva, cantidad, subtotal)
            SELECT id_servicio, r.id_reserva, v_cant, v_cant * precio
              FROM SERVICIO
             WHERE id_alojamiento = r.id_alojamiento
               AND nombre = CASE MOD(r.id_reserva + 1, 3) WHEN 0 THEN 'Desayuno'
                                                          WHEN 1 THEN 'Lavandería'
                                                          ELSE 'Tour cafetero' END;
        END IF;
    END LOOP;
    COMMIT;
END;
/

-- 13. VALOR DE CADA RESERVA = estadía (fn_valor_estadia de sus habitaciones) + servicios
UPDATE RESERVA r
   SET valor_total = (SELECT SUM(PKG_TURISMO_UQ.fn_valor_estadia(rh.id_habitacion,
                                                                 r.fecha_entrada,
                                                                 r.fecha_salida))
                        FROM RESERVA_HABITACION rh
                       WHERE rh.id_reserva = r.id_reserva)
                     + (SELECT NVL(SUM(s.subtotal), 0)
                          FROM RESERVA_SERVICIO s
                         WHERE s.id_reserva = r.id_reserva);
COMMIT;

-- 14. PAGOS: uno por reserva no cancelada
INSERT INTO PAGO (id_pago, fecha, valor, confirmado, metodo_pago, id_reserva)
SELECT seq_pago.NEXTVAL,
       fecha_reserva,
       ROUND(valor_total * CASE estado WHEN 'FINALIZADA' THEN 1 WHEN 'CONFIRMADA' THEN 0.5 ELSE 0.3 END, 2),
       CASE estado WHEN 'PENDIENTE' THEN 'NO' ELSE 'SI' END,
       CASE MOD(id_reserva, 4) WHEN 0 THEN 'EFECTIVO' WHEN 1 THEN 'TARJETA'
                               WHEN 2 THEN 'TRANSFERENCIA' ELSE 'PSE' END,
       id_reserva
  FROM RESERVA
 WHERE estado <> 'CANCELADA';
COMMIT;

-- 15. RESEÑAS (5.000) sobre reservas finalizadas
INSERT INTO RESENA (id_resena, calificacion, comentario, fecha, id_reserva)
SELECT seq_resena.NEXTVAL,
       ROUND(DBMS_RANDOM.VALUE(1, 5)),
       'Comentario de la reseña',
       LEAST(fecha_salida + ROUND(DBMS_RANDOM.VALUE(1, 10)), TRUNC(SYSDATE)),
       id_reserva
  FROM RESERVA
 WHERE estado = 'FINALIZADA'
   AND ROWNUM <= 5000;
COMMIT;

-- 16. ESTADÍSTICAS PARA EL OPTIMIZADOR
BEGIN
    DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER, cascade => TRUE);
END;
/

SELECT 'MUNICIPIO' AS tabla, COUNT(*) AS filas FROM MUNICIPIO
UNION ALL SELECT 'TIPO_ALOJAMIENTO',   COUNT(*) FROM TIPO_ALOJAMIENTO
UNION ALL SELECT 'TEMPORADA',          COUNT(*) FROM TEMPORADA
UNION ALL SELECT 'PROPIETARIO',        COUNT(*) FROM PROPIETARIO
UNION ALL SELECT 'CLIENTE',            COUNT(*) FROM CLIENTE
UNION ALL SELECT 'ALOJAMIENTO',        COUNT(*) FROM ALOJAMIENTO
UNION ALL SELECT 'HABITACION',         COUNT(*) FROM HABITACION
UNION ALL SELECT 'TARIFA',             COUNT(*) FROM TARIFA
UNION ALL SELECT 'SERVICIO',           COUNT(*) FROM SERVICIO
UNION ALL SELECT 'USUARIO_SISTEMA',    COUNT(*) FROM USUARIO_SISTEMA
UNION ALL SELECT 'RESERVA',            COUNT(*) FROM RESERVA
UNION ALL SELECT 'RESERVA_HABITACION', COUNT(*) FROM RESERVA_HABITACION
UNION ALL SELECT 'PAGO',               COUNT(*) FROM PAGO
UNION ALL SELECT 'RESERVA_SERVICIO',   COUNT(*) FROM RESERVA_SERVICIO
UNION ALL SELECT 'RESENA',             COUNT(*) FROM RESENA;

SELECT EXTRACT(YEAR FROM fecha_entrada) AS anio, COUNT(*) AS reservas
  FROM RESERVA
 GROUP BY EXTRACT(YEAR FROM fecha_entrada)
 ORDER BY anio;

SELECT partition_name, tablespace_name, num_rows
  FROM user_tab_partitions
 WHERE table_name = 'RESERVA'
 ORDER BY partition_position;

SELECT COUNT(*) AS solapamientos
  FROM RESERVA_HABITACION rh1
  JOIN RESERVA r1 ON r1.id_reserva = rh1.id_reserva
  JOIN RESERVA_HABITACION rh2 ON rh2.id_habitacion = rh1.id_habitacion
                             AND rh2.id_reserva > rh1.id_reserva
  JOIN RESERVA r2 ON r2.id_reserva = rh2.id_reserva
 WHERE r1.fecha_entrada < r2.fecha_salida
   AND r2.fecha_entrada < r1.fecha_salida;