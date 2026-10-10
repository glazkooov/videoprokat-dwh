-- Лабораторная работа по дисциплине «Хранилища данных»
-- Вариант 14. Система учёта в видеопрокате
-- Часть 2. Модель Data Vault
-- Глазков Г.К., группа 223-321
--
-- Хаб      - список бизнес-ключей сущности
-- Линк     - связь между хабами
-- Сателлит - описательные атрибуты хаба или линка
--
-- Служебные поля:
--   *_hk          - хеш-ключ, md5 от бизнес-ключа
--   load_date     - дата загрузки записи
--   record_source - откуда загружена запись

DROP SCHEMA IF EXISTS dv CASCADE;
CREATE SCHEMA dv;
SET search_path TO dv;

-- ===================== ХАБЫ =====================

CREATE TABLE hub_client (
    client_hk      CHAR(32) PRIMARY KEY,
    card_number    VARCHAR(20) NOT NULL,   -- бизнес-ключ: номер карты
    load_date      TIMESTAMP NOT NULL DEFAULT now(),
    record_source  VARCHAR(50) NOT NULL
);

CREATE TABLE hub_film (
    film_hk        CHAR(32) PRIMARY KEY,
    film_code      VARCHAR(20) NOT NULL,   -- бизнес-ключ: код фильма
    load_date      TIMESTAMP NOT NULL DEFAULT now(),
    record_source  VARCHAR(50) NOT NULL
);

CREATE TABLE hub_copy (
    copy_hk           CHAR(32) PRIMARY KEY,
    inventory_number  VARCHAR(20) NOT NULL,  -- бизнес-ключ: инвентарный номер
    load_date         TIMESTAMP NOT NULL DEFAULT now(),
    record_source     VARCHAR(50) NOT NULL
);

CREATE TABLE hub_employee (
    employee_hk    CHAR(32) PRIMARY KEY,
    tab_number     VARCHAR(10) NOT NULL,   -- бизнес-ключ: табельный номер
    load_date      TIMESTAMP NOT NULL DEFAULT now(),
    record_source  VARCHAR(50) NOT NULL
);

CREATE TABLE hub_rental (
    rental_hk      CHAR(32) PRIMARY KEY,
    rental_number  VARCHAR(20) NOT NULL,   -- бизнес-ключ: номер проката
    load_date      TIMESTAMP NOT NULL DEFAULT now(),
    record_source  VARCHAR(50) NOT NULL
);

-- ===================== ЛИНКИ =====================

-- Копия -> фильм
CREATE TABLE link_copy_film (
    copy_film_hk   CHAR(32) PRIMARY KEY,
    copy_hk        CHAR(32) NOT NULL REFERENCES hub_copy (copy_hk),
    film_hk        CHAR(32) NOT NULL REFERENCES hub_film (film_hk),
    load_date      TIMESTAMP NOT NULL DEFAULT now(),
    record_source  VARCHAR(50) NOT NULL
);

-- Прокат -> клиент и сотрудник
CREATE TABLE link_rental_client_employee (
    rental_client_employee_hk  CHAR(32) PRIMARY KEY,
    rental_hk      CHAR(32) NOT NULL REFERENCES hub_rental (rental_hk),
    client_hk      CHAR(32) NOT NULL REFERENCES hub_client (client_hk),
    employee_hk    CHAR(32) NOT NULL REFERENCES hub_employee (employee_hk),
    load_date      TIMESTAMP NOT NULL DEFAULT now(),
    record_source  VARCHAR(50) NOT NULL
);

-- Прокат -> выданные копии
CREATE TABLE link_rental_copy (
    rental_copy_hk  CHAR(32) PRIMARY KEY,
    rental_hk       CHAR(32) NOT NULL REFERENCES hub_rental (rental_hk),
    copy_hk         CHAR(32) NOT NULL REFERENCES hub_copy (copy_hk),
    load_date       TIMESTAMP NOT NULL DEFAULT now(),
    record_source   VARCHAR(50) NOT NULL
);

-- ===================== САТЕЛЛИТЫ =====================
-- Ключ сателлита = хеш-ключ родителя + дата загрузки,
-- поэтому при изменении данных добавляется новая строка,
-- а старая остаётся (сохраняется история)

