CREATE OR REPLACE PACKAGE PKG_TURISMO_UQ AS

    FUNCTION fn_valor_estadia(
        p_id_habitacion IN NUMBER,
        p_fecha_in      IN DATE,
        p_fecha_out     IN DATE
    ) RETURN NUMBER;

    PROCEDURE sp_crear_reserva(
        p_id_cliente       IN NUMBER,
        p_id_habitacion    IN NUMBER,
        p_fecha_in         IN DATE,
        p_fecha_out        IN DATE,
        p_numero_personas  IN NUMBER,
        p_id_reserva       OUT NUMBER
    );

    PROCEDURE sp_editar_reserva(
        p_id_reserva       IN NUMBER,
        p_id_cliente       IN NUMBER,
        p_id_habitacion    IN NUMBER,
        p_fecha_in         IN DATE,
        p_fecha_out        IN DATE,
        p_numero_personas  IN NUMBER
    );

    PROCEDURE sp_liquidacion_mensual(
        p_anio IN NUMBER,
        p_mes  IN NUMBER
    );

    PROCEDURE sp_liquidacion_temporada(
        p_anio IN NUMBER
    );

END PKG_TURISMO_UQ;
/
