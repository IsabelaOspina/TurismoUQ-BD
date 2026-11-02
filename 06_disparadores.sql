CREATE OR REPLACE TRIGGER trg_auditoria_tarifa
FOR INSERT OR UPDATE OR DELETE ON TARIFA
COMPOUND TRIGGER

    TYPE t_cambio IS RECORD (
        tipo_operacion VARCHAR2(10),
        id_habitacion  NUMBER,
        id_temporada   NUMBER,
        valor_anterior NUMBER(12,2),
        valor_nuevo    NUMBER(12,2)
    );
    TYPE t_cambios IS TABLE OF t_cambio INDEX BY PLS_INTEGER;

    v_cambios t_cambios;
    v_usuario VARCHAR2(100);

    BEFORE STATEMENT IS
    BEGIN
        v_cambios.DELETE;
        v_usuario := NVL(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), USER);
    END BEFORE STATEMENT;

    AFTER EACH ROW IS
        i PLS_INTEGER := v_cambios.COUNT + 1;
    BEGIN
        v_cambios(i).tipo_operacion := CASE
                                         WHEN INSERTING THEN 'INSERT'
                                         WHEN UPDATING  THEN 'UPDATE'
                                         ELSE                'DELETE'
                                       END;
        v_cambios(i).id_habitacion  := NVL(:NEW.id_habitacion, :OLD.id_habitacion);
        v_cambios(i).id_temporada   := NVL(:NEW.id_temporada,  :OLD.id_temporada);
        v_cambios(i).valor_anterior := :OLD.precio_noche;
        v_cambios(i).valor_nuevo    := :NEW.precio_noche;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        FORALL i IN 1 .. v_cambios.COUNT
            INSERT INTO AUDITORIA_TARIFA
                (usuario, fecha_cambio, tipo_operacion, id_habitacion,
                 id_temporada, valor_anterior, valor_nuevo)
            VALUES
                (v_usuario, SYSTIMESTAMP, v_cambios(i).tipo_operacion, v_cambios(i).id_habitacion,
                 v_cambios(i).id_temporada, v_cambios(i).valor_anterior, v_cambios(i).valor_nuevo);
        v_cambios.DELETE;
    END AFTER STATEMENT;

END trg_auditoria_tarifa;
/

CREATE OR REPLACE TRIGGER trg_no_solapamiento
BEFORE INSERT ON RESERVA_HABITACION
FOR EACH ROW
DECLARE
    v_fecha_in  RESERVA.fecha_entrada%TYPE;
    v_fecha_out RESERVA.fecha_salida%TYPE;
    v_estado    RESERVA.estado%TYPE;
    v_count     NUMBER;
BEGIN
    SELECT fecha_entrada, fecha_salida, estado
      INTO v_fecha_in, v_fecha_out, v_estado
      FROM RESERVA
     WHERE id_reserva = :NEW.id_reserva;

    IF v_estado NOT IN ('CONFIRMADA', 'PENDIENTE') THEN
        RETURN;
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM RESERVA_HABITACION rh
      JOIN RESERVA r ON r.id_reserva = rh.id_reserva
     WHERE rh.id_habitacion = :NEW.id_habitacion
       AND rh.id_reserva   <> :NEW.id_reserva
       AND r.estado IN ('CONFIRMADA', 'PENDIENTE')
       AND v_fecha_in  < r.fecha_salida
       AND v_fecha_out > r.fecha_entrada
       AND ROWNUM = 1;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20200,
            'La habitación ' || :NEW.id_habitacion ||
            ' ya está reservada entre ' ||
            TO_CHAR(v_fecha_in, 'YYYY-MM-DD') || ' y ' ||
            TO_CHAR(v_fecha_out, 'YYYY-MM-DD'));
    END IF;
END;
/

SELECT trigger_name, trigger_type, triggering_event, table_name, status
  FROM user_triggers
 ORDER BY trigger_name;
