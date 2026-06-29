# Convenience wrapper around docker-bake.hcl. All real work happens in bake;
# Make just gives short, memorable command names.
#
# By default builds are sequenced one matrix target at a time to keep laptop
# fans alive. Set CONCURRENT=1 to fall back to bake's native parallel mode
# (all targets at once — fast on workstations, brutal on laptops).
#
#   make build                  # sequential (default)
#   CONCURRENT=1 make build     # parallel

SHELL := /usr/bin/env bash

REGISTRY   ?= puncoz
IMAGE_NAME ?= laravel-php
CONCURRENT ?= 0

# Host-arch single platform — required for `--load` (multi-arch can't load).
PLATFORM   ?= linux/$(shell uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
PLATFORMS  ?= linux/amd64,linux/arm64

BAKE := REGISTRY=$(REGISTRY) IMAGE_NAME=$(IMAGE_NAME) docker buildx bake

# Run bake against the matrix slice matching prefix laravel-$(1).
# In CONCURRENT mode this is a single bake invocation (parallel). Otherwise
# we resolve the target list from bake itself and invoke bake once per target.
#   $(1) = prefix after "laravel-" (e.g. "7-4", "8-2", empty for all)
#   $(2) = bake flags (--set ..., --load / --push, etc.)
ifeq ($(CONCURRENT),1)
define seq_bake
	$(BAKE) $(2) 'laravel-$(1)*'
endef
MODE_LABEL := concurrent (CONCURRENT=1)
else
define seq_bake
	@set -e; \
	targets=$$($(BAKE) --print 2>/dev/null \
		| python3 -c "import json,sys; print(' '.join(t for t in json.load(sys.stdin)['target'] if t.startswith('laravel-$(1)')))"); \
	if [ -z "$$targets" ]; then \
		echo "no targets match prefix 'laravel-$(1)'"; exit 1; \
	fi; \
	for t in $$targets; do \
		echo "===> $$t"; \
		$(BAKE) $(2) $$t; \
	done
endef
MODE_LABEL := sequential (default; set CONCURRENT=1 to parallelize)
endif

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show available targets
	@awk 'BEGIN{FS=":.*##"; printf "Usage: make <target>\n\nTargets:\n"} \
		/^[a-zA-Z0-9._-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' \
		$(MAKEFILE_LIST)
	@printf "\nBuild mode: %s\n" "$(MODE_LABEL)"

.PHONY: builder
builder: ## Create the multi-platform buildx builder (one-time setup)
	docker buildx create --use --name multi-platform-builder --platform $(PLATFORMS) 2>/dev/null || \
		docker buildx use multi-platform-builder
	docker buildx inspect --bootstrap

.PHONY: print
print: ## Print resolved bake targets and tags as JSON
	@$(BAKE) --print

.PHONY: login
login: ## Log in to Docker Hub
	docker login

.PHONY: build
build: ## Build all 8 images, host arch (no push)
	$(call seq_bake,,--set '*.platform=$(PLATFORM)' --load)

.PHONY: push
push: ## Build + push all 8 images, multi-arch
	$(call seq_bake,,--set '*.platform=$(PLATFORMS)' --push)

.PHONY: push-local
push-local: ## Push only tags already present in local docker (no rebuild). Use after `make build`.
	@$(BAKE) --print 2>/dev/null \
		| python3 -c "import json,sys; print('\n'.join(t for tgt in json.load(sys.stdin)['target'].values() for t in tgt['tags']))" \
		| sort -u \
		| while IFS= read -r tag; do \
			if docker image inspect "$$tag" >/dev/null 2>&1; then \
				echo ">> pushing $$tag"; \
				docker push "$$tag"; \
			else \
				echo "-- skip    $$tag (not in local docker)"; \
			fi; \
		done

# Per-PHP-version local builds: `make 8.2` -> laravel-8-2 + laravel-8-2-grpc.
.PHONY: 7.4 8.0 8.1 8.2
7.4: ## Build 7.4 + 7.4-grpc, host arch
	$(call seq_bake,7-4,--set '*.platform=$(PLATFORM)' --load)
8.0: ## Build 8.0 + 8.0-grpc, host arch
	$(call seq_bake,8-0,--set '*.platform=$(PLATFORM)' --load)
8.1: ## Build 8.1 + 8.1-grpc, host arch
	$(call seq_bake,8-1,--set '*.platform=$(PLATFORM)' --load)
8.2: ## Build 8.2 + 8.2-grpc, host arch
	$(call seq_bake,8-2,--set '*.platform=$(PLATFORM)' --load)

# Per-PHP-version push.
.PHONY: push-7.4 push-8.0 push-8.1 push-8.2
push-7.4: ## Build + push 7.4 + 7.4-grpc, multi-arch
	$(call seq_bake,7-4,--set '*.platform=$(PLATFORMS)' --push)
push-8.0: ## Build + push 8.0 + 8.0-grpc, multi-arch
	$(call seq_bake,8-0,--set '*.platform=$(PLATFORMS)' --push)
push-8.1: ## Build + push 8.1 + 8.1-grpc, multi-arch
	$(call seq_bake,8-1,--set '*.platform=$(PLATFORMS)' --push)
push-8.2: ## Build + push 8.2 + 8.2-grpc, multi-arch
	$(call seq_bake,8-2,--set '*.platform=$(PLATFORMS)' --push)

.PHONY: smoke
smoke: ## Quick single-image build to validate the bake setup (8.2 base, host arch)
	$(BAKE) --set '*.platform=$(PLATFORM)' --load laravel-8-2

.PHONY: clean
clean: ## Prune the buildx build cache
	docker buildx prune -f
