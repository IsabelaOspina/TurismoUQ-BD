-- MUNICIPIO
CREATE TABLE MUNICIPIO (
    id_municipio NUMBER        NOT NULL,
    nombre       VARCHAR2(100) NOT NULL,
    descripcion  VARCHAR2(250),
    CONSTRAINT pk_municipio        PRIMARY KEY (id_municipio),
    CONSTRAINT uq_municipio_nombre UNIQUE (nombre)
);

-- TIPO_ALOJAMIENTO
CREATE TABLE TIPO_ALOJAMIENTO (
    id_tipo_alojamiento NUMBER       NOT NULL,
    nombre              VARCHAR2(50) NOT NULL,
    descripcion         VARCHAR2(250),
    CONSTRAINT pk_tipo_alojamiento        PRIMARY KEY (id_tipo_alojamiento),
    CONSTRAINT uq_tipo_alojamiento_nombre UNIQUE (nombre)
);

-- PROPIETARIO
CREATE TABLE PROPIETARIO (
    id_propietario NUMBER        NOT NULL,
    nombre         VARCHAR2(100) NOT NULL,
    cedula         VARCHAR2(30)  NOT NULL,
    correo         VARCHAR2(150) NOT NULL,
    CONSTRAINT pk_propietario        PRIMARY KEY (id_propietario),
    CONSTRAINT uq_propietario_cedula UNIQUE (cedula),
    CONSTRAINT uq_propietario_correo UNIQUE (correo),
    CONSTRAINT ck_propietario_correo
        CHECK (REGEXP_LIKE(correo, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'))
);

-- CLIENTE
CREATE TABLE CLIENTE (
    id_cliente NUMBER        NOT NULL,
    nombre     VARCHAR2(100) NOT NULL,
    cedula     VARCHAR2(30)  NOT NULL,
    correo     VARCHAR2(150) NOT NULL,
    CONSTRAINT pk_cliente        PRIMARY KEY (id_cliente),
    CONSTRAINT uq_cliente_cedula UNIQUE (cedula),
    CONSTRAINT uq_cliente_correo UNIQUE (correo),
    CONSTRAINT ck_cliente_correo
        CHECK (REGEXP_LIKE(correo, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'))
);

-- USUARIO_SISTEMA
CREATE TABLE USUARIO_SISTEMA (
    id_usuario NUMBER        NOT NULL,
    nombre     VARCHAR2(100) NOT NULL,
    correo     VARCHAR2(150) NOT NULL,
    estado     VARCHAR2(20)  NOT NULL,
    cedula     VARCHAR2(30)  NOT NULL,
    contrasena VARCHAR2(255) NOT NULL,
    CONSTRAINT pk_usuario_sistema PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_correo  UNIQUE (correo),
    CONSTRAINT uq_usuario_cedula  UNIQUE (cedula),
    CONSTRAINT ck_usuario_estado  CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    CONSTRAINT ck_usuario_correo
        CHECK (REGEXP_LIKE(correo, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'))
);

-- ALOJAMIENTO
CREATE TABLE ALOJAMIENTO (
    id_alojamiento      NUMBER        NOT NULL,
    nombre              VARCHAR2(150) NOT NULL,
    descripcion         VARCHAR2(500),
    direccion           VARCHAR2(200) NOT NULL,
    capacidad           NUMBER        NOT NULL,
    telefono            VARCHAR2(20),
    correo              VARCHAR2(150),
    id_propietario      NUMBER        NOT NULL,
    id_tipo_alojamiento NUMBER        NOT NULL,
    id_municipio        NUMBER        NOT NULL,
    CONSTRAINT pk_alojamiento PRIMARY KEY (id_alojamiento),
    CONSTRAINT fk_alojamiento_propietario FOREIGN KEY (id_propietario)
        REFERENCES PROPIETARIO (id_propietario),
    CONSTRAINT fk_alojamiento_tipo FOREIGN KEY (id_tipo_alojamiento)
        REFERENCES TIPO_ALOJAMIENTO (id_tipo_alojamiento),
    CONSTRAINT fk_alojamiento_municipio FOREIGN KEY (id_municipio)
        REFERENCES MUNICIPIO (id_municipio),
    CONSTRAINT uq_alojamiento_nombre_municipio UNIQUE (id_municipio, nombre),
    CONSTRAINT ck_alojamiento_capacidad CHECK (capacidad > 0),
    CONSTRAINT ck_alojamiento_correo
        CHECK (correo IS NULL
               OR REGEXP_LIKE(correo, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'))
);

-- HABITACION
CREATE TABLE HABITACION (
    id_habitacion  NUMBER       NOT NULL,
    numero         VARCHAR2(20) NOT NULL,
    capacidad      NUMBER       NOT NULL,
    precio_base    NUMBER(12,2) NOT NULL,
    tipo           VARCHAR2(20) NOT NULL,
    id_alojamiento NUMBER       NOT NULL,
    CONSTRAINT pk_habitacion PRIMARY KEY (id_habitacion),
    CONSTRAINT fk_habitacion_alojamiento FOREIGN KEY (id_alojamiento)
        REFERENCES ALOJAMIENTO (id_alojamiento),
    CONSTRAINT uq_habitacion_numero    UNIQUE (id_alojamiento, numero),
    CONSTRAINT ck_habitacion_capacidad CHECK (capacidad > 0),
    CONSTRAINT ck_habitacion_precio    CHECK (precio_base > 0),
    CONSTRAINT ck_habitacion_tipo      CHECK (tipo IN ('SENCILLA', 'DOBLE', 'FAMILIAR'))
);

-- TEMPORADA
CREATE TABLE TEMPORADA (
    id_temporada NUMBER       NOT NULL,
    nombre       VARCHAR2(50) NOT NULL,
    mes          NUMBER(2)    NOT NULL,
    tipo         VARCHAR2(20) NOT NULL,
    CONSTRAINT pk_temporada      PRIMARY KEY (id_temporada),
    CONSTRAINT uq_temporada_mes  UNIQUE (mes),
    CONSTRAINT ck_temporada_mes  CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT ck_temporada_tipo CHECK (tipo IN ('ALTA', 'MEDIA', 'BAJA'))
);

-- TARIFA
CREATE TABLE TARIFA (
    id_habitacion NUMBER       NOT NULL,
    id_temporada  NUMBER       NOT NULL,
    precio_noche  NUMBER(12,2) NOT NULL,
    CONSTRAINT pk_tarifa PRIMARY KEY (id_habitacion, id_temporada),
    CONSTRAINT fk_tarifa_habitacion FOREIGN KEY (id_habitacion)
        REFERENCES HABITACION (id_habitacion),
    CONSTRAINT fk_tarifa_temporada FOREIGN KEY (id_temporada)
        REFERENCES TEMPORADA (id_temporada),
    CONSTRAINT ck_tarifa_precio CHECK (precio_noche > 0)
);

-- RESERVA
CREATE TABLE RESERVA (
    id_reserva      NUMBER       NOT NULL,
    fecha_reserva   DATE         NOT NULL,
    fecha_entrada   DATE         NOT NULL,
    fecha_salida    DATE         NOT NULL,
    numero_personas NUMBER       NOT NULL,
    estado          VARCHAR2(20) NOT NULL,
    valor_total     NUMBER(14,2) NOT NULL,
    id_cliente      NUMBER       NOT NULL,
    CONSTRAINT pk_reserva PRIMARY KEY (id_reserva),
    CONSTRAINT fk_reserva_cliente FOREIGN KEY (id_cliente)
        REFERENCES CLIENTE (id_cliente),
    CONSTRAINT ck_reserva_fechas   CHECK (fecha_salida > fecha_entrada),
    CONSTRAINT ck_reserva_personas CHECK (numero_personas > 0),
    CONSTRAINT ck_reserva_valor    CHECK (valor_total >= 0),
    CONSTRAINT ck_reserva_estado
        CHECK (estado IN ('PENDIENTE', 'CONFIRMADA', 'CANCELADA', 'FINALIZADA'))
)
PARTITION BY RANGE (fecha_entrada) (
    PARTITION p_2024   VALUES LESS THAN (DATE '2025-01-01') TABLESPACE TS_HISTORICO,
    PARTITION p_2025   VALUES LESS THAN (DATE '2026-01-01') TABLESPACE TS_HISTORICO,
    PARTITION p_actual VALUES LESS THAN (MAXVALUE)          TABLESPACE USERS
)
ENABLE ROW MOVEMENT;

-- RESERVA_HABITACION
CREATE TABLE RESERVA_HABITACION (
    id_reserva    NUMBER NOT NULL,
    id_habitacion NUMBER NOT NULL,
    CONSTRAINT pk_reserva_habitacion PRIMARY KEY (id_reserva, id_habitacion),
    CONSTRAINT fk_reserva_habitacion_reserva FOREIGN KEY (id_reserva)
        REFERENCES RESERVA (id_reserva),
    CONSTRAINT fk_reserva_habitacion_habitacion FOREIGN KEY (id_habitacion)
        REFERENCES HABITACION (id_habitacion)
);

-- PAGO
CREATE TABLE PAGO (
    id_pago     NUMBER       NOT NULL,
    fecha       DATE         NOT NULL,
    valor       NUMBER(14,2) NOT NULL,
    confirmado  VARCHAR2(2)  NOT NULL,
    metodo_pago VARCHAR2(30) NOT NULL,
    id_reserva  NUMBER       NOT NULL,
    CONSTRAINT pk_pago PRIMARY KEY (id_pago),
    CONSTRAINT fk_pago_reserva FOREIGN KEY (id_reserva)
        REFERENCES RESERVA (id_reserva),
    CONSTRAINT ck_pago_valor      CHECK (valor > 0),
    CONSTRAINT ck_pago_confirmado CHECK (confirmado IN ('SI', 'NO')),
    CONSTRAINT ck_pago_metodo
        CHECK (metodo_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA', 'PSE'))
);

-- SERVICIO
CREATE TABLE SERVICIO (
    id_servicio    NUMBER        NOT NULL,
    nombre         VARCHAR2(100) NOT NULL,
    descripcion    VARCHAR2(250),
    precio         NUMBER(12,2)  NOT NULL,
    id_alojamiento NUMBER        NOT NULL,
    CONSTRAINT pk_servicio PRIMARY KEY (id_servicio),
    CONSTRAINT fk_servicio_alojamiento FOREIGN KEY (id_alojamiento)
        REFERENCES ALOJAMIENTO (id_alojamiento),
    CONSTRAINT uq_servicio_alojamiento_nombre UNIQUE (id_alojamiento, nombre),
    CONSTRAINT ck_servicio_precio CHECK (precio >= 0)
);

-- RESERVA_SERVICIO
CREATE TABLE RESERVA_SERVICIO (
    id_servicio NUMBER       NOT NULL,
    id_reserva  NUMBER       NOT NULL,
    cantidad    NUMBER       NOT NULL,
    subtotal    NUMBER(14,2) NOT NULL,
    CONSTRAINT pk_reserva_servicio PRIMARY KEY (id_servicio, id_reserva),
    CONSTRAINT fk_reserva_servicio_servicio FOREIGN KEY (id_servicio)
        REFERENCES SERVICIO (id_servicio),
    CONSTRAINT fk_reserva_servicio_reserva FOREIGN KEY (id_reserva)
        REFERENCES RESERVA (id_reserva),
    CONSTRAINT ck_reserva_servicio_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_reserva_servicio_subtotal CHECK (subtotal >= 0)
);

-- RESENA
CREATE TABLE RESENA (
    id_resena    NUMBER NOT NULL,
    calificacion NUMBER NOT NULL,
    comentario   VARCHAR2(1000),
    fecha        DATE   NOT NULL,
    id_reserva   NUMBER NOT NULL,
    CONSTRAINT pk_resena PRIMARY KEY (id_resena),
    CONSTRAINT fk_resena_reserva FOREIGN KEY (id_reserva)
        REFERENCES RESERVA (id_reserva),
    CONSTRAINT uq_resena_reserva      UNIQUE (id_reserva),
    CONSTRAINT ck_resena_calificacion CHECK (calificacion BETWEEN 1 AND 5)
);

-- AUDITORIA_TARIFA
CREATE TABLE AUDITORIA_TARIFA (
    id_auditoria   NUMBER GENERATED BY DEFAULT AS IDENTITY,
    usuario        VARCHAR2(100) NOT NULL,
    fecha_cambio   TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    tipo_operacion VARCHAR2(10)  NOT NULL,
    id_habitacion  NUMBER        NOT NULL,
    id_temporada   NUMBER        NOT NULL,
    valor_anterior NUMBER(12,2),
    valor_nuevo    NUMBER(12,2),
    CONSTRAINT pk_auditoria_tarifa PRIMARY KEY (id_auditoria),
    CONSTRAINT ck_auditoria_operacion CHECK (tipo_operacion IN ('INSERT', 'UPDATE', 'DELETE'))
);

-- LIQUIDACION_MENSUAL
CREATE TABLE LIQUIDACION_MENSUAL (
    anio            NUMBER(4)    NOT NULL,
    mes             NUMBER(2)    NOT NULL,
    id_alojamiento  NUMBER       NOT NULL,
    total_reservas  NUMBER       NOT NULL,
    ingresos        NUMBER(14,2) NOT NULL,
    pagado          NUMBER(14,2) NOT NULL,
    saldo_pendiente NUMBER(14,2) NOT NULL,
    temporada       VARCHAR2(10),
    fecha_proceso   DATE DEFAULT SYSDATE,
    CONSTRAINT pk_liquidacion_mensual PRIMARY KEY (anio, mes, id_alojamiento),
    CONSTRAINT fk_liq_mes_alojamiento FOREIGN KEY (id_alojamiento)
        REFERENCES ALOJAMIENTO (id_alojamiento),
    CONSTRAINT ck_liq_mes_mes       CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT ck_liq_mes_temporada CHECK (temporada IN ('ALTA', 'MEDIA', 'BAJA'))
);

-- LIQUIDACION_TEMPORADA
CREATE TABLE LIQUIDACION_TEMPORADA (
    anio            NUMBER(4)    NOT NULL,
    temporada       VARCHAR2(10) NOT NULL,
    id_alojamiento  NUMBER       NOT NULL,
    total_reservas  NUMBER       NOT NULL,
    ingresos        NUMBER(14,2) NOT NULL,
    pagado          NUMBER(14,2) NOT NULL,
    saldo_pendiente NUMBER(14,2) NOT NULL,
    fecha_proceso   DATE DEFAULT SYSDATE,
    CONSTRAINT pk_liquidacion_temporada PRIMARY KEY (anio, temporada, id_alojamiento),
    CONSTRAINT fk_liq_temp_alojamiento FOREIGN KEY (id_alojamiento)
        REFERENCES ALOJAMIENTO (id_alojamiento),
    CONSTRAINT ck_liq_temp_temporada CHECK (temporada IN ('ALTA', 'MEDIA', 'BAJA'))
);

-- ÍNDICES EN LLAVES FORÁNEAS
CREATE INDEX idx_alojamiento_propietario ON ALOJAMIENTO (id_propietario);
CREATE INDEX idx_alojamiento_tipo        ON ALOJAMIENTO (id_tipo_alojamiento);
CREATE INDEX idx_alojamiento_municipio   ON ALOJAMIENTO (id_municipio);
CREATE INDEX idx_tarifa_temporada        ON TARIFA (id_temporada);
CREATE INDEX idx_reserva_cliente         ON RESERVA (id_cliente);
CREATE INDEX idx_reserva_hab_habitacion  ON RESERVA_HABITACION (id_habitacion);
CREATE INDEX idx_pago_reserva            ON PAGO (id_reserva);
CREATE INDEX idx_reserva_serv_reserva    ON RESERVA_SERVICIO (id_reserva);

-- SECUENCIAS
CREATE SEQUENCE seq_municipio   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_tipo_aloj   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_propietario START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_cliente     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_usuario     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_alojamiento START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_habitacion  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_temporada   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_reserva     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_pago        START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_servicio    START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_resena      START WITH 1 INCREMENT BY 1 NOCACHE;
