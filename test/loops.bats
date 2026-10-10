#!/usr/bin/env bats

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../templater.sh"
    WORK=$(mktemp -d); cd "$WORK"
}
teardown() { cd /; rm -rf "$WORK"; }

@test "list by spaces" {
    printf 'USERS="alice bob carol"\n' > u.env
    printf '{%% for u in USERS %%}{{ u }};{%% endfor %%}\n' > u.j3
    run bash "$SCRIPT" -e u.env -o - u.j3
    [ "$output" = "alice;bob;carol;" ]
}

@test "list by tabs and multiple spaces" {
    printf 'USERS="a\t\tb   c"\n' > u.env
    printf '{%% for u in USERS %%}{{ u }};{%% endfor %%}\n' > u.j3
    run bash "$SCRIPT" -e u.env -o - u.j3
    [ "$output" = "a;b;c;" ]
}

@test "filters on element" {
    printf 'USERS="alice bob"\n' > u.env
    printf '{%% for u in USERS %%}{{ u | upper }};{%% endfor %%}\n' > u.j3
    run bash "$SCRIPT" -e u.env -o - u.j3
    [ "$output" = "ALICE;BOB;" ]
}

@test "other vars inside loop" {
    printf 'USERS="a b"\n' > u.env
    printf 'ENV=prod\n' >> u.env
    printf '{%% for u in USERS %%}{{ u }}.{{ ENV }};{%% endfor %%}\n' > u.j3
    run bash "$SCRIPT" -e u.env -o - u.j3
    [ "$output" = "a.prod;b.prod;" ]
}

@test "other vars and filters inside loop" {
    printf 'USERS="a b"\nENV=prod\n' > u.env
    printf '{%% for u in USERS %%}{{ u | upper }}-{{ ENV | upper }};{%% endfor %%}\n' > u.j3
    run bash "$SCRIPT" -e u.env -o - u.j3
    [ "$output" = "A-PROD;B-PROD;" ]
}

@test "empty list" {
    printf 'USERS=""\n' > u.env
    printf 'A{%% for u in USERS %%}X{%% endfor %%}B\n' > u.j3
    run bash "$SCRIPT" -e u.env -o - u.j3
    [ "$output" = "AB" ]
}

@test "missing list" {
    printf 'A{%% for u in NOPE %%}X{%% endfor %%}B\n' > u.j3
    run bash "$SCRIPT" -o - u.j3
    [ "$output" = "AB" ]
}

@test "multiline loop body" {
    printf 'HOSTS="a b"\nENV=prod\n' > h.env
    cat > h.j3 <<'EOF'
{% for h in HOSTS %}
- host: {{ h }}
  env: {{ ENV }}
{% endfor %}
EOF
    run bash "$SCRIPT" -e h.env -o - h.j3
    [ "$output" = "- host: a
  env: prod
- host: b
  env: prod" ]
}

@test "endfor without for" {
    printf 'A{%% endfor %%}B\n' > t.j3
    run bash "$SCRIPT" -o - t.j3
    [ "$status" -ne 0 ]
    [[ "$output" == *"endfor"* ]]
}

@test "for without endfor" {
    printf 'A{%% for x in Y %%}B\n' > t.j3
    run bash "$SCRIPT" -o - t.j3
    [ "$status" -ne 0 ]
    [[ "$output" == *"for"* ]]
}

@test "dynamic variable name" {
    printf 'USERS="user1 user2"\nUUID_A_user1="aaaa-1111"\nUUID_A_user2="bbbb-2222"\nFLOW=xtls\n' > u.env
    cat > u.j3 <<'EOF'
users:
{% for user in USERS %}
      - username: {{ user }}
        uuid: "{{ UUID_A_{{ user }} }}"
        flow: {{ FLOW }}
{% endfor %}
EOF
    run bash "$SCRIPT" -e u.env -o - u.j3
    [ "$status" -eq 0 ]
    [ "$output" = 'users:
      - username: user1
        uuid: "aaaa-1111"
        flow: xtls
      - username: user2
        uuid: "bbbb-2222"
        flow: xtls' ]
}