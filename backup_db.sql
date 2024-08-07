--
-- PostgreSQL database dump
--

-- Dumped from database version 16.2
-- Dumped by pg_dump version 16.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: inventario_ventas; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA inventario_ventas;


ALTER SCHEMA inventario_ventas OWNER TO postgres;

--
-- Name: actualizar_espacio_disponible(); Type: FUNCTION; Schema: inventario_ventas; Owner: postgres
--

CREATE FUNCTION inventario_ventas.actualizar_espacio_disponible() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Actualizar el espacio disponible en la bodega
    UPDATE inventario_ventas.bodega
    SET capacidad_uso = COALESCE((SELECT SUM(cantidad_disponible)
                                 FROM inventario_ventas.inventario
                                 WHERE id_bodega = NEW.id_bodega), 0)
    WHERE id = NEW.id_bodega;
    
    
    UPDATE inventario_ventas.bodega SET 
    espacio_disponible = capacidad_max - capacidad_uso
    WHERE id = NEW.id_bodega;

    RETURN NEW;
END;
$$;


ALTER FUNCTION inventario_ventas.actualizar_espacio_disponible() OWNER TO postgres;

--
-- Name: actualizar_estado_producto(); Type: FUNCTION; Schema: inventario_ventas; Owner: postgres
--

CREATE FUNCTION inventario_ventas.actualizar_estado_producto() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_inventario_producto INT;
BEGIN
    -- Obtener la cantidad disponible del producto en el inventario
    SELECT COALESCE(SUM(cantidad_disponible), 0) INTO v_inventario_producto
    FROM inventario_ventas.inventario
    WHERE id_producto = NEW.id_producto;

    -- Actualizar el estado del producto basado en la cantidad disponible
    IF v_inventario_producto = 0 THEN
        UPDATE inventario_ventas.productos
        SET activo = FALSE
        WHERE id_producto = NEW.id_producto;
    ELSE 
        UPDATE inventario_ventas.productos
        SET activo = TRUE
        WHERE id_producto = NEW.id_producto;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION inventario_ventas.actualizar_estado_producto() OWNER TO postgres;

--
-- Name: crear_producto(character varying, text, numeric); Type: PROCEDURE; Schema: inventario_ventas; Owner: postgres
--

