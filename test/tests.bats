# --- автопоиск .env/.out ---

@test "автопоиск .env: file.j3 + file.env" {
    echo 'A={{ FOO }}' > file.j3
    echo 'FOO=bar'    > file.env
    rm -f file.out
    run bash "$SCRIPT" file.j3
    [ "$status" -eq 0 ]
    [ -f file.out ]
    [ "$(cat file.out)" = "A=bar" ]
}

@test "автопоиск .out перезаписывает существующий" {
    echo 'A={{ FOO }}' > file.j3
    echo 'FOO=bar'    > file.env
    echo 'stale'      > file.out
    run bash "$SCRIPT" file.j3
    [ "$(cat file.out)" = "A=bar" ]
}

@test "окружение перебивает .env" {
    echo 'A={{ FOO }}' > file.j3
    echo 'FOO=fromfile' > file.env
    run env FOO=fromenv bash "$SCRIPT" file.j3
    [ "$(cat file.out)" = "A=fromenv" ]
}

@test "-e отключает автопоиск .env" {
    echo 'A={{ FOO }}' > file.j3
    echo 'FOO=auto'   > file.env
    echo 'FOO=explicit' > other.env
    run bash "$SCRIPT" -e other.env file.j3
    [ "$(cat file.out)" = "A=explicit" ]
}

@test "-o отключает автопоиск .out" {
    echo 'A={{ FOO }}' > file.j3
    echo 'FOO=bar'    > file.env
    rm -f custom.out file.out
    run bash "$SCRIPT" -o custom.out file.j3
    [ -f custom.out ]
    [ ! -f file.out ]
}

@test "файл без расширения: file -> file.env / file.out" {
    echo 'A={{ FOO }}' > plain
    echo 'FOO=x'       > plain.env
    rm -f plain.out
    run bash "$SCRIPT" plain
    [ "$(cat plain.out)" = "A=x" ]
}

@test "stdin не создаёт .env/.out" {
    run bash -c "printf 'A={{ FOO }}\n' | env FOO=1 bash '$SCRIPT' -"
    [ "$status" -eq 0 ]
    [ "$output" = "A=1" ]
    [ ! -f .env ]
    [ ! -f out ]
}

@test "нет .env рядом — переменные берутся только из окружения" {
    echo 'A={{ FOO | default(\"n/a\") }}' > file.j3
    rm -f file.env file.out
    run bash "$SCRIPT" file.j3
    [ "$(cat file.out)" = "A=n/a" ]
}