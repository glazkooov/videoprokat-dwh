-- Лабораторная работа по дисциплине «Хранилища данных»
-- Вариант 14. Система учёта в видеопрокате
-- Часть 1. Модель 3NF
-- Глазков Г.К., группа 223-321

-- Схема nf3 удаляется и создаётся заново,
-- чтобы скрипт можно было запускать несколько раз
DROP SCHEMA IF EXISTS nf3 CASCADE;
CREATE SCHEMA nf3;
SET search_path TO nf3;

-- Жанры фильмов (справочник)
CREATE TABLE genre (
    genre_id    SERIAL PRIMARY KEY,
    genre_name  VARCHAR(50) NOT NULL UNIQUE      -- название жанра
);

-- Типы носителей (справочник): DVD, Blu-ray
CREATE TABLE carrier_type (
    carrier_type_id  SERIAL PRIMARY KEY,
    carrier_name     VARCHAR(30) NOT NULL UNIQUE,  -- название носителя
    deposit_amount   NUMERIC(8,2) NOT NULL         -- залог за копию, руб.
);

-- Фильмы
CREATE TABLE film (
    film_id        SERIAL PRIMARY KEY,
    film_code      VARCHAR(20) NOT NULL UNIQUE,    -- каталожный код фильма
    title          VARCHAR(200) NOT NULL,          -- название
    release_year   SMALLINT,                       -- год выпуска
    duration_min   SMALLINT,                       -- длительность, мин.
    age_rating     VARCHAR(5),                     -- возрастное ограничение
    price_per_day  NUMERIC(8,2) NOT NULL,          -- цена проката за сутки
    genre_id       INTEGER NOT NULL REFERENCES genre (genre_id)
);

-- Копии фильмов (конкретные диски)
CREATE TABLE film_copy (
    copy_id           SERIAL PRIMARY KEY,
    inventory_number  VARCHAR(20) NOT NULL UNIQUE, -- инвентарный номер
    film_id           INTEGER NOT NULL REFERENCES film (film_id),
    carrier_type_id   INTEGER NOT NULL REFERENCES carrier_type (carrier_type_id),
    purchase_date     DATE NOT NULL,               -- дата поступления
    copy_status       VARCHAR(20) NOT NULL DEFAULT 'в наличии'
                      CHECK (copy_status IN ('в наличии', 'выдана', 'списана'))
);

-- Клиенты
CREATE TABLE client (
    client_id    SERIAL PRIMARY KEY,
    card_number  VARCHAR(20) NOT NULL UNIQUE,      -- номер клиентской карты
    last_name    VARCHAR(50) NOT NULL,
    first_name   VARCHAR(50) NOT NULL,
    middle_name  VARCHAR(50),
    birth_date   DATE,
    phone        VARCHAR(20) NOT NULL,
    email        VARCHAR(100),
    address      VARCHAR(200),
    reg_date     DATE NOT NULL DEFAULT CURRENT_DATE  -- дата регистрации
);

-- Сотрудники
CREATE TABLE employee (
    employee_id  SERIAL PRIMARY KEY,
    tab_number   VARCHAR(10) NOT NULL UNIQUE,      -- табельный номер
    last_name    VARCHAR(50) NOT NULL,
    first_name   VARCHAR(50) NOT NULL,
    middle_name  VARCHAR(50),
    position     VARCHAR(50) NOT NULL,             -- должность
    hire_date    DATE NOT NULL                     -- дата приёма
);

-- Прокат (документ выдачи)
CREATE TABLE rental (
    rental_id       SERIAL PRIMARY KEY,
    rental_number   VARCHAR(20) NOT NULL UNIQUE,   -- номер документа
    client_id       INTEGER NOT NULL REFERENCES client (client_id),
    employee_id     INTEGER NOT NULL REFERENCES employee (employee_id),
    rental_date     TIMESTAMP NOT NULL DEFAULT now(),  -- дата выдачи
    planned_return  DATE NOT NULL                  -- плановая дата возврата
);

-- Позиции проката: какие копии выданы по документу
-- (за один раз клиент может взять несколько дисков)
CREATE TABLE rental_item (
    rental_id      INTEGER NOT NULL REFERENCES rental (rental_id),
    copy_id        INTEGER NOT NULL REFERENCES film_copy (copy_id),
    price_per_day  NUMERIC(8,2) NOT NULL,          -- цена на момент выдачи
    actual_return  TIMESTAMP,                      -- фактический возврат
    fine_amount    NUMERIC(8,2) NOT NULL DEFAULT 0,  -- штраф
    PRIMARY KEY (rental_id, copy_id)
);

-- Тестовые данные
INSERT INTO genre (genre_name) VALUES
    ('Комедия'), ('Драма'), ('Фантастика'), ('Мультфильм');

INSERT INTO carrier_type (carrier_name, deposit_amount) VALUES
    ('DVD', 300), ('Blu-ray', 500);

INSERT INTO film (film_code, title, release_year, duration_min, age_rating, price_per_day, genre_id) VALUES
    ('F-0001', 'Москва слезам не верит', 1979, 150, '12+', 80, 2),
    ('F-0002', 'Кин-дза-дза!',           1986, 135, '12+', 70, 3),
    ('F-0003', 'Ёжик в тумане',          1975,  10, '0+',  40, 4),
    ('F-0004', 'Операция «Ы»',           1965,  95, '6+',  60, 1);

INSERT INTO film_copy (inventory_number, film_id, carrier_type_id, purchase_date, copy_status) VALUES
    ('INV-1001', 1, 1, '2025-02-10', 'в наличии'),
    ('INV-1002', 1, 2, '2025-02-10', 'выдана'),
    ('INV-1003', 2, 1, '2025-03-01', 'в наличии'),
    ('INV-1004', 3, 1, '2025-03-15', 'в наличии'),
    ('INV-1005', 4, 2, '2025-04-20', 'выдана');

INSERT INTO client (card_number, last_name, first_name, middle_name, birth_date, phone, email, address, reg_date) VALUES
    ('C-000101', 'Иванов',   'Пётр', 'Сергеевич', '1998-05-12', '+7 900 111-22-33', 'ivanov@mail.ru', 'г. Москва, ул. Ленина, 1', '2025-01-15'),
    ('C-000102', 'Смирнова', 'Анна', 'Игоревна',  '2001-09-30', '+7 900 444-55-66', NULL,             'г. Москва, ул. Мира, 15',  '2025-02-03'),
    ('C-000103', 'Кузнецов', 'Олег', NULL,        '1990-01-07', '+7 900 777-88-99', 'oleg@ya.ru',     NULL,                       '2025-03-21');

INSERT INTO employee (tab_number, last_name, first_name, middle_name, position, hire_date) VALUES
    ('T-01', 'Петрова', 'Мария', 'Александровна', 'Администратор', '2024-09-01'),
    ('T-02', 'Сидоров', 'Илья',  'Павлович',      'Кассир',        '2025-01-10');

INSERT INTO rental (rental_number, client_id, employee_id, rental_date, planned_return) VALUES
    ('R-2025-0001', 1, 1, '2025-05-01 18:20', '2025-05-03'),
    ('R-2025-0002', 2, 2, '2025-05-02 12:05', '2025-05-04'),
    ('R-2025-0003', 3, 1, '2025-05-05 19:40', '2025-05-07');

INSERT INTO rental_item (rental_id, copy_id, price_per_day, actual_return, fine_amount) VALUES
    (1, 1, 80, '2025-05-03 17:00', 0),
    (1, 4, 40, '2025-05-04 10:00', 50),
    (2, 2, 80, NULL, 0),
    (3, 5, 60, NULL, 0);

-- Проверочный запрос: кто, какой фильм и когда взял
SELECT r.rental_number, c.last_name, f.title, fc.inventory_number,
       r.rental_date, r.planned_return, ri.actual_return, ri.fine_amount
FROM rental r
JOIN client c       ON c.client_id = r.client_id
JOIN rental_item ri ON ri.rental_id = r.rental_id
JOIN film_copy fc   ON fc.copy_id = ri.copy_id
JOIN film f         ON f.film_id = fc.film_id
ORDER BY r.rental_date;