CREATE PROCEDURE inventario_ventas.crear_producto(IN p_nombre character varying, IN p_descripcion text, IN p_precio numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_producto INT;
BEGIN
    -- Validacion
    IF p_nombre IS NULL OR p_nombre = '' THEN
        RAISE EXCEPTION 'El nombre del producto no puede ser nulo o vacío';
    END IF;

    IF p_precio <= 0 THEN
        RAISE EXCEPTION 'El precio del producto debe ser mayor que cero';
    END IF;

    -- Inicia la transaccion
    BEGIN
        -- Agrega el registro en la tabla de productos
        INSERT INTO inventario_ventas.productos (nombre, descripcion, precio)
        VALUES (p_nombre, p_descripcion, p_precio)
        RETURNING id_producto INTO v_id_producto;
        
        -- Verificar si el id_producto no es nulo
        IF v_id_producto IS NULL THEN
            RAISE EXCEPTION 'El ID del producto no puede ser nulo';
        END IF;

        RAISE NOTICE 'ID del producto no es nulo';

        -- Intentar agregar el producto en la tabla de inventario
        INSERT INTO inventario_ventas.inventario (id_producto)
        VALUES (v_id_producto);
               
       	-- Confirmacion
        RAISE NOTICE 'Nuevo producto registrado con éxito: %', p_nombre;
           
       	EXCEPTION
        WHEN OTHERS THEN
        	-- Cancela transaccion
            ROLLBACK;
            RAISE NOTICE 'Error: %', SQLERRM;
        
		-- Fin transaccion
        COMMIT;

    END;
END;
$$;


ALTER PROCEDURE inventario_ventas.crear_producto(IN p_nombre character varying, IN p_descripcion text, IN p_precio numeric) OWNER TO postgres;

--
-- Name: create_inventario(); Type: FUNCTION; Schema: inventario_ventas; Owner: postgres
--

CREATE FUNCTION inventario_ventas.create_inventario() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO inventario_ventas.inventario (id_producto, cantidad_disponible, id_bodega)
    VALUES (NEW.id_producto, 0, NULL);
    RETURN NEW;
END;
$$;


ALTER FUNCTION inventario_ventas.create_inventario() OWNER TO postgres;

--
-- Name: insertar_venta_con_detalles(json); Type: PROCEDURE; Schema: inventario_ventas; Owner: postgres
--

CREATE PROCEDURE inventario_ventas.insertar_venta_con_detalles(IN p_detalles json)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_venta INT;
    v_detalle JSONB;
    v_id_producto INT;
    v_cantidad INT;
    v_cantidad_disponible INT;
  	v_nombre_producto VARCHAR(255);
    v_precio_unitario DECIMAL(10, 2);
    v_total_venta DECIMAL(10, 2) := 0;
    v_total_producto_cantidad DECIMAL(10, 2);
    v_fecha TIMESTAMP := NOW();
BEGIN
    -- Inicio de la transacción
    BEGIN
        -- Validaciones de los detalles y cálculo del total de la venta
        FOR v_detalle IN SELECT * FROM jsonb_array_elements(p_detalles::jsonb)
        LOOP
            v_id_producto := (v_detalle->>'id_producto')::INT;
            v_cantidad := (v_detalle->>'cantidad')::INT;

            -- Validaciones de detalles
            IF v_id_producto IS NULL OR NOT EXISTS (SELECT 1 FROM inventario_ventas.productos WHERE id_producto = v_id_producto) THEN
                RAISE EXCEPTION 'El producto con ID % no existe', v_id_producto;
            END IF;
            
            
            -- Obtener cantidad en bodega
            SELECT cantidad_disponible INTO v_cantidad_disponible
            FROM inventario_ventas.inventario 
            WHERE id_producto = v_id_producto;
            

			-- Validar la cantidad que no sea 0 y que este disponible ne bodega
            IF v_cantidad <= 0 OR v_cantidad > v_cantidad_disponible THEN
    		RAISE EXCEPTION 'La cantidad debe ser mayor que cero y no puede ser mayor que la cantidad disponible';
			END IF;

            
            -- Obtener el precio unitario del producto
            SELECT precio INTO v_precio_unitario
            FROM inventario_ventas.productos
            WHERE id_producto = v_id_producto;
            
            -- Obtener la cantidad que hay en el inventario y actualizarla
            UPDATE inventario_ventas.inventario
		    SET cantidad_disponible = cantidad_disponible - v_cantidad
		    WHERE id_producto = v_id_producto;
            
            -- Calcular el total del detalle
            v_total_producto_cantidad := v_precio_unitario * v_cantidad;

            -- Calcular el total de la venta
            v_total_venta := v_total_venta + v_total_producto_cantidad;
        END LOOP;

        -- Insertar en ventas y obtener el id de la venta
        INSERT INTO inventario_ventas.ventas (fecha_venta, total_venta)
        VALUES (v_fecha, v_total_venta)
        RETURNING id_venta INTO v_id_venta;

        -- Insertar en detalle_venta
        FOR v_detalle IN SELECT * FROM jsonb_array_elements(p_detalles::jsonb)
        LOOP
            v_id_producto := (v_detalle->>'id_producto')::INT;
            v_cantidad := (v_detalle->>'cantidad')::INT;


            -- Insertar en detalle_venta
            INSERT INTO inventario_ventas.detalle_venta (id_venta, id_producto, cantidad)
            VALUES (v_id_venta, v_id_producto, v_cantidad);
        END LOOP;

        -- Confirmación de la venta
        RAISE NOTICE 'Venta generada: Fecha %, Total %, ID Venta %', v_fecha, v_total_venta, v_id_venta;

    EXCEPTION
        WHEN OTHERS THEN
            -- Cancelar la transacción
            RAISE NOTICE 'Error: %', SQLERRM;
            ROLLBACK;
            RETURN;
    END;

    -- Fin de la transacción
    COMMIT;
END;
$$;


ALTER PROCEDURE inventario_ventas.insertar_venta_con_detalles(IN p_detalles json) OWNER TO postgres;

--
-- Name: set_espacio_disponible(); Type: FUNCTION; Schema: inventario_ventas; Owner: postgres
--

CREATE FUNCTION inventario_ventas.set_espacio_disponible() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Asignar capacidad_max a espacio_disponible si este último es NULL
    IF NEW.espacio_disponible IS NULL THEN
        NEW.espacio_disponible = NEW.capacidad_max;
    END IF;

    -- Actualizar espacio_disponible al nuevo valor de capacidad_max si este cambia
    IF NEW.capacidad_max IS DISTINCT FROM OLD.capacidad_max THEN
        NEW.espacio_disponible = NEW.capacidad_max;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION inventario_ventas.set_espacio_disponible() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: auth_group; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);


