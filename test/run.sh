#!/usr/bin/env bash
# test/run.sh — минимальный раннер без bats
# v 3.3.0, 2026-10-10
# Автор: @smg38
set -uo pipefail

SCRIPT="${SCRIPT:-$(cd "$(dirname "$0")/.." && pwd)/templater.sh}"
[[ -x "$SCRIPT" ]] || { echo "templater.sh не найден или не исполняем: $SCRIPT" >&2; exit 1; }

pass=0
fail=0
failed_names=()

assert_equal() {
    local name=$1 expected=$2 actual=$3
    if [[ "$expected" == "$actual" ]]; then
        printf 'PASS  %s\n' "$name"
        pass=$((pass+1))
    else
        printf 'FAIL  %s\n' "$name"
        printf '      expected: %q\n' "$expected"
        printf '      actual:   %q\n' "$actual"
        fail=$((fail+1))
        failed_names+=("$name")
    fi
}

run_case() {
    local name=$1 expected=$2; shift 2
    local envs=() tmpl="" args=()
    local seen_sep=0
    for a in "$@"; do
        if [[ "$a" == "--" ]]; then seen_sep=1; continue; fi
        if (( ! seen_sep )); then
            envs+=("$a")
        else
            if [[ -z "$tmpl" ]]; then tmpl=$a; else args+=("$a"); fi
        fi
    done

    local work; work=$(mktemp -d)
    pushd "$work" >/dev/null

    # пишем шаблон БАЙТ-В-БАЙТ, без потери кавычек
    printf '%s' "$tmpl" > t.tpl

    local actual
    actual=$(env "${envs[@]}" bash "$SCRIPT" "${args[@]}" - < t.tpl 2>/dev/null)

    popd >/dev/null
    rm -rf "$work"
    assert_equal "$name" "$expected" "$actual"
}

# --- базовые ---
run_case "simple"                 "Hello World!"             NAME=World -- 'Hello {{ NAME }}!'
run_case "undefined-empty"        "X="                       -- 'X={{ X }}'
run_case "default-applied"        "fallback"                 A= -- "{{ A | default('fallback') }}"
run_case "default-not-override"   "real"                     A=real -- "{{ A | default('fallback') }}"
run_case "default-with-spaces"    "hello world"              -- "{{ A | default('hello world') }}"
run_case "upper"                  "HELLO"                    A=hello -- '{{ A | upper }}'
run_case "lower"                  "hello"                    A=HeLLo -- '{{ A | lower }}'
run_case "trim"                   "x"                        A='  x  ' -- '{{ A | trim }}'
run_case "b64encode"              "aGVsbG8="                 A=hello -- '{{ A | b64encode }}'
run_case "b64decode"              "hello"                    A=aGVsbG8= -- '{{ A | b64decode }}'
run_case "urlencode"              "a%20b%2Fc%3Fd%26e"        A='a b/c?d&e' -- '{{ A | urlencode }}'
run_case "replace"                "bXnXnX"                   A=banana -- "{{ A | replace('a','X') }}"
run_case "substr"                 "cdef"                     A=abcdef -- '{{ A | substr(3) }}'
run_case "substr2"                "bcd"                      A=abcdef -- '{{ A | substr(2,3) }}'
run_case "sha256"                 "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" \
    A=hello -- '{{ A | sha256 }}'
run_case "md5"                    "5d41402abc4b2a76b9719d911017c592" \
    A=hello -- '{{ A | md5 }}'
run_case "hexdump"                "4142"                     A=AB -- '{{ A | hexdump }}'
run_case "two-in-line"            "A=1 B=2"                  A=1 B=2 -- 'A={{ A }} B={{ B }}'
run_case "value-with-ampersand"   "A=foo&bar"                A='foo&bar' -- 'A={{ A }}'
run_case "value-with-slash-and-brace" 'A=/a\b{c}'            A='/a\b{c}' -- 'A={{ A }}'

# --- циклы ---
run_case "loop-space"   "a;b;c;"  USERS="a b c"        -- '{% for u in USERS %}{{ u }};{% endfor %}'
run_case "loop-tabs"    "a;b;c;"  USERS=$'a\tb   c'    -- '{% for u in USERS %}{{ u }};{% endfor %}'
run_case "loop-other"   "a.prod;" USERS=a ENV=prod     -- '{% for u in USERS %}{{ u }}.{{ ENV }};{% endfor %}'
run_case "loop-filter"  "A;B;"    USERS="a b"          -- '{% for u in USERS %}{{ u | upper }};{% endfor %}'
# run_case "loop-nested"  "x1 x2 y1 y2 " OUTER="x y" INNER="1 2" \
#     -- '{% for o in OUTER %}{% for i in INNER %}{{ o }}{{ i }} {% endfor %}{% endfor %}'
run_case "loop-empty"   "AB"      USERS=               -- 'A{% for u in USERS %}X{% endfor %}B'
run_case "loop-missing" "AB"                           -- 'A{% for u in NOPE %}X{% endfor %}B'

# --- .env / автопоиск ---
test_env() {
    local name=$1 expected=$2 envbody=$3 script=$4
    local work; work=$(mktemp -d)
    pushd "$work" >/dev/null
    printf 'A={{ FOO }}\n' > file.j3
    printf '%s\n' "$envbody" > file.env
    local actual
    actual=$(env $script bash "$SCRIPT" -o - file.j3 2>/dev/null)
    popd >/dev/null
    rm -rf "$work"
    assert_equal "$name" "$expected" "$actual"
}

test_env "envfile-autoload"        "A=bar"     "FOO=bar"                     ""
test_env "envfile-inline-comment"  "A=bar"     "FOO=bar # inline comment"    ""
test_env "env-overrides-envfile"   "A=fromenv" "FOO=fromfile"                "FOO=fromenv"

# --- итог ---
echo
echo "===================="
echo "PASS: $pass"
echo "FAIL: $fail"
if (( fail > 0 )); then
    echo "Failed:"
    for n in "${failed_names[@]}"; do echo "  - $n"; done
    exit 1
fi
exit 0