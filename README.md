# templater

[![CI](https://github.com/OWNER/REPO/actions/workflows/test.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/test.yml)
[![ShellCheck](https://img.shields.io/badge/shellcheck-passing-brightgreen)](https://www.shellcheck.net/)
[![Bats](https://img.shields.io/badge/tests-bats-blue)](https://github.com/bats-core/bats-core)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-3.4.0-blue.svg)](CHANGELOG.md)

Простой шаблонизатор для подстановки переменных окружения в текстовые
файлы. Поддерживает модификаторы (фильтры), автозагрузку `.env` и
автозапись `.out`. Не требует Python, Node.js или Jinja2 — только
POSIX-совместимые `bash`, `awk` и `coreutils`.

---

## Содержание

- [templater](#templater)
  - [Содержание](#содержание)
  - [Возможности](#возможности)
  - [Установка](#установка)
    - [Из репозитория](#из-репозитория)
    - [Вручную](#вручную)
    - [Требования](#требования)
  - [Быстрый старт](#быстрый-старт)
  - [Синтаксис шаблонов](#синтаксис-шаблонов)
    - [Циклы](#циклы)
      - [Простой цикл](#простой-цикл)
    - [Условия](#условия)
    - [Динамические имена переменных](#динамические-имена-переменных)
  - [Фильтры](#фильтры)
  - [`{{ SECRET | default('') | b64encode }}`.](#-secret--default--b64encode-)
  - [Файл переменных `.env`](#файл-переменных-env)
  - [Автопоиск `.env` и `.out`](#автопоиск-env-и-out)
  - [Ключи командной строки](#ключи-командной-строки)
  - [Приоритеты](#приоритеты)
  - [Примеры](#примеры)
    - [Базовая подстановка](#базовая-подстановка)
    - [Окружение перебивает `.env`](#окружение-перебивает-env)
    - [Явные `-e` / `-o`](#явные--e---o)
    - [stdin → stdout](#stdin--stdout)
    - [Strict-режим в CI](#strict-режим-в-ci)
  - [Безопасность](#безопасность)
  - [Разработка](#разработка)
    - [Локальные хуки (pre-commit)](#локальные-хуки-pre-commit)
  - [Тестирование](#тестирование)
  - [CI](#ci)
  - [Ограничения](#ограничения)
  - [FAQ](#faq)
  - [Лицензия](#лицензия)

---

## Возможности

- циклы `{% for VAR in LIST %} ... {% endfor %}` с динамическими
  именами переменных: `{{ UUID_A_{{ user }} }}`;
- условия `{% if COND %} ... {% elif %} ... {% else %} ... {% endif %}`
  с операторами `==`, `!=`, `>`, `<`, `>=`, `<=`, `and`, `or`, `not`,
  `is [not] defined`, `is empty`; поддерживают вложенность и работу
  внутри циклов;
- `{{ VAR }}` — подстановка переменных окружения;
- фильтры-цепочки: `{{ VAR | lower | replace('-','_') | upper }}`;
- `default(...)` — значение по умолчанию;
- кодирование и хеширование: `b64encode`, `b64decode`, `sha256`, `md5`, `hexdump`, `urlencode`;
- строковые операции: `upper`, `lower`, `trim`, `quote`, `replace`, `substr`, `indent`;
- автопоиск `<template>.env` и запись результата в `<template>.out`;
- strict-режим `-s` для CI;
- чтение шаблона из stdin (`-`) и запись в stdout;
- **без `eval`** — значения переменных не исполняются как shell-код.

---

## Установка

### Из репозитория

```bash
git clone https://github.com/OWNER/REPO.git templater
cd templater
make install           # копирует templater.sh в /usr/local/bin/templater
```

### Вручную

```bash
chmod +x templater.sh
sudo ln -s "$PWD/templater.sh" /usr/local/bin/templater
```

### Требования

- `bash >= 4.0`
- `awk` (проверено на `gawk`, `mawk`, `busybox awk`)
- `coreutils`: `base64`, `sha256sum`/`shasum`, `md5sum`/`md5`, `od`, `tr`, `cut`
- опционально: `bats-core` — для тестов

---

## Быстрый старт

`config.j3`:

```jinja
app: {{ APP_NAME | upper }}
greeting: {{ GREETING | default('hello') | quote }}
url: https://example.com/?q={{ GREETING | urlencode }}
token: {{ SECRET | b64encode }}
```

`config.env`:

```dotenv
APP_NAME=my-service
GREETING="hello world"
SECRET='s3cr3t'
```

Запуск:

```bash
templater config.j3
```

Результат — `config.out`:

```yaml
app: MY-SERVICE
greeting: 'hello world'
url: https://example.com/?q=hello%20world
token: czNjcjN0
```

---

## Синтаксис шаблонов

```
{{ VAR }}
{{ VAR | filter }}
{{ VAR | filter1 | filter2 | ... }}
```

Правила:

- имя переменной: `[A-Za-z_][A-Za-z0-9_]*`;
- между `{{` и именем допускаются пробелы;
- фильтры разделяются `|`, аргументы — в скобках, в одинарных или двойных кавычках;
- несколько плейсхолдеров в одной строке поддерживаются;
- неизвестный фильтр молча игнорируется;
- отсутствие переменной без `default(...)` → пустая строка + warning в stderr.

### Циклы

```
{% for VAR in LIST %}
  ...
{% endfor %}
```

- `LIST` — имя переменной окружения; значение делится на элементы по
  **одному или нескольким пробелам, табам или `\r`**;
- внутри тела доступны:
  - `{{ VAR }}` — текущий элемент (с фильтрами);
  - любые другие переменные окружения — как обычно;
- циклы **нельзя вкладывать** (один уровень);
- пустой или отсутствующий список → 0 итераций.

#### Простой цикл

```jinja
# {{ ENV }} cluster
{% for h in HOSTS %}
- host: {{ h | upper }}
  url: https://{{ h }}.{{ ENV }}/
{% endfor %}
```

```dotenv
HOSTS="alpha beta gamma"
ENV=prod
```

### Условия

```jinja
{% if COND %} ... {% elif COND %} ... {% else %} ... {% endif %}
```

- `COND` — выражение: `VAR`, `VAR == "value"`, `PORT > 1024`,
  `A and not B`, `SECRET is defined`, `GREETING is empty`;
- операнды: имя переменной, имя итератора, строка в `'...'`/`"..."`,
  число, литералы `true`/`false`/`empty`;
- `if` **вкладывается** и работает **внутри** `{% for %}`;
- невыполненные ветви полностью пропускаются (фильтры не вызываются).

Подробности: [docs/conditionals.md](docs/conditionals.md).


### Динамические имена переменных

Внутри `{{ ... }}` можно использовать другой плейсхолдер — он подставится
раньше, чем имя переменной будет найдено:

```jinja
users:
{% for user in USERS %}
      - username: {{ user }}
        uuid: "{{ UUID_A_{{ user }} }}"
        flow: {{ FLOW_USERS }}
{% endfor %}
```

```dotenv
USERS="user1 user2"
UUID_A_user1="aaaa-1111"
UUID_A_user2="bbbb-2222"
FLOW_USERS=xtls-rprx-vision
```

Результат:

```yaml
users:
      - username: user1
        uuid: "aaaa-1111"
        flow: xtls-rprx-vision
      - username: user2
        uuid: "bbbb-2222"
        flow: xtls-rprx-vision
```

---

## Фильтры

| Фильтр | Аргументы | Пример |
|---|---|---|
| `default('V')` | строка | `{{ X \| default('n/a') }}` |
| `upper` / `lower` | — | `hello` → `HELLO` / `hello` |
| `trim` | — | `"  x  "` → `x` |
| `quote` | — | `it's` → `'it'\''s'` |
| `b64encode` / `b64decode` | — | `hi` → `aGk=` / обратно |
| `urlencode` | — | `a b/c` → `a%20b%2Fc` |
| `sha256` / `md5` | — | hex-дайджест |
| `hexdump` | — | `AB` → `4142` |
| `replace('A','B')` | две строки | `banana` → `bXnXnX` |
| `substr(N)` / `substr(N,M)` | числа | `abcdef`, 3 → `cdef` |
| `indent(N)` | число | сдвиг каждой строки на N пробелов |

Цепочки:

```jinja
{{ NAME | lower | replace('-','_') | upper }}
{{ TOKEN | default('x') | b64encode | sha256 }}
```
Фильтры можно использовать в любой выполняемой ветке `{% if %}`:
`{{ SECRET | default('') | b64encode }}`.
---

## Файл переменных `.env`

```dotenv
# комментарий
KEY=value
EMPTY=
WITH_SPACES="hello world"
LITERAL='$not_expanded'
MULTILINE="line1\nline2"
```

- `$VAR` **не** раскрывается (безопасность);
- переменные окружения процесса имеют приоритет над `.env`;
- для секретов: `chmod 600 *.env` и добавить `*.env` в `.gitignore`.

---

## Автопоиск `.env` и `.out`

При запуске `templater config.j3`:

1. если рядом есть `config.env` — загружается;
2. если `-o` не указан — результат пишется в `config.out`.

| Шаблон | Авто `.env` | Авто `.out` |
|---|---|---|
| `file.j3` | `file.env` | `file.out` |
| `dir/file.tpl` | `dir/file.env` | `dir/file.out` |
| `file` (без расширения) | `file.env` | `file.out` |
| `-` (stdin) | — | stdout |

---

## Ключи командной строки

| Ключ | Описание |
|---|---|
| `-e ENVFILE` | загрузить переменные из ENVFILE; можно указывать несколько раз (отключает автопоиск `.env`) |
| `-o OUTPUT` | записать результат в OUTPUT (отключает автопоиск `.out`) |
| `-s` | strict: ошибка, если переменная не определена и нет `default` |
| `-h` | справка |

---

## Приоритеты

**Источники переменных** (высший → низший):

1. окружение процесса (`FOO=bar templater ...`);
2. `-e ENVFILE` — если указано несколько, они применяются слева направо,
   переменные из более позднего файла не перезаписывают уже установленные
   (как и в случае с `.env`);
3. `<template>.env` (автопоиск).

**Источники вывода:**

1. `-o OUTPUT`;
2. `<template>.out`;
3. stdout (только для stdin-шаблона).

---

## Примеры

### Базовая подстановка

```bash
echo 'Hello {{ NAME }}!' > hello.j3
echo 'NAME=World' > hello.env
templater hello.j3
cat hello.out          # Hello World!
```

### Окружение перебивает `.env`

```bash
NAME=Override templater hello.j3
cat hello.out          # Hello Override!
```

### Явные `-e` / `-o`

```bash
templater -e prod.env -o /etc/app/config.yml config.j3
```
Несколько env-файлов применяются слева направо; при конфликте выигрывает
первое определение:
```bash
templater -e defaults.env -e prod.env config.j3
```


### stdin → stdout

```bash
printf 'Hi {{ N }}\n' | N=you templater -
# Hi you
```

### Strict-режим в CI

```bash
templater -s config.j3 || exit $?
```

---

## Безопасность

- Скрипт **не использует `eval`** — значения переменных не исполняются.
- Значения передаются во внешние утилиты через `printf %s '...'` с корректным shell-квотингом.
- Имя файла-шаблона не попадает в `eval`.
- `.env` не раскрывает `$VAR`, `$(...)`, бэктики.
- Подробности: [docs/security.md](docs/security.md).

---

## Разработка

```bash
git clone https://github.com/OWNER/REPO.git
cd templater
make ci            # lint + bats
```

### Локальные хуки (pre-commit)

```bash
pip install pre-commit
pre-commit install
```

С этого момента при `git commit` будут прогоняться shellcheck, bats и
стандартные проверки (trailing whitespace, EOF, YAML).

---

## Тестирование

```bash
make test           # bats --print-output-on-failure test/
make lint           # bash -n + shellcheck
make ci             # всё сразу
```

Тесты лежат в `test/`:

- `templater.bats` — базовая функциональность;
- `filters.bats` — все фильтры;
- `envfile.bats` — `.env`, `-e`, приоритеты;
- `integration.bats` — end-to-end сценарии.

---

## CI

GitHub Actions прогоняет на каждый push и pull request:

- **lint** — `bash -n` + `shellcheck`;
- **test** — bats на Ubuntu и macOS;
- **integration** — end-to-end с `.j3` + `.env` → `.out`;
- **awk-matrix** — совместимость с `gawk`, `mawk`, `busybox awk` (опционально).

Конфигурация: [.github/workflows/test.yml](.github/workflows/test.yml).

---

## Ограничения

- Циклы `{% for %}` не вкладываются (один уровень).
- Условия поддерживают только плоские переменные и перечисленные
  операторы; нет атрибутов (`user.name`), вызовов функций и тернарника.
- Нет вложенных плейсхолдеров, кроме случая динамического имени
  переменной внутри `{{ ... }}` (см. «Циклы»).
- `replace('A','B')` — аргументы режутся по запятой.
- Один проход; результат не переобрабатывается.
- Зависит от POSIX `awk` (проверено на gawk, mawk, busybox awk).

---

## FAQ

**Q: Чем отличается от `envsubst`?**
A: `envsubst` умеет только `$VAR`/`${VAR}`. Здесь — `{{ VAR }}`, фильтры,
`default(...)`, автопоиск `.env`/`.out`, strict-режим, безопасность без `eval`.

**Q: Почему результат пишется в `file.out`, а не в stdout?**
A: Чтобы `templater config.j3` была идемпотентной командой без пайпов.
Нужен stdout — используйте шаблон `-` или `-o /dev/stdout`.

**Q: `.env` не подхватился. Почему?**
A: Проверьте, что имена совпадают (`file.j3` ↔ `file.env`) и что не передан `-e`.

**Q: Как добавить свой фильтр?**
A: Добавьте `f_имя(v, arg)` в awk-блок `templater.sh` и ветку в `apply_filter`.
Подробности: [docs/filters.md](docs/filters.md).

---

## Лицензия

MIT. См. [LICENSE](LICENSE).
