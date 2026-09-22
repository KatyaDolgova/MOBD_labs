# Лабораторная работа №1. Проектирование и создание структуры базы данных

## 1. Постановка задачи

Спроектировать и реализовать в PostgreSQL структуру базы данных маркетплейса
(сквозной кейс курса): продавцы размещают товары в каталоге, покупатели
собирают их в корзину, оформляют заказы, оплачивают и получают доставку,
оставляют отзывы. Схема должна быть приведена к третьей нормальной форме,
содержать связь «многие-ко-многим» и иерархическую самоссылку, а также
декларативные ограничения целостности.

## 2. Бизнес-правила

1. У пользователя может быть учётная запись покупателя и/или продавца;
   продавец (`sellers`) связан ровно с одним пользователем-владельцем.
2. У товара (`products`) ровно один продавец и ровно одна категория.
3. Категория (`categories`) может иметь родительскую категорию; корневые
   категории имеют `parent_id = NULL`.
4. У товара есть ровно одна запись остатков (`stock`); остаток не может быть
   отрицательным.
5. У пользователя не более одной активной корзины (`carts`); корзина состоит
   из позиций (`cart_items`), каждая — конкретный товар и количество.
6. Заказ (`orders`) принадлежит одному покупателю и содержит одну или
   несколько позиций (`order_items`); связь заказов и товаров — «многие-ко-
   многим» через `order_items`.
7. Позиция заказа фиксирует цену товара на момент покупки (`unit_price`),
   чтобы последующее изменение цены товара не искажало историю заказов.
8. Заказ может быть оплачен не более одного раза (`payments`, 1:0..1).
9. Заказ доставляется по одному адресу пользователя (`deliveries`, 1:0..1),
   адрес принадлежит конкретному пользователю (`addresses`).
10. Отзыв (`reviews`) оставляется конкретным пользователем к конкретному
    товару; один пользователь может оставить не более одного отзыва на
    товар (`UNIQUE(user_id, product_id)`).
11. Нельзя удалить продавца, пока у него есть товары; нельзя удалить товар,
    пока на него ссылаются позиции уже оформленных заказов (`ON DELETE
    RESTRICT`). Удаление заказа каскадно удаляет его позиции, оплату и
    доставку (`ON DELETE CASCADE`) — это уже не самостоятельные сущности.

## 3. Состав схемы и связи

Схема содержит 13 таблиц (сущностей), что покрывает требование «не менее
десяти сущностей»:

`users`, `sellers`, `categories`, `products`, `stock`, `carts`, `cart_items`,
`orders`, `order_items`, `payments`, `reviews`, `addresses`, `deliveries`.

Виды связей:
- **1:1 / 1:0..1** — `users`—`sellers`, `products`—`stock`, `users`—`carts`,
  `orders`—`payments`, `orders`—`deliveries`.
- **1:N** — `sellers`—`products`, `categories`—`products`, `users`—`orders`,
  `users`—`reviews`, `users`—`addresses`.
- **M:N через ассоциативную таблицу** — `carts`↔`products` (через
  `cart_items`), `orders`↔`products` (через `order_items`).
- **Иерархия (самоссылка)** — `categories.parent_id → categories.id`.

## 4. Ключи

Во всех таблицах используется **суррогатный первичный ключ**
`BIGINT GENERATED ALWAYS AS IDENTITY`: он стабилен (не зависит от бизнес-
данных, которые могут меняться — например, email или название магазина),
компактен и не требует пересмотра при изменении бизнес-правил. Исключения:
- `stock.product_id` — первичный ключ и одновременно внешний ключ,
  поскольку связь с `products` строго 1:1.
- `cart_items` и `order_items` — составной первичный ключ из пары внешних
  ключей (`cart_id, product_id` и `order_id, product_id` соответственно) —
  стандартный способ реализации ассоциативной таблицы.

Естественные кандидаты в ключи (`users.email`, `categories.name`) вынесены в
ограничения `UNIQUE`, но не используются как первичные — они могут
изменяться (email пользователя, переименование категории), тогда как
первичный ключ должен оставаться неизменным.

