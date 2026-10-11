RAW_VERSION ?=
ARCH ?= $(shell dpkg --print-architecture)

.PHONY: all build-release build-cli deb test-packaging
all: build-release build-cli deb
build-release:
	RAWPAIR_VERSION=$(patsubst v%,%,$(RAW_VERSION)) native/build.sh
build-cli:
	@test -n "$(RAW_VERSION)" || (echo 'Set RAW_VERSION=vMAJOR.MINOR.PATCH'; exit 1)
	mkdir -p dist
	CGO_ENABLED=0 go build -trimpath -ldflags '-s -w -X github.com/rawpair/rawpair/cli/cmd.Version=$(patsubst v%,%,$(RAW_VERSION))' -o dist/rawpair ./cli

deb:
	python3 packaging/build.py --tag '$(RAW_VERSION)' --arch '$(ARCH)'

test-packaging:
	python3 -m unittest discover -s packaging/tests -v
