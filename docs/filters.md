# Фильтры — детали

## Синтаксис аргументов

- `filter` — без скобок;
- `filter(arg)` — один аргумент;
- `filter(a, b)` — два аргумента, разделитель — запятая;
- аргументы в одинарных (`'`) или двойных (`"`) кавычках; кавычки снимаются.

## Таблица

| Фильтр | Аргументы | Реализация | Замечание |
|---|---|---|---|
| `default` | строка | awk | срабатывает, только если значение пусто |
| `upper` / `lower` | — | awk `toupper`/`tolower` | ASCII |
| `trim` | — | awk `sub` | пробелы, табы, `\r`, `\n` |
| `quote` | — | awk | shell-safe: `'it'\''s'` |
| `b64encode` | — | `base64 \| tr -d '\n'` | без переносов |
| `b64decode` | — | `base64 -d` | ошибки → пусто |
| `urlencode` | — | awk | RFC 3986 (unreserved: `A-Za-z0-9._~-`) |
| `sha256` | — | `sha256sum`/`shasum` | hex |
| `md5` | — | `md5sum`/`md5` | hex |
| `hexdump` | — | `od -An -v -tx1` | без разделителей |
| `replace` | две строки | awk `gsub` | regex-aware |
| `substr` | 1 или 2 числа | awk `substr` | 1-based |
| `indent` | число | awk | добавляет N пробелов в начало каждой строки |

## Примеры

```jinja
{{ PASSWORD | default('changeme') }}
{{ USERNAME | lower | replace(' ','_') }}
{{ API_KEY | sha256 | substr(1, 16) }}
{{ CERT | indent(4) }}
```
