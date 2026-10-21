# Условия `{% if %}`

## Синтаксис

```
{% if CONDITION %}
  ...
{% elif CONDITION %}
  ...
{% else %}
  ...
{% endif %}
```

- `elif` и `else` опциональны, `endif` обязателен.
- Вложенность `if` **поддерживается** (в отличие от `for`).
- `if` работает **внутри** тела `{% for %}` и наоборот.

## Операторы

| Оператор | Пример | Семантика |
|---|---|---|
| `==`, `!=` | `{% if ENV == "prod" %}` | равенство строк/чисел |
| `>`, `<`, `>=`, `<=` | `{% if PORT > 1024 %}` | числовое, если обе стороны — числа, иначе лексикографическое |
| `and`, `or` | `{% if A and B %}` | логические, ленивые |
| `not` | `{% if not DEBUG %}` | отрицание |
| `is defined` | `{% if SECRET is defined %}` | истина, если переменная задана |
| `is not defined` | `{% if X is not defined %}` | отрицание предыдущего |
| `is empty` | `{% if GREETING is empty %}` | пустая строка / не задана |

### Truthiness

Без оператора значение считается истинным, если оно непустое и не равно
`0` или `false` (строка):

```jinja
{% if DEBUG %}verbose mode{% endif %}
```

## Операнды

- имя переменной: `ENV`, `APP_NAME`, `UUID_A_user1`;
- имя итератора цикла: `user`, `h`;
- строка в кавычках: `'prod'`, `"hello world"`;
- число: `8080`, `-1`, `3.14`;
- литералы: `true`, `false`, `empty`.

## Примеры

### Простое условие

```jinja
{% if ENV == "prod" %}
log_level: warning
{% else %}
log_level: debug
{% endif %}
```

### Проверка наличия секрета

```jinja
{% if SECRET is defined %}
token: {{ SECRET | b64encode }}
{% else %}
token: null
{% endif %}
```

### Числовое сравнение

```jinja
{% if PORT > 1024 %}
port: {{ PORT }}
{% else %}
port: 8080   # привилегированные порты запрещены
{% endif %}
```

### Логика

```jinja
{% if ENV == "prod" and not DEBUG %}
replicas: 3
{% elif ENV == "staging" %}
replicas: 1
{% else %}
replicas: 1
{% endif %}
```

### Внутри цикла

```jinja
{% for h in HOSTS %}
- host: {{ h }}
{% if h == "alpha" %}
  role: primary
{% else %}
  role: replica
{% endif %}
{% endfor %}
```

### Вложенные if

```jinja
{% if ENV == "prod" %}
{% if SECRET is defined %}
  secure: yes
{% else %}
  secure: no   # прод без секрета — ошибка конфигурации!
{% endif %}
{% endif %}
```

## Ограничения

- Нет доступа к атрибутам (`user.name`) — только плоские переменные.
- Нет вызовов функций в условии (`length(x)`, `x.startswith(...)`).
- Нет тернарного оператора в `{{ ... }}` — используйте `default(...)`.
- Аргументы `is` ограничены `defined` / `empty`.
- Сравнение `>`/`<` между строками — лексикографическое (как `[[ a < b ]]` в bash).

## Ошибки

| Ситуация | Поведение |
|---|---|
| `{% if %}` без `{% endif %}` | ошибка, код 2 |
| `{% endif %}` без `{% if %}` | ошибка, код 2 |
| `{% elif %}` без `{% if %}` | ошибка, код 2 |
| `{% if %}` с пустым условием | ошибка, код 2 |