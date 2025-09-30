



---

# ПРЕДМЕТНА ОБЛАСТЬ -Платформа організації музичних фестивалів — БД

## Мета і завдання

**Мета проєкту** — спроєктувати та реалізувати реляційну БД для платформи організації музичних фестивалів, яка покриває:

* управління артистами (соло та гуртами), підтипи/склад гуртів;
* фестивалі, події, майданчики та сцени;
* лайн-ап виступів, підрядників (світло/звук/сцена/піротехніка), контракти;
* волонтерські команди і призначення людей;
* менторські зв’язки між артистами.

**Завдання:**

1. Реалізувати **всю ER-модель схему** (сутності, атрибути, зв’язки 1:1, 1:M, M:N, рекурсивні, тернарний, слабкі сутності).
2. Додати принаймні **одне нестандартне обмеження тригером** (не з лекцій). У проєкті реалізовано **три** корисні тригери.

---

## Вміст репозиторію

```
 festival-db
 ├─ schema.sql   # лише структура: CREATE TABLE, ключі, індекси, тригери, функції
 ├─ seed.sql     # лише дані: INSERT-и (включно з масовим наповненням по ~500 записів)   
```


<img width="916" height="903" alt="image" src="https://github.com/user-attachments/assets/dd3bdda6-7ec1-46ed-adbe-be65281ca5dd" />


---

## Коротко про модель даних

### Сутності

* **artist**: `id`, `display_name`, `country`, `artist_type` (`solo` | `band`).
* **solo_artist** *(ISA підтип)*: `artist_id` (PK/FK), `real_name`, `birth_date`.
* **band** *(ISA підтип)*: `artist_id` (PK/FK), `formed_year`, `genre`.
* **person**: люди, які можуть бути директорами, координаторами, волонтерами.
* **organizer**: організатори фестивалів/подій.
* **equipment_provider**: підрядники (звук, сцена, тощо).
* **venue**: майданчик (арена/палац), місткість, місто.
* **stage** *(слабка сутність)*: сцена, **PK(venue_id, stage_name)**.
* **festival**: назва (UNIQUE), дати, місто, **директор (1:1 → person)**, **головний організатор (1:1 → organizer)**.
* **event**: подія фестивалю, **композитний FK на stage(venue_id, stage_name)**, дати/час, бюджет.

### Зв’язки

* **artist ↔ event** (M:N) → `artist_event` (лайн-ап).
* **event ↔ equipment_provider** (M:N) → `event_equipment_provider`.
* **band ↔ artist** (M:N) → `band_member` (склад гурту).
* **volunteer_team** *(слабка)*: **PK(festival_id, team_name)**;
  **volunteer_team ↔ person** (M:N) → `volunteer_team_person`.
* **artist ↔ artist** (M:N) → `artist_mentorship` (рекурсивне «менторство»).
* **Тернарний**: `contract(artist_id, event_id, organizer_id)` — **на кожну пару (artist,event) рівно один organizer** (PK по (artist_id, event_id)).

### Важливі обмеження та індекси

* PK/UNIQUE: композитні ключі на слабких сутностях, унікальність `festival.name`, унікальність директора та гол.організатора (1:1).
* FK з каскадною поведінкою (напр., видалення майданчика тягне сцени, тощо).
* CHECK-и на дати (`start < end`) та місткість (невід’ємна).
* Індекси: для найпоширеніших JOIN’ів (`event(festival_id)`, `event(venue_id,stage_name)`, `artist_event(event_id)` тощо).

---

## Тригери (3 шт.)

### 1) Заборона циклів у «менторстві»

* **Таблиця**: `artist_mentorship`
* **Що робить**: при вставці/оновленні перевіряє рекурсивним запитом, чи не утворюється цикл (A→…→B і B→A).
* **Навіщо**: таку перевірку неможливо реалізувати простим PK/FK/CHECK — потрібна рекурсія.
* **Повідомлення про помилку**: `Mentorship cycle detected ...`.

### 2) Анти-подвійне бронювання підрядника

* **Таблиця**: `event_equipment_provider`
* **Що робить**: якщо підрядник уже закріплений за подією, яка **перетинається в часі** з новою подією, вставка/оновлення блокується.
* **Навіщо**: запобігання конфліктам у розкладі підрядників.

### 3) Мінімальний бюджет події

* **Таблиця**: `event`
* **Що робить**: бюджет не може бути `NULL` або < **10000**.
* **Навіщо**: захист від помилкових/некоректних значень.

> Усі тригери оформлено через окремі PL/pgSQL-функції, підключені `BEFORE INSERT OR UPDATE`.

---

## Як розгорнути

### Варіант A: через `psql` (рекомендовано)

1. Створи порожню БД, наприклад `festival_db`.
2. Імпортуй схему:

   ```bash
   psql -U postgres -d festival_db -f schema.sql
   ```
3. Імпортуй дані:

   ```bash
   psql -U postgres -d festival_db -f seed.sql
   ```

### Варіант Б: через pgAdmin

* Відкрий **Query Tool** → виконай вміст `schema.sql`, далі `seed.sql`.

---

## Приклади запитів

### Хто де і коли виступає

```sql
SELECT f.name      AS festival,
       e.title     AS event,
       v.name      AS venue,
       e.stage_name,
       a.display_name AS artist,
       e.start_datetime, e.end_datetime
FROM event e
JOIN festival f ON f.id = e.festival_id
JOIN venue v    ON v.id = e.venue_id
JOIN artist_event ae ON ae.event_id = e.id
JOIN artist a   ON a.id = ae.artist_id
ORDER BY e.start_datetime, a.display_name;
```

### Підрядники по подіях

```sql
SELECT e.title, p.company_name, p.service_type
FROM event_equipment_provider ep
JOIN event e ON e.id = ep.event_id
JOIN equipment_provider p ON p.id = ep.provider_id
ORDER BY e.id, p.company_name;
```

### Волонтери з командами

```sql
SELECT f.name AS festival, vtp.team_name, pr.full_name, vtp.role_in_team
FROM volunteer_team_person vtp
JOIN volunteer_team vt ON (vt.festival_id, vt.team_name) = (vtp.festival_id, vtp.team_name)
JOIN festival f ON f.id = vt.festival_id
JOIN person pr ON pr.id = vtp.person_id
ORDER BY f.name, vtp.team_name, pr.full_name;
```

### Перевірка тригера «менторство» (має впасти з помилкою циклу)

```sql
-- Припустимо, що існує зв’язок (1 -> 4)
-- Тоді наступний INSERT створює цикл і буде заблокований:
-- INSERT INTO artist_mentorship(mentor_id, mentee_id, since_date)
-- VALUES (4, 1, CURRENT_DATE);
```

---

## Масове наповнення

У `seed.sql` є генератори, що додають **~500 записів** у більшість таблиць (артістів, подій, команд, контрактів тощо). Вони написані так, щоб:

* поважати всі FK/UNIQUE/тригери;
* працювати ідемпотентно (`ON CONFLICT DO NOTHING`);
* не створювати перетинів часу для підрядників (тригер підстрахує).

---

## Нетривіальні рішення

* **ISA** реалізовано «по-класиці»: `artist` як узагальнення, а `solo_artist` і `band` — підтипи з PK=FK.
* **Слабкі сутності** (`stage`, `volunteer_team`) мають **складені PK** та `ON DELETE CASCADE` від «батьків».
* **Тернарний зв’язок** — окремою таблицею `contract` з PK по `(artist_id, event_id)` (один організатор на пару).
* **Композитний FK** `event(venue_id,stage_name)` → `stage(...)` гарантує, що подія завжди «проводиться» на конкретній сцені конкретного майданчика.


---

## Як відтворити дамп самостійно (опціонально)

У pgAdmin: **Backup → Format: Plain → Only schemas** → `schema.sql`, потім **Only data** → `seed.sql`.

---



