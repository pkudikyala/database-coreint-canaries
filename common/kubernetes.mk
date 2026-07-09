CANARY = $(shell basename $(CURDIR))
ENVIRONMENT ?= default

NRIA_LICENSE_KEY       := ${NRIA_LICENSE_KEY}

ifeq ($(ENVIRONMENT),stable)
    NRIA_LICENSE_KEY := $(NRIA_LICENSE_KEY_STABLE)
endif
ifeq ($(ENVIRONMENT),candidate)
    NRIA_LICENSE_KEY := $(NRIA_LICENSE_KEY_CANDIDATE)
endif

NEWRELIC_OTLP_ENDPOINT := ${NEWRELIC_OTLP_ENDPOINT}

SKIP_MINIKUBE := ""

# Determine namespace and release name based on environment
ifeq "$(ENVIRONMENT)" "default"
    NAMESPACE = can-$(CANARY)
    RELEASE_NAME = $(CANARY)
    OTEL_FILES_TO_FIND := $(shell git rev-parse --show-toplevel)/common/otel-collector-values.yaml otel-collector-values.yaml values.yaml
    VALUE_FILES := $(foreach file,$(wildcard $(OTEL_FILES_TO_FIND)),-f $(file)) -f $(shell git rev-parse --show-toplevel)/common/values-$(ENVIRONMENT).yaml
else
    NAMESPACE = can-$(CANARY)-$(ENVIRONMENT)
    RELEASE_NAME = $(CANARY)-$(ENVIRONMENT)
    OTEL_FILES_TO_FIND := $(shell git rev-parse --show-toplevel)/common/otel-collector-values.yaml otel-collector-values.yaml values.yaml
    VALUE_FILES := $(foreach file,$(wildcard $(OTEL_FILES_TO_FIND)),-f $(file)) -f $(shell git rev-parse --show-toplevel)/common/values-$(ENVIRONMENT).yaml
endif

.PHONY: canary-up
canary-up:
ifeq "$(NRIA_LICENSE_KEY)" ""
	@echo "The environment variable for NRIA_LICENSE_KEY is empty and is needed to create the secret needed"; exit 1
endif
ifeq "$(NEWRELIC_OTLP_ENDPOINT)" ""
	@echo "The environment variable for NEWRELIC_OTLP_ENDPOINT is empty and is needed to create the secret needed"; exit 1
endif

ifeq "$(SKIP_MINIKUBE)" ""
	@echo " ==> Starting minikube"
	minikube start
endif
	@echo " ==> Creating canary's namespace: $(NAMESPACE)"
	kubectl create ns "$(NAMESPACE)" || true
	@echo " ==> Creating the secret with the licenses"
	kubectl -n "$(NAMESPACE)" create secret generic newrelic-licenses \
		--dry-run=client -o yaml \
		--type=string \
		--from-literal="NRIA_LICENSE_KEY=$(NRIA_LICENSE_KEY)" \
		--from-literal="NEWRELIC_OTLP_ENDPOINT=$(NEWRELIC_OTLP_ENDPOINT)" \
		| kubectl apply -n "$(NAMESPACE)" -f -
	@echo " ==> Building Helm dependencies"
	helm dependency build
	@echo " ==> Installing Helm chart: $(RELEASE_NAME) in $(NAMESPACE)"
	helm upgrade --install -n "$(NAMESPACE)" "$(RELEASE_NAME)" . $(VALUE_FILES) --set environment=$(ENVIRONMENT)

.PHONY: canary-down
canary-down:
	@echo " ==> Uninstalling Helm chart: $(RELEASE_NAME) from $(NAMESPACE)"
	helm uninstall -n "$(NAMESPACE)" "$(RELEASE_NAME)" || true
	@echo " ==> Deleting namespace: $(NAMESPACE)"
	kubectl delete ns "$(NAMESPACE)" || true

.PHONY: canary-up-stable
canary-up-stable:
	$(MAKE) canary-up ENVIRONMENT=stable

.PHONY: canary-up-candidate
canary-up-candidate:
	$(MAKE) canary-up ENVIRONMENT=candidate

.PHONY: canary-down-stable
canary-down-stable:
	$(MAKE) canary-down ENVIRONMENT=stable

.PHONY: canary-down-candidate
canary-down-candidate:
	$(MAKE) canary-down ENVIRONMENT=candidate

.PHONY: canary-up-dual
canary-up-dual: canary-up-stable canary-up-candidate

.PHONY: canary-down-dual
canary-down-dual: canary-down-stable canary-down-candidate

.PHONY: canary-status
canary-status:
	@echo "==> Checking canary deployments..."
	@echo "Default environment:"
	kubectl get pods -n can-$(CANARY) 2>/dev/null || echo "  No default deployment found"
	@echo "Stable environment:"
	kubectl get pods -n can-$(CANARY)-stable 2>/dev/null || echo "  No stable deployment found"
	@echo "Candidate environment:"
	kubectl get pods -n can-$(CANARY)-candidate 2>/dev/null || echo "  No candidate deployment found"