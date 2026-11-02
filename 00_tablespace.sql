-- Ejecutar como SYSTEM en XEPDB1
CREATE TABLESPACE TS_HISTORICO
    DATAFILE 'historico_reservas.dbf'
    SIZE 100M
    AUTOEXTEND ON NEXT 50M
    MAXSIZE 2G;

SELECT tablespace_name, status, contents
  FROM dba_tablespaces
 WHERE tablespace_name = 'TS_HISTORICO';
