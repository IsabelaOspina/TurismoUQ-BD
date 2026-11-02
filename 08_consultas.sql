-- CONSULTA 1 · Ocupación por municipio y mes, con PIVOT
WITH reserva_aloj AS (
    SELECT DISTINCT rh.id_reserva, h.id_alojamiento
      FROM RESERVA_HABITACION rh
      JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion
)
SELECT *
  FROM (SELECT m.nombre                       AS municipio,
               TO_CHAR(r.fecha_entrada, 'MM') AS mes,
               r.id_reserva
          FROM RESERVA r
          JOIN reserva_aloj ra ON r.id_reserva = ra.id_reserva
          JOIN ALOJAMIENTO a   ON ra.id_alojamiento = a.id_alojamiento
          JOIN MUNICIPIO m     ON a.id_municipio = m.id_municipio
         WHERE r.estado IN ('CONFIRMADA', 'FINALIZADA'))
 PIVOT (COUNT(id_reserva)
        FOR mes IN ('01' AS ene, '02' AS feb, '03' AS mar, '04' AS abr,
                    '05' AS may, '06' AS jun, '07' AS jul, '08' AS ago,
                    '09' AS sep, '10' AS oct, '11' AS nov, '12' AS dic))
 ORDER BY municipio;

-- CONSULTA 2 · Ingresos por municipio, tipo de alojamiento y temporada
WITH reserva_aloj AS (
    SELECT DISTINCT rh.id_reserva, h.id_alojamiento
      FROM RESERVA_HABITACION rh
      JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion
)
SELECT CASE GROUPING(m.nombre)    WHEN 1 THEN 'TOTAL GENERAL'  ELSE m.nombre END    AS municipio,
       CASE GROUPING(t.nombre)    WHEN 1 THEN 'SUBTOTAL'       ELSE t.nombre END    AS tipo_alojamiento,
       CASE GROUPING(temp.tipo)   WHEN 1 THEN 'SUBTOTAL'       ELSE temp.tipo END   AS temporada,
       GROUPING(m.nombre) + GROUPING(t.nombre) + GROUPING(temp.tipo)               AS nivel,
       SUM(r.valor_total)                                                           AS ingresos
  FROM RESERVA r
  JOIN reserva_aloj ra     ON r.id_reserva = ra.id_reserva
  JOIN ALOJAMIENTO a       ON ra.id_alojamiento = a.id_alojamiento
  JOIN MUNICIPIO m         ON a.id_municipio = m.id_municipio
  JOIN TIPO_ALOJAMIENTO t  ON a.id_tipo_alojamiento = t.id_tipo_alojamiento
  JOIN TEMPORADA temp      ON temp.mes = EXTRACT(MONTH FROM r.fecha_entrada)
 WHERE r.estado IN ('CONFIRMADA', 'FINALIZADA')
 GROUP BY ROLLUP (m.nombre, t.nombre, temp.tipo)
 ORDER BY GROUPING(m.nombre), m.nombre, GROUPING(t.nombre), t.nombre, GROUPING(temp.tipo), temp.tipo;

-- CONSULTA 3 · Los 3 alojamientos de mayor ingreso en cada municipio
WITH reserva_aloj AS (
    SELECT DISTINCT rh.id_reserva, h.id_alojamiento
      FROM RESERVA_HABITACION rh
      JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion
)
SELECT municipio, alojamiento, ingresos, ranking
  FROM (SELECT m.nombre           AS municipio,
               a.nombre           AS alojamiento,
               SUM(r.valor_total) AS ingresos,
               RANK() OVER (PARTITION BY m.nombre ORDER BY SUM(r.valor_total) DESC) AS ranking
          FROM RESERVA r
          JOIN reserva_aloj ra ON r.id_reserva = ra.id_reserva
          JOIN ALOJAMIENTO a   ON ra.id_alojamiento = a.id_alojamiento
          JOIN MUNICIPIO m     ON a.id_municipio = m.id_municipio
         WHERE r.estado IN ('CONFIRMADA', 'FINALIZADA')
         GROUP BY m.nombre, a.nombre)
 WHERE ranking <= 3
 ORDER BY municipio, ranking;

-- CONSULTA 4 · Variación de ingresos mes contra mes (LAG)
SELECT mes,
       ingresos,
       LAG(ingresos) OVER (ORDER BY mes)                                  AS ingresos_mes_anterior,
       ingresos - LAG(ingresos) OVER (ORDER BY mes)                       AS variacion,
       ROUND((ingresos - LAG(ingresos) OVER (ORDER BY mes))
             / NULLIF(LAG(ingresos) OVER (ORDER BY mes), 0) * 100, 2)     AS variacion_pct
  FROM (SELECT TO_CHAR(fecha_entrada, 'YYYY-MM') AS mes,
               SUM(valor_total)                  AS ingresos
          FROM RESERVA
         WHERE estado IN ('CONFIRMADA', 'FINALIZADA')
         GROUP BY TO_CHAR(fecha_entrada, 'YYYY-MM'))
 ORDER BY mes;

-- CONSULTA 5 · Reservas en un rango de fechas con variables de enlace
VARIABLE fecha_inicio VARCHAR2(10)
VARIABLE fecha_fin    VARCHAR2(10)
EXEC :fecha_inicio := '2025-06-01';
EXEC :fecha_fin    := '2025-06-30';

SELECT r.id_reserva,
       r.fecha_entrada,
       r.fecha_salida,
       r.estado,
       r.valor_total,
       c.nombre AS cliente,
       m.nombre AS municipio
  FROM RESERVA r
  JOIN CLIENTE c ON r.id_cliente = c.id_cliente
  JOIN (SELECT rh.id_reserva, MIN(h.id_alojamiento) AS id_alojamiento
          FROM RESERVA_HABITACION rh
          JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion
         GROUP BY rh.id_reserva) ra ON ra.id_reserva = r.id_reserva
  JOIN ALOJAMIENTO a ON ra.id_alojamiento = a.id_alojamiento
  JOIN MUNICIPIO m   ON a.id_municipio = m.id_municipio
 WHERE r.fecha_entrada BETWEEN TO_DATE(:fecha_inicio, 'YYYY-MM-DD')
                           AND TO_DATE(:fecha_fin,    'YYYY-MM-DD')
 ORDER BY r.fecha_entrada, r.id_reserva;

-- CONSULTA 6 · Vista materializada de ocupación mensual
SELECT mes, municipio, total_reservas, ingresos_totales
  FROM mv_ocupacion_mensual
 ORDER BY mes, municipio;

EXEC DBMS_MVIEW.REFRESH('MV_OCUPACION_MENSUAL', 'C');

-- CONSULTA 7 · UNPIVOT
WITH reserva_aloj AS (
    SELECT DISTINCT rh.id_reserva, h.id_alojamiento
      FROM RESERVA_HABITACION rh
      JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion
),
por_trimestre AS (
    SELECT *
      FROM (SELECT m.nombre                       AS municipio,
                   'Q' || TO_CHAR(r.fecha_entrada, 'Q') AS trimestre,
                   r.id_reserva
              FROM RESERVA r
              JOIN reserva_aloj ra ON r.id_reserva = ra.id_reserva
              JOIN ALOJAMIENTO a   ON ra.id_alojamiento = a.id_alojamiento
              JOIN MUNICIPIO m     ON a.id_municipio = m.id_municipio
             WHERE r.estado IN ('CONFIRMADA', 'FINALIZADA'))
     PIVOT (COUNT(id_reserva) FOR trimestre IN ('Q1' AS q1, 'Q2' AS q2, 'Q3' AS q3, 'Q4' AS q4))
)
SELECT municipio, trimestre, total_reservas
  FROM por_trimestre
UNPIVOT (total_reservas FOR trimestre IN (q1 AS 'Q1', q2 AS 'Q2', q3 AS 'Q3', q4 AS 'Q4'))
 ORDER BY municipio, trimestre;

-- CONSULTA 8 · Consulta libre
WITH reserva_aloj AS (
    SELECT DISTINCT rh.id_reserva, h.id_alojamiento
      FROM RESERVA_HABITACION rh
      JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion
)
SELECT a.nombre                       AS alojamiento,
       m.nombre                       AS municipio,
       ROUND(AVG(re.calificacion), 2) AS calificacion_promedio,
       COUNT(re.id_resena)            AS total_resenas
  FROM RESENA re
  JOIN reserva_aloj ra ON re.id_reserva = ra.id_reserva
  JOIN ALOJAMIENTO a   ON ra.id_alojamiento = a.id_alojamiento
  JOIN MUNICIPIO m     ON a.id_municipio = m.id_municipio
 GROUP BY a.nombre, m.nombre
HAVING COUNT(re.id_resena) >= 3
 ORDER BY calificacion_promedio DESC, total_resenas DESC
 FETCH FIRST 10 ROWS ONLY;
