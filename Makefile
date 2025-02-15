GO111MODULE=on


CURL_BIN ?= curl
GO_BIN ?= go
GORELEASER_BIN ?= goreleaser

PUBLISH_PARAM?=
GO_MOD_PARAM?=-mod vendor
TMP_DIR?=./tmp

BASE_DIR=$(shell pwd)

NAME=httpref

export GO111MODULE=on
export GOPROXY=https://proxy.golang.org
export PATH := $(BASE_DIR)/bin:$(PATH)

.PHONY: install deps clean clean-deps test-deps build-deps deps test acceptance-test ci-test lint release update

install:
	$(GO_BIN) install -v ./cmd/$(NAME)

clean:
	rm -f ./bin/$(NAME)
	rm -rf dist/
	rm -rf cmd/$(NAME)/dist

clean-deps:
	rm -rf ./bin
	rm -rf ./tmp
	rm -rf ./libexec
	rm -rf ./share

./bin/httpref:
	$(GO_BIN) build -o ./bin/$(NAME) -v ./cmd/$(NAME)

build: ./bin/httpref

./bin/godog:
	GOBIN=$(BASE_DIR)/bin go install github.com/cucumber/godog/cmd/godog@v0.12.0

./bin/golangci-lint:
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s v1.42.1

./bin/tparse: ./bin ./tmp
	curl -sfL -o ./tmp/tparse.tar.gz https://github.com/mfridman/tparse/releases/download/v0.7.4/tparse_0.7.4_Linux_x86_64.tar.gz
	tar -xf ./tmp/tparse.tar.gz -C ./bin

test-deps: ./bin/tparse ./bin/godog ./bin/golangci-lint
	$(GO_BIN) get -v ./...
	$(GO_BIN) mod tidy

./bin:
	mkdir ./bin

./tmp:
	mkdir ./tmp

./bin/goreleaser: ./bin ./tmp
	$(CURL_BIN) --fail -L -o ./tmp/goreleaser.tar.gz https://github.com/goreleaser/goreleaser/releases/download/v0.117.2/goreleaser_Linux_x86_64.tar.gz
	gunzip -f ./tmp/goreleaser.tar.gz
	tar -C ./bin -xvf ./tmp/goreleaser.tar

build-deps: ./bin/goreleaser

deps: build-deps test-deps

test:
	$(GO_BIN) test -json ./... | tparse -all

acceptance-test:
	cd test; godog 

ci-test:
	$(GO_BIN) test -race -coverprofile=coverage.txt -covermode=atomic ./...

lint:
	golangci-lint run

release: clean
	cd cmd/$(NAME) ; $(GORELEASER_BIN) $(PUBLISH_PARAM)

update:
	$(GO_BIN) get -u
	$(GO_BIN) mod tidy
	make test
	make install
	$(GO_BIN) mod tidy