## 5. Нормализация: пример устранения аномалии

**До нормализации.** Если бы информация о продавце и категории хранилась
непосредственно в таблице `products` (столбцы `seller_name`, `seller_email`,
`category_name`), возникли бы аномалии:
- *вставки* — нельзя завести товар нового продавца, не продублировав его имя
  и email в каждой строке товара;
- *обновления* — при смене email продавца пришлось бы обновлять его во всех
  строках `products`, где он упоминается, рискуя рассогласовать данные, если
  обновить не все строки;
- *удаления* — при удалении последнего товара продавца терялись бы и
  сведения о самом продавце.

Причина — транзитивная зависимость: `seller_email` зависит от `seller_name`,
а не напрямую от ключа товара (`product_id`), что нарушает 3НФ.

**После нормализации.** Сведения о продавце вынесены в отдельную таблицу
`sellers` с собственным первичным ключом; `products` ссылается на неё через
`seller_id`. Аналогично для категорий (`categories`). Теперь имя и email
продавца хранятся в одном месте, изменяются одной командой `UPDATE` и не
теряются при удалении товаров.

## 6. Реализация

Схема реализована единым воспроизводимым DDL-скриптом [`schema.sql`](schema.sql):
скрипт сначала удаляет существующие объекты (`DROP TABLE IF EXISTS ... CASCADE`)
в порядке, обратном зависимостям, затем создаёт все 13 таблиц с ограничениями
`PRIMARY KEY`, `FOREIGN KEY` (с правилами `ON DELETE RESTRICT` / `CASCADE`),
`NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT`, а в конце — вспомогательные индексы
по внешним ключам.

### Как выполнить

```
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -h localhost -c "CREATE DATABASE marketplace;"
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -h localhost -d marketplace -f schema.sql
```

Либо через pgAdmin: создать базу `marketplace`, открыть Query Tool и
выполнить содержимое `schema.sql`.

Проверка результата в psql:

```
\c marketplace
\dt
\d products
```

Ожидается список из 13 таблиц и вывод структуры `products` со всеми
ограничениями (`NOT NULL`, `CHECK (price > 0)`, внешние ключи на `sellers` и
`categories`).

## 7. Словарь данных

### users
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| id | BIGINT | PK, IDENTITY | Суррогатный идентификатор пользователя |
| full_name | TEXT | NOT NULL | Полное имя |
| email | TEXT | NOT NULL, UNIQUE | Логин / контакт, уникален |
| phone | TEXT | — | Контактный телефон |
| role | TEXT | NOT NULL, CHECK ∈ {customer, seller_owner, admin} | Роль пользователя |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Дата регистрации |

### sellers
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| id | BIGINT | PK, IDENTITY | Идентификатор магазина |
| user_id | BIGINT | NOT NULL, UNIQUE, FK → users, ON DELETE CASCADE | Владелец магазина |
| store_name | TEXT | NOT NULL | Название магазина |
| description | TEXT | — | Описание магазина |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Дата регистрации продавца |

### categories
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| id | BIGINT | PK, IDENTITY | Идентификатор категории |
| parent_id | BIGINT | FK → categories, ON DELETE RESTRICT | Родительская категория (NULL — корень) |
| name | TEXT | NOT NULL, UNIQUE | Название категории |

### products
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| id | BIGINT | PK, IDENTITY | Идентификатор товара |
| seller_id | BIGINT | NOT NULL, FK → sellers, ON DELETE RESTRICT | Продавец товара |
| category_id | BIGINT | NOT NULL, FK → categories, ON DELETE RESTRICT | Категория товара |
| title | TEXT | NOT NULL | Название товара |
| description | TEXT | — | Описание |
| price | NUMERIC(12,2) | NOT NULL, CHECK (price > 0) | Цена |
| is_active | BOOLEAN | NOT NULL, DEFAULT TRUE | Активна ли карточка товара |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Дата создания карточки |

### stock
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| product_id | BIGINT | PK, FK → products, ON DELETE CASCADE | Товар |
| quantity | INTEGER | NOT NULL, DEFAULT 0, CHECK (quantity >= 0) | Остаток на складе |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Время последнего обновления остатка |

### carts
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| id | BIGINT | PK, IDENTITY | Идентификатор корзины |
| user_id | BIGINT | NOT NULL, UNIQUE, FK → users, ON DELETE CASCADE | Владелец корзины |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Дата создания корзины |

### cart_items
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| cart_id | BIGINT | PK(часть), FK → carts, ON DELETE CASCADE | Корзина |
| product_id | BIGINT | PK(часть), FK → products, ON DELETE CASCADE | Товар в корзине |
| quantity | INTEGER | NOT NULL, CHECK (quantity > 0) | Количество |

### orders
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| id | BIGINT | PK, IDENTITY | Идентификатор заказа |
| user_id | BIGINT | NOT NULL, FK → users, ON DELETE RESTRICT | Покупатель |
| status | TEXT | NOT NULL, DEFAULT 'created', CHECK ∈ {created, paid, shipped, delivered, cancelled} | Статус заказа |
| total_amount | NUMERIC(12,2) | NOT NULL, DEFAULT 0, CHECK (>= 0) | Итоговая сумма заказа |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Дата оформления |

### order_items
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| order_id | BIGINT | PK(часть), FK → orders, ON DELETE CASCADE | Заказ |
| product_id | BIGINT | PK(часть), FK → products, ON DELETE RESTRICT | Товар в заказе |
| quantity | INTEGER | NOT NULL, CHECK (quantity > 0) | Количество |
| unit_price | NUMERIC(12,2) | NOT NULL, CHECK (unit_price > 0) | Цена товара на момент заказа |

### payments
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| id | BIGINT | PK, IDENTITY | Идентификатор платежа |
| order_id | BIGINT | NOT NULL, UNIQUE, FK → orders, ON DELETE CASCADE | Оплачиваемый заказ |
| amount | NUMERIC(12,2) | NOT NULL, CHECK (amount > 0) | Сумма платежа |
| status | TEXT | NOT NULL, DEFAULT 'pending', CHECK ∈ {pending, succeeded, failed, refunded} | Статус платежа |
| paid_at | TIMESTAMPTZ | — | Время фактической оплаты |

### reviews
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| id | BIGINT | PK, IDENTITY | Идентификатор отзыва |
| user_id | BIGINT | NOT NULL, FK → users, ON DELETE CASCADE | Автор отзыва |
| product_id | BIGINT | NOT NULL, FK → products, ON DELETE CASCADE | Товар отзыва |
| score | INTEGER | NOT NULL, CHECK (score BETWEEN 1 AND 5) | Оценка |
| comment | TEXT | — | Текст отзыва |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Дата отзыва |
| — | — | UNIQUE(user_id, product_id) | Один отзыв на товар от пользователя |

### addresses
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| id | BIGINT | PK, IDENTITY | Идентификатор адреса |
| user_id | BIGINT | NOT NULL, FK → users, ON DELETE CASCADE | Владелец адреса |
| city | TEXT | NOT NULL | Город |
| street | TEXT | NOT NULL | Улица |
| house | TEXT | NOT NULL | Дом |
| apartment | TEXT | — | Квартира/офис |

### deliveries
| Столбец | Тип | Ограничения | Назначение |
|---|---|---|---|
| id | BIGINT | PK, IDENTITY | Идентификатор доставки |
| order_id | BIGINT | NOT NULL, UNIQUE, FK → orders, ON DELETE CASCADE | Доставляемый заказ |
| address_id | BIGINT | NOT NULL, FK → addresses, ON DELETE RESTRICT | Адрес доставки |
| delivery_status | TEXT | NOT NULL, DEFAULT 'pending', CHECK ∈ {pending, in_transit, delivered, returned} | Статус доставки |
| delivery_date | TIMESTAMPTZ | — | Плановая/фактическая дата доставки |