ALTER TABLE inventario_ventas.auth_group OWNER TO postgres;

--
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE inventario_ventas.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventario_ventas.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_group_permissions; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE inventario_ventas.auth_group_permissions OWNER TO postgres;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE inventario_ventas.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventario_ventas.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_permission; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


ALTER TABLE inventario_ventas.auth_permission OWNER TO postgres;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE inventario_ventas.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventario_ventas.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_user; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.auth_user (
    id integer NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    username character varying(150) NOT NULL,
    first_name character varying(150) NOT NULL,
    last_name character varying(150) NOT NULL,
    email character varying(254) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL
);


ALTER TABLE inventario_ventas.auth_user OWNER TO postgres;

--
-- Name: auth_user_groups; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.auth_user_groups (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


ALTER TABLE inventario_ventas.auth_user_groups OWNER TO postgres;

--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE inventario_ventas.auth_user_groups ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventario_ventas.auth_user_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_user_id_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE inventario_ventas.auth_user ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventario_ventas.auth_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_user_user_permissions; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.auth_user_user_permissions (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE inventario_ventas.auth_user_user_permissions OWNER TO postgres;

--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE inventario_ventas.auth_user_user_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventario_ventas.auth_user_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: bodega; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.bodega (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    capacidad_max integer NOT NULL,
    capacidad_uso integer DEFAULT 0 NOT NULL,
    ubicacion character varying(255) NOT NULL,
    espacio_disponible integer
);


ALTER TABLE inventario_ventas.bodega OWNER TO postgres;

--
-- Name: bodega_id_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

CREATE SEQUENCE inventario_ventas.bodega_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE inventario_ventas.bodega_id_seq OWNER TO postgres;

--
-- Name: bodega_id_seq; Type: SEQUENCE OWNED BY; Schema: inventario_ventas; Owner: postgres
--

ALTER SEQUENCE inventario_ventas.bodega_id_seq OWNED BY inventario_ventas.bodega.id;


--
-- Name: detalle_venta; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.detalle_venta (
    id_detalle integer NOT NULL,
    id_venta integer,
    id_producto integer,
    cantidad integer NOT NULL
);


ALTER TABLE inventario_ventas.detalle_venta OWNER TO postgres;

--
-- Name: detalle_venta_id_detalle_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

CREATE SEQUENCE inventario_ventas.detalle_venta_id_detalle_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE inventario_ventas.detalle_venta_id_detalle_seq OWNER TO postgres;

--
-- Name: detalle_venta_id_detalle_seq; Type: SEQUENCE OWNED BY; Schema: inventario_ventas; Owner: postgres
--

ALTER SEQUENCE inventario_ventas.detalle_venta_id_detalle_seq OWNED BY inventario_ventas.detalle_venta.id_detalle;


--
-- Name: django_admin_log; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id integer NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


ALTER TABLE inventario_ventas.django_admin_log OWNER TO postgres;

--
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE inventario_ventas.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventario_ventas.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_content_type; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


ALTER TABLE inventario_ventas.django_content_type OWNER TO postgres;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE inventario_ventas.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventario_ventas.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_migrations; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


ALTER TABLE inventario_ventas.django_migrations OWNER TO postgres;

--
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE inventario_ventas.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventario_ventas.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_session; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


ALTER TABLE inventario_ventas.django_session OWNER TO postgres;

--
-- Name: inventario; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.inventario (
    id_inventario integer NOT NULL,
    id_producto integer,
    cantidad_disponible integer DEFAULT 0 NOT NULL,
    id_bodega integer
);


ALTER TABLE inventario_ventas.inventario OWNER TO postgres;

--
-- Name: inventario_id_inventario_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

CREATE SEQUENCE inventario_ventas.inventario_id_inventario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE inventario_ventas.inventario_id_inventario_seq OWNER TO postgres;

--
-- Name: inventario_id_inventario_seq; Type: SEQUENCE OWNED BY; Schema: inventario_ventas; Owner: postgres
--

ALTER SEQUENCE inventario_ventas.inventario_id_inventario_seq OWNED BY inventario_ventas.inventario.id_inventario;


--
-- Name: productos; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.productos (
    id_producto integer NOT NULL,
    nombre character varying(255) NOT NULL,
    descripcion text,
    precio numeric(10,2) NOT NULL,
    activo boolean DEFAULT false NOT NULL
);


ALTER TABLE inventario_ventas.productos OWNER TO postgres;

--
-- Name: productos_id_producto_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

CREATE SEQUENCE inventario_ventas.productos_id_producto_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE inventario_ventas.productos_id_producto_seq OWNER TO postgres;

--
-- Name: productos_id_producto_seq; Type: SEQUENCE OWNED BY; Schema: inventario_ventas; Owner: postgres
--

ALTER SEQUENCE inventario_ventas.productos_id_producto_seq OWNED BY inventario_ventas.productos.id_producto;


--
-- Name: ventas; Type: TABLE; Schema: inventario_ventas; Owner: postgres
--

CREATE TABLE inventario_ventas.ventas (
    id_venta integer NOT NULL,
    fecha_venta date NOT NULL,
    total_venta numeric(10,2) NOT NULL
);


ALTER TABLE inventario_ventas.ventas OWNER TO postgres;

--
-- Name: ventas_id_venta_seq; Type: SEQUENCE; Schema: inventario_ventas; Owner: postgres
--

CREATE SEQUENCE inventario_ventas.ventas_id_venta_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE inventario_ventas.ventas_id_venta_seq OWNER TO postgres;

--
-- Name: ventas_id_venta_seq; Type: SEQUENCE OWNED BY; Schema: inventario_ventas; Owner: postgres
--

ALTER SEQUENCE inventario_ventas.ventas_id_venta_seq OWNED BY inventario_ventas.ventas.id_venta;


--
-- Name: bodega id; Type: DEFAULT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.bodega ALTER COLUMN id SET DEFAULT nextval('inventario_ventas.bodega_id_seq'::regclass);


--
-- Name: detalle_venta id_detalle; Type: DEFAULT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.detalle_venta ALTER COLUMN id_detalle SET DEFAULT nextval('inventario_ventas.detalle_venta_id_detalle_seq'::regclass);


--
-- Name: inventario id_inventario; Type: DEFAULT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.inventario ALTER COLUMN id_inventario SET DEFAULT nextval('inventario_ventas.inventario_id_inventario_seq'::regclass);


--
-- Name: productos id_producto; Type: DEFAULT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.productos ALTER COLUMN id_producto SET DEFAULT nextval('inventario_ventas.productos_id_producto_seq'::regclass);


--
-- Name: ventas id_venta; Type: DEFAULT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.ventas ALTER COLUMN id_venta SET DEFAULT nextval('inventario_ventas.ventas_id_venta_seq'::regclass);


--
-- Data for Name: auth_group; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.auth_group (id, name) FROM stdin;
\.


--
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.auth_group_permissions (id, group_id, permission_id) FROM stdin;
\.


--
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.auth_permission (id, name, content_type_id, codename) FROM stdin;
1	Can add log entry	1	add_logentry
2	Can change log entry	1	change_logentry
3	Can delete log entry	1	delete_logentry
4	Can view log entry	1	view_logentry
5	Can add permission	2	add_permission
6	Can change permission	2	change_permission
7	Can delete permission	2	delete_permission
8	Can view permission	2	view_permission
9	Can add group	3	add_group
10	Can change group	3	change_group
11	Can delete group	3	delete_group
12	Can view group	3	view_group
13	Can add user	4	add_user
14	Can change user	4	change_user
15	Can delete user	4	delete_user
16	Can view user	4	view_user
17	Can add content type	5	add_contenttype
18	Can change content type	5	change_contenttype
19	Can delete content type	5	delete_contenttype
20	Can view content type	5	view_contenttype
21	Can add session	6	add_session
22	Can change session	6	change_session
23	Can delete session	6	delete_session
24	Can view session	6	view_session
25	Can add bodega	7	add_bodega
26	Can change bodega	7	change_bodega
27	Can delete bodega	7	delete_bodega
28	Can view bodega	7	view_bodega
29	Can add detalle venta	8	add_detalleventa
30	Can change detalle venta	8	change_detalleventa
31	Can delete detalle venta	8	delete_detalleventa
32	Can view detalle venta	8	view_detalleventa
33	Can add inventario	9	add_inventario
34	Can change inventario	9	change_inventario
35	Can delete inventario	9	delete_inventario
36	Can view inventario	9	view_inventario
37	Can add productos	10	add_productos
38	Can change productos	10	change_productos
39	Can delete productos	10	delete_productos
40	Can view productos	10	view_productos
41	Can add ventas	11	add_ventas
42	Can change ventas	11	change_ventas
43	Can delete ventas	11	delete_ventas
44	Can view ventas	11	view_ventas
\.


--
-- Data for Name: auth_user; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.auth_user (id, password, last_login, is_superuser, username, first_name, last_name, email, is_staff, is_active, date_joined) FROM stdin;
1	pbkdf2_sha256$720000$NJ3UVOisjxifv57rQ6Zu03$GTMu53aOeZ010M2VSiZxWt6gNciWWaB3PMIOip4O8F8=	2024-07-29 11:11:08.876756-05	t	admin			admin@example.com	t	t	2024-07-28 09:41:55.158744-05
\.


--
-- Data for Name: auth_user_groups; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.auth_user_groups (id, user_id, group_id) FROM stdin;
\.


--
-- Data for Name: auth_user_user_permissions; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.auth_user_user_permissions (id, user_id, permission_id) FROM stdin;
\.


--
-- Data for Name: bodega; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.bodega (id, nombre, capacidad_max, capacidad_uso, ubicacion, espacio_disponible) FROM stdin;
2	Bodega Norte	500	763	Sucursal Norte	-263
1	Bodega Central	1000	684	Centro de Distribución	316
6	Bodega	200	0	Barrio	200
3	Bodega Sur	750	5	Sucursal Sur	745
\.


--
-- Data for Name: detalle_venta; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.detalle_venta (id_detalle, id_venta, id_producto, cantidad) FROM stdin;
14	8	30	3
15	8	33	2
20	11	30	2
21	11	32	5
24	13	30	2
25	13	32	5
26	14	32	4
27	14	30	3
28	15	41	2
29	16	32	2
30	16	30	3
\.


--
-- Data for Name: django_admin_log; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
\.


--
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.django_content_type (id, app_label, model) FROM stdin;
1	admin	logentry
2	auth	permission
3	auth	group
4	auth	user
5	contenttypes	contenttype
6	sessions	session
7	api	bodega
8	api	detalleventa
9	api	inventario
10	api	productos
11	api	ventas
\.


--
-- Data for Name: django_migrations; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.django_migrations (id, app, name, applied) FROM stdin;
1	contenttypes	0001_initial	2024-07-28 09:39:39.175032-05
2	auth	0001_initial	2024-07-28 09:39:39.328819-05
3	admin	0001_initial	2024-07-28 09:39:39.367551-05
4	admin	0002_logentry_remove_auto_add	2024-07-28 09:39:39.384455-05
5	admin	0003_logentry_add_action_flag_choices	2024-07-28 09:39:39.384455-05
6	contenttypes	0002_remove_content_type_name	2024-07-28 09:39:39.441693-05
7	auth	0002_alter_permission_name_max_length	2024-07-28 09:39:39.454037-05
8	auth	0003_alter_user_email_max_length	2024-07-28 09:39:39.47541-05
9	auth	0004_alter_user_username_opts	2024-07-28 09:39:39.485385-05
10	auth	0005_alter_user_last_login_null	2024-07-28 09:39:39.501876-05
11	auth	0006_require_contenttypes_0002	2024-07-28 09:39:39.503875-05
12	auth	0007_alter_validators_add_error_messages	2024-07-28 09:39:39.514816-05
13	auth	0008_alter_user_username_max_length	2024-07-28 09:39:39.545732-05
14	auth	0009_alter_user_last_name_max_length	2024-07-28 09:39:39.562775-05
15	auth	0010_alter_group_name_max_length	2024-07-28 09:39:39.579375-05
16	auth	0011_update_proxy_permissions	2024-07-28 09:39:39.589379-05
17	auth	0012_alter_user_first_name_max_length	2024-07-28 09:39:39.60813-05
18	sessions	0001_initial	2024-07-28 09:39:39.634103-05
20	api	0002_alter_bodega_options	2024-07-31 20:13:26.625178-05
21	api	0003_alter_bodega_options	2024-07-31 20:14:04.955598-05
23	api	0001_initial	2024-07-31 20:43:27.225242-05
24	api	0002_alter_bodega_options_alter_detalleventa_options_and_more	2024-07-31 20:43:27.245548-05
\.


--
-- Data for Name: django_session; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.django_session (session_key, session_data, expire_date) FROM stdin;
ulhirjfhp7gq4dwnaqnb8hupmyn5j0lm	.eJxVjMsOwiAURP-FtSFc3rh07zcQuFylaiAp7cr477ZJF7qcOWfmzWJalxrXQXOcCjszYKffLid8UttBeaR27xx7W-Yp813hBx382gu9Lof7d1DTqNs6gFZBkNUyk1CFhPXOGCtvoLTLRiAYjX5LaKQOCDkplAazLw4UQWGfL7HENwE:1sY59B:MpF6_iUfDEI29aoEPkcVtT5yfb-YYQK6vm0OaJQsHog	2024-08-11 09:45:17.625847-05
lmcv8z02gzhwjknow5wey96djoaix4a3	.eJxVjMsOwiAURP-FtSFc3rh07zcQuFylaiAp7cr477ZJF7qcOWfmzWJalxrXQXOcCjszYKffLid8UttBeaR27xx7W-Yp813hBx382gu9Lof7d1DTqNs6gFZBkNUyk1CFhPXOGCtvoLTLRiAYjX5LaKQOCDkplAazLw4UQWGfL7HENwE:1sYSxo:iU_dKuJ7qtSmrYaZY64rOquYcgAPDztmFrzwnpE__R0	2024-08-12 11:11:08.886756-05
\.


--
-- Data for Name: inventario; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.inventario (id_inventario, id_producto, cantidad_disponible, id_bodega) FROM stdin;
10	33	0	3
12	40	0	\N
13	41	5	3
9	32	169	2
7	30	594	2
\.


--
-- Data for Name: productos; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.productos (id_producto, nombre, descripcion, precio, activo) FROM stdin;
33	Tv Samsung 40"	Pantalla OLED de 40"	2220000.00	f
34	Producto 1	Descripción del producto 1	100.00	f
35	Producto 2	Descripción del producto 2	200.00	f
36	dasdsadsad	dsadasda	20.00	f
37	Nuevo	Sssss	400.00	f
40	Test	desc	22000.00	f
41	taza	cualquiera	4000.00	t
32	Tv Samsung 32"	Pantalla OLED de 32"	2220000.00	t
30	Caja	Caja de medidas axbxc cm	3200.00	t
\.


--
-- Data for Name: ventas; Type: TABLE DATA; Schema: inventario_ventas; Owner: postgres
--

COPY inventario_ventas.ventas (id_venta, fecha_venta, total_venta) FROM stdin;
8	2024-07-29	4446600.00
11	2024-07-30	11104400.00
13	2024-08-01	11104400.00
14	2024-08-06	8889600.00
15	2024-08-06	8000.00
16	2024-08-07	4449600.00
\.


--
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.auth_group_id_seq', 1, false);


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.auth_group_permissions_id_seq', 1, false);


--
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.auth_permission_id_seq', 44, true);


--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.auth_user_groups_id_seq', 1, false);


--
-- Name: auth_user_id_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.auth_user_id_seq', 1, true);


--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.auth_user_user_permissions_id_seq', 1, false);


--
-- Name: bodega_id_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.bodega_id_seq', 6, true);


--
-- Name: detalle_venta_id_detalle_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.detalle_venta_id_detalle_seq', 30, true);


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.django_admin_log_id_seq', 1, false);


--
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.django_content_type_id_seq', 11, true);


--
-- Name: django_migrations_id_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.django_migrations_id_seq', 24, true);


--
-- Name: inventario_id_inventario_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.inventario_id_inventario_seq', 13, true);


--
-- Name: productos_id_producto_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.productos_id_producto_seq', 41, true);


--
-- Name: ventas_id_venta_seq; Type: SEQUENCE SET; Schema: inventario_ventas; Owner: postgres
--

SELECT pg_catalog.setval('inventario_ventas.ventas_id_venta_seq', 16, true);


--
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- Name: auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- Name: auth_permission auth_permission_content_type_id_codename_01ab375a_uniq; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups auth_user_groups_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_user_groups
    ADD CONSTRAINT auth_user_groups_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups auth_user_groups_user_id_group_id_94350c0c_uniq; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_group_id_94350c0c_uniq UNIQUE (user_id, group_id);


--
-- Name: auth_user auth_user_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_user
    ADD CONSTRAINT auth_user_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions auth_user_user_permissions_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_permission_id_14a6b632_uniq; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_permission_id_14a6b632_uniq UNIQUE (user_id, permission_id);


--
-- Name: auth_user auth_user_username_key; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_user
    ADD CONSTRAINT auth_user_username_key UNIQUE (username);


--
-- Name: bodega bodega_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.bodega
    ADD CONSTRAINT bodega_pkey PRIMARY KEY (id);


--
-- Name: detalle_venta detalle_venta_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.detalle_venta
    ADD CONSTRAINT detalle_venta_pkey PRIMARY KEY (id_detalle);


--
-- Name: django_admin_log django_admin_log_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- Name: django_content_type django_content_type_app_label_model_76bd3d3b_uniq; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- Name: django_session django_session_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- Name: inventario inventario_id_producto_key; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.inventario
    ADD CONSTRAINT inventario_id_producto_key UNIQUE (id_producto);


--
-- Name: inventario inventario_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.inventario
    ADD CONSTRAINT inventario_pkey PRIMARY KEY (id_inventario);


--
-- Name: productos productos_nombre_key; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.productos
    ADD CONSTRAINT productos_nombre_key UNIQUE (nombre);


--
-- Name: productos productos_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.productos
    ADD CONSTRAINT productos_pkey PRIMARY KEY (id_producto);


--
-- Name: ventas ventas_pkey; Type: CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.ventas
    ADD CONSTRAINT ventas_pkey PRIMARY KEY (id_venta);


--
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX auth_group_name_a6ea08ec_like ON inventario_ventas.auth_group USING btree (name varchar_pattern_ops);


--
-- Name: auth_group_permissions_group_id_b120cbf9; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON inventario_ventas.auth_group_permissions USING btree (group_id);


--
-- Name: auth_group_permissions_permission_id_84c5c92e; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON inventario_ventas.auth_group_permissions USING btree (permission_id);


--
-- Name: auth_permission_content_type_id_2f476e4b; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX auth_permission_content_type_id_2f476e4b ON inventario_ventas.auth_permission USING btree (content_type_id);


--
-- Name: auth_user_groups_group_id_97559544; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX auth_user_groups_group_id_97559544 ON inventario_ventas.auth_user_groups USING btree (group_id);


--
-- Name: auth_user_groups_user_id_6a12ed8b; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX auth_user_groups_user_id_6a12ed8b ON inventario_ventas.auth_user_groups USING btree (user_id);


--
-- Name: auth_user_user_permissions_permission_id_1fbb5f2c; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX auth_user_user_permissions_permission_id_1fbb5f2c ON inventario_ventas.auth_user_user_permissions USING btree (permission_id);


--
-- Name: auth_user_user_permissions_user_id_a95ead1b; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX auth_user_user_permissions_user_id_a95ead1b ON inventario_ventas.auth_user_user_permissions USING btree (user_id);


--
-- Name: auth_user_username_6821ab7c_like; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX auth_user_username_6821ab7c_like ON inventario_ventas.auth_user USING btree (username varchar_pattern_ops);


--
-- Name: django_admin_log_content_type_id_c4bce8eb; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON inventario_ventas.django_admin_log USING btree (content_type_id);


--
-- Name: django_admin_log_user_id_c564eba6; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX django_admin_log_user_id_c564eba6 ON inventario_ventas.django_admin_log USING btree (user_id);


--
-- Name: django_session_expire_date_a5c62663; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX django_session_expire_date_a5c62663 ON inventario_ventas.django_session USING btree (expire_date);


--
-- Name: django_session_session_key_c0390e0f_like; Type: INDEX; Schema: inventario_ventas; Owner: postgres
--

CREATE INDEX django_session_session_key_c0390e0f_like ON inventario_ventas.django_session USING btree (session_key varchar_pattern_ops);


--
-- Name: inventario actualizar_estado_producto_trigger; Type: TRIGGER; Schema: inventario_ventas; Owner: postgres
--

CREATE TRIGGER actualizar_estado_producto_trigger AFTER UPDATE ON inventario_ventas.inventario FOR EACH ROW EXECUTE FUNCTION inventario_ventas.actualizar_estado_producto();


--
-- Name: productos after_producto_insert; Type: TRIGGER; Schema: inventario_ventas; Owner: postgres
--

CREATE TRIGGER after_producto_insert AFTER INSERT ON inventario_ventas.productos FOR EACH ROW EXECUTE FUNCTION inventario_ventas.create_inventario();


--
-- Name: inventario trg_actualizar_espacio_disponible; Type: TRIGGER; Schema: inventario_ventas; Owner: postgres
--

CREATE TRIGGER trg_actualizar_espacio_disponible AFTER INSERT OR DELETE OR UPDATE ON inventario_ventas.inventario FOR EACH ROW EXECUTE FUNCTION inventario_ventas.actualizar_espacio_disponible();


--
-- Name: bodega trigger_set_espacio_disponible; Type: TRIGGER; Schema: inventario_ventas; Owner: postgres
--

CREATE TRIGGER trigger_set_espacio_disponible BEFORE INSERT ON inventario_ventas.bodega FOR EACH ROW EXECUTE FUNCTION inventario_ventas.set_espacio_disponible();


--
-- Name: bodega trigger_set_espacio_disponible_upd; Type: TRIGGER; Schema: inventario_ventas; Owner: postgres
--

CREATE TRIGGER trigger_set_espacio_disponible_upd BEFORE UPDATE ON inventario_ventas.bodega FOR EACH ROW EXECUTE FUNCTION inventario_ventas.set_espacio_disponible();


--
-- Name: auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES inventario_ventas.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES inventario_ventas.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES inventario_ventas.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups auth_user_groups_group_id_97559544_fk_auth_group_id; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_user_groups
    ADD CONSTRAINT auth_user_groups_group_id_97559544_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES inventario_ventas.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups auth_user_groups_user_id_6a12ed8b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_6a12ed8b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES inventario_ventas.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES inventario_ventas.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES inventario_ventas.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: detalle_venta detalle_venta_id_producto_fkey; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.detalle_venta
    ADD CONSTRAINT detalle_venta_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES inventario_ventas.productos(id_producto);


--
-- Name: detalle_venta detalle_venta_id_venta_fkey; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.detalle_venta
    ADD CONSTRAINT detalle_venta_id_venta_fkey FOREIGN KEY (id_venta) REFERENCES inventario_ventas.ventas(id_venta) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- Name: django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES inventario_ventas.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log django_admin_log_user_id_c564eba6_fk_auth_user_id; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES inventario_ventas.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: inventario fk_bodega; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.inventario
    ADD CONSTRAINT fk_bodega FOREIGN KEY (id_bodega) REFERENCES inventario_ventas.bodega(id);


--
-- Name: inventario inventario_id_producto_fkey; Type: FK CONSTRAINT; Schema: inventario_ventas; Owner: postgres
--

ALTER TABLE ONLY inventario_ventas.inventario
    ADD CONSTRAINT inventario_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES inventario_ventas.productos(id_producto);


--
-- PostgreSQL database dump complete
--

