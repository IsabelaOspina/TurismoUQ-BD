CREATE MATERIALIZED VIEW mv_ocupacion_mensual
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT TO_CHAR(r.fecha_entrada, 'YYYY-MM') AS mes,
       m.nombre                            AS municipio,
       COUNT(*)                            AS total_reservas,
       SUM(r.valor_total)                  AS ingresos_totales
  FROM RESERVA r
  JOIN (SELECT DISTINCT rh.id_reserva, h.id_alojamiento
          FROM RESERVA_HABITACION rh
          JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion) ra
    ON r.id_reserva = ra.id_reserva
  JOIN ALOJAMIENTO a ON ra.id_alojamiento = a.id_alojamiento
  JOIN MUNICIPIO m   ON a.id_municipio = m.id_municipio
 WHERE r.estado IN ('CONFIRMADA', 'FINALIZADA')
 GROUP BY TO_CHAR(r.fecha_entrada, 'YYYY-MM'), m.nombre;

SELECT mview_name, refresh_mode, refresh_method, last_refresh_date, staleness
  FROM user_mviews;