CREATE TABLE sat_client (
    client_hk      CHAR(32) NOT NULL REFERENCES hub_client (client_hk),
    load_date      TIMESTAMP NOT NULL DEFAULT now(),
    record_source  VARCHAR(50) NOT NULL,
    last_name      VARCHAR(50),
    first_name     VARCHAR(50),
    middle_name    VARCHAR(50),
    birth_date     DATE,
    phone          VARCHAR(20),
    email          VARCHAR(100),
    address        VARCHAR(200),
    reg_date       DATE,
    PRIMARY KEY (client_hk, load_date)
);

-- Жанр здесь хранится просто как атрибут фильма
CREATE TABLE sat_film (
    film_hk        CHAR(32) NOT NULL REFERENCES hub_film (film_hk),
    load_date      TIMESTAMP NOT NULL DEFAULT now(),
    record_source  VARCHAR(50) NOT NULL,
    title          VARCHAR(200),
    release_year   SMALLINT,
    duration_min   SMALLINT,
    age_rating     VARCHAR(5),
    genre_name     VARCHAR(50),
    price_per_day  NUMERIC(8,2),
    PRIMARY KEY (film_hk, load_date)
);

CREATE TABLE sat_copy (
    copy_hk         CHAR(32) NOT NULL REFERENCES hub_copy (copy_hk),
    load_date       TIMESTAMP NOT NULL DEFAULT now(),
    record_source   VARCHAR(50) NOT NULL,
    carrier_name    VARCHAR(30),
    deposit_amount  NUMERIC(8,2),
    purchase_date   DATE,
    copy_status     VARCHAR(20),
    PRIMARY KEY (copy_hk, load_date)
);

CREATE TABLE sat_employee (
    employee_hk    CHAR(32) NOT NULL REFERENCES hub_employee (employee_hk),
    load_date      TIMESTAMP NOT NULL DEFAULT now(),
    record_source  VARCHAR(50) NOT NULL,
    last_name      VARCHAR(50),
    first_name     VARCHAR(50),
    middle_name    VARCHAR(50),
    position       VARCHAR(50),
    hire_date      DATE,
    PRIMARY KEY (employee_hk, load_date)
);

CREATE TABLE sat_rental (
    rental_hk       CHAR(32) NOT NULL REFERENCES hub_rental (rental_hk),
    load_date       TIMESTAMP NOT NULL DEFAULT now(),
    record_source   VARCHAR(50) NOT NULL,
    rental_date     TIMESTAMP,
    planned_return  DATE,
    PRIMARY KEY (rental_hk, load_date)
);

-- Сателлит на линке: данные по конкретной выданной копии
CREATE TABLE sat_rental_copy (
    rental_copy_hk  CHAR(32) NOT NULL REFERENCES link_rental_copy (rental_copy_hk),
    load_date       TIMESTAMP NOT NULL DEFAULT now(),
    record_source   VARCHAR(50) NOT NULL,
    price_per_day   NUMERIC(8,2),
    actual_return   TIMESTAMP,
    fine_amount     NUMERIC(8,2),
    PRIMARY KEY (rental_copy_hk, load_date)
);

-- ===================== ЗАГРУЗКА ДАННЫХ ИЗ nf3 =====================
-- Порядок: хабы -> линки -> сателлиты

-- Хабы
INSERT INTO hub_client (client_hk, card_number, record_source)
SELECT md5(card_number), card_number, 'nf3.client' FROM nf3.client;

INSERT INTO hub_film (film_hk, film_code, record_source)
SELECT md5(film_code), film_code, 'nf3.film' FROM nf3.film;

INSERT INTO hub_copy (copy_hk, inventory_number, record_source)
SELECT md5(inventory_number), inventory_number, 'nf3.film_copy' FROM nf3.film_copy;

INSERT INTO hub_employee (employee_hk, tab_number, record_source)
SELECT md5(tab_number), tab_number, 'nf3.employee' FROM nf3.employee;

INSERT INTO hub_rental (rental_hk, rental_number, record_source)
SELECT md5(rental_number), rental_number, 'nf3.rental' FROM nf3.rental;

