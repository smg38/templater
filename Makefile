SHELL  := /usr/bin/env bash
SCRIPT := templater.sh
TESTS  := test/

.PHONY: all test lint syntax shellcheck install uninstall clean ci release-dry

all: lint test

run-sh:
	bash test/run.sh

test:
	bats --print-output-on-failure $(TESTS)

syntax:
	bash -n $(SCRIPT)

shellcheck:
	shellcheck --severity=warning $(SCRIPT)

lint: syntax shellcheck

ci: lint run-sh test

install:
	install -m 0755 $(SCRIPT) /usr/local/bin/templater

uninstall:
	rm -f /usr/local/bin/templater

clean:
	rm -f *.out .env.ci
	rm -rf .bats

release-dry:
	@echo "Would release version: $$(grep -m1 'v [0-9]' $(SCRIPT) | awk '{print $$2}')"
