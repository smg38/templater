# Формат .env

## Грамматика

```
line       := comment | blank | assignment
comment    := WS* '#' .*
blank      := WS*
assignment := WS* KEY WS* '=' VALUE
KEY        := [A-Za-z_][A-Za-z0-9_]*
VALUE      := bare | single_quoted | double_quoted
```

## Правила значений

| Форма | Что происходит |
|---|---|
| `KEY=value` | значение обрезается по краям |
| `KEY="a\nb"` | `\n` → перевод строки, `\t` → таб, `\"` → `"`, `\\` → `\` |
| `KEY='$x'` | буквально `$x`, без раскрытия |
| `KEY=` | пустая строка |

`$VAR`, `$(cmd)`, бэктики **не** раскрываются.

## Приоритет

Окружение процесса побеждает `.env`. Если `FOO` уже есть в окружении,
значение из `.env` не перезапишет его.

## Пример

```dotenv
# .env.example
APP_NAME=my-service
GREETING="hello world"
SECRET='s3cr3t'
INDENT=4
EMPTY=
```