-- Линки (хеш-ключ линка = md5 от склеенных бизнес-ключей)
INSERT INTO link_copy_film (copy_film_hk, copy_hk, film_hk, record_source)
SELECT md5(fc.inventory_number || f.film_code),
       md5(fc.inventory_number), md5(f.film_code), 'nf3.film_copy'
FROM nf3.film_copy fc
JOIN nf3.film f ON f.film_id = fc.film_id;

INSERT INTO link_rental_client_employee
       (rental_client_employee_hk, rental_hk, client_hk, employee_hk, record_source)
SELECT md5(r.rental_number || c.card_number || e.tab_number),
       md5(r.rental_number), md5(c.card_number), md5(e.tab_number), 'nf3.rental'
FROM nf3.rental r
JOIN nf3.client c   ON c.client_id = r.client_id
JOIN nf3.employee e ON e.employee_id = r.employee_id;

INSERT INTO link_rental_copy (rental_copy_hk, rental_hk, copy_hk, record_source)
SELECT md5(r.rental_number || fc.inventory_number),
       md5(r.rental_number), md5(fc.inventory_number), 'nf3.rental_item'
FROM nf3.rental_item ri
JOIN nf3.rental r     ON r.rental_id = ri.rental_id
JOIN nf3.film_copy fc ON fc.copy_id = ri.copy_id;

-- Сателлиты
INSERT INTO sat_client (client_hk, record_source, last_name, first_name, middle_name,
                        birth_date, phone, email, address, reg_date)
SELECT md5(card_number), 'nf3.client', last_name, first_name, middle_name,
       birth_date, phone, email, address, reg_date
FROM nf3.client;

INSERT INTO sat_film (film_hk, record_source, title, release_year, duration_min,
                      age_rating, genre_name, price_per_day)
SELECT md5(f.film_code), 'nf3.film', f.title, f.release_year, f.duration_min,
       f.age_rating, g.genre_name, f.price_per_day
FROM nf3.film f
JOIN nf3.genre g ON g.genre_id = f.genre_id;

INSERT INTO sat_copy (copy_hk, record_source, carrier_name, deposit_amount,
                      purchase_date, copy_status)
SELECT md5(fc.inventory_number), 'nf3.film_copy', ct.carrier_name, ct.deposit_amount,
       fc.purchase_date, fc.copy_status
FROM nf3.film_copy fc
JOIN nf3.carrier_type ct ON ct.carrier_type_id = fc.carrier_type_id;

INSERT INTO sat_employee (employee_hk, record_source, last_name, first_name,
                          middle_name, position, hire_date)
SELECT md5(tab_number), 'nf3.employee', last_name, first_name,
       middle_name, position, hire_date
FROM nf3.employee;

INSERT INTO sat_rental (rental_hk, record_source, rental_date, planned_return)
SELECT md5(rental_number), 'nf3.rental', rental_date, planned_return
FROM nf3.rental;

INSERT INTO sat_rental_copy (rental_copy_hk, record_source, price_per_day,
                             actual_return, fine_amount)
SELECT md5(r.rental_number || fc.inventory_number), 'nf3.rental_item',
       ri.price_per_day, ri.actual_return, ri.fine_amount
FROM nf3.rental_item ri
JOIN nf3.rental r     ON r.rental_id = ri.rental_id
JOIN nf3.film_copy fc ON fc.copy_id = ri.copy_id;

-- Проверочный запрос: те же прокаты, но собранные из хранилища
SELECT hr.rental_number, sc.last_name, sf.title, hc.inventory_number,
       sr.rental_date, sr.planned_return, src.actual_return, src.fine_amount
FROM hub_rental hr
JOIN link_rental_client_employee l1 ON l1.rental_hk = hr.rental_hk
JOIN sat_client sc       ON sc.client_hk = l1.client_hk
JOIN sat_rental sr       ON sr.rental_hk = hr.rental_hk
JOIN link_rental_copy l2 ON l2.rental_hk = hr.rental_hk
JOIN sat_rental_copy src ON src.rental_copy_hk = l2.rental_copy_hk
JOIN hub_copy hc         ON hc.copy_hk = l2.copy_hk
JOIN link_copy_film l3   ON l3.copy_hk = hc.copy_hk
JOIN sat_film sf         ON sf.film_hk = l3.film_hk
ORDER BY sr.rental_date;
