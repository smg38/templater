#!/usr/bin/env bats

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../templater.sh"
    WORK=$(mktemp -d); cd "$WORK"
}
teardown() { cd /; rm -rf "$WORK"; }

@test "if true" {
    printf 'ENV=prod\n' > e.env
    printf '{%% if ENV == "prod" %%}P{%% endif %%}\n' > t.j3
    run bash "$SCRIPT" -e e.env -o - t.j3
    [ "$output" = "P" ]
}

@test "if false — no output" {
    printf 'ENV=dev\n' > e.env
    printf 'A{%% if ENV == "prod" %%}P{%% endif %%}B\n' > t.j3
    run bash "$SCRIPT" -e e.env -o - t.j3
    [ "$output" = "AB" ]
}

@test "else branch" {
    printf 'ENV=dev\n' > e.env
    printf '{%% if ENV == "prod" %%}P{%% else %%}D{%% endif %%}\n' > t.j3
    run bash "$SCRIPT" -e e.env -o - t.j3
    [ "$output" = "D" ]
}

@test "elif chain" {
    printf 'ENV=staging\n' > e.env
    printf '{%% if ENV == "prod" %%}P{%% elif ENV == "staging" %%}S{%% else %%}X{%% endif %%}\n' > t.j3
    run bash "$SCRIPT" -e e.env -o - t.j3
    [ "$output" = "S" ]
}

@test "numeric comparison" {
    printf 'PORT=8080\n' > e.env
    printf '{%% if PORT > 1024 %%}ok{%% endif %%}\n' > t.j3
    run bash "$SCRIPT" -e e.env -o - t.j3
    [ "$output" = "ok" ]
}

@test "and / or / not" {
    printf 'A=1\nB=0\n' > e.env
    printf '{%% if A and not B %%}yes{%% endif %%}\n' > t.j3
    run bash "$SCRIPT" -e e.env -o - t.j3
    [ "$output" = "yes" ]
}

@test "is defined" {
    printf 'SECRET=x\n' > e.env
    printf '{%% if SECRET is defined %%}has{%% endif %%}\n' > t.j3
    run bash "$SCRIPT" -e e.env -o - t.j3
    [ "$output" = "has" ]
}

@test "is not defined" {
    printf 'A=1\n' > e.env
    printf '{%% if MISSING is not defined %%}none{%% endif %%}\n' > t.j3
    run bash "$SCRIPT" -e e.env -o - t.j3
    [ "$output" = "none" ]
}

@test "is empty" {
    printf 'X=\n' > e.env
    printf '{%% if X is empty %%}empty{%% endif %%}\n' > t.j3
    run bash "$SCRIPT" -e e.env -o - t.j3
    [ "$output" = "empty" ]
}

@test "if inside for" {
    printf 'HOSTS="a b"\n' > e.env
    cat > t.j3 <<'EOF'
{% for h in HOSTS %}
{% if h == "a" %}A{% else %}B{% endif %}
{% endfor %}
EOF
    run bash "$SCRIPT" -e e.env -o - t.j3
    [ "$output" = "A
B" ]
}

@test "nested if" {
    printf 'A=1\nB=1\n' > e.env
    printf '{%% if A %%}{%% if B %%}AB{%% endif %%}{%% endif %%}\n' > t.j3
    run bash "$SCRIPT" -e e.env -o - t.j3
    [ "$output" = "AB" ]
}

@test "endif without if" {
    printf '{%% endif %%}\n' > t.j3
    run bash "$SCRIPT" -o - t.j3
    [ "$status" -ne 0 ]
    [[ "$output" == *"endif"* ]]
}

@test "if without endif" {
    printf '{%% if A %%}x\n' > t.j3
    run bash "$SCRIPT" -o - t.j3
    [ "$status" -ne 0 ]
    [[ "$output" == *"endif"* ]]
}

@test "dead branch does not invoke filters" {
    # битый base64 в невыполненной ветви не должен ломать вывод
    printf 'A=1\n' > e.env
    printf '{%% if A == "2" %%}{{ X | b64decode }}{%% endif %%}ok\n' > t.j3
    run bash "$SCRIPT" -e e.env -o - t.j3
    [ "$output" = "ok" ]
}