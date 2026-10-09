#!/usr/bin/env bats
# базовая функциональность — добавьте тесты из предыдущей итерации

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../templater.sh"
    WORK=$(mktemp -d); cd "$WORK"
}
teardown() { cd /; rm -rf "$WORK"; }

@test "placeholder" {
    echo 'Hello {{ NAME }}!' > t.tpl
    run env NAME=World bash "$SCRIPT" -o - t.tpl
    [ "$output" = "Hello World!" ]
}
