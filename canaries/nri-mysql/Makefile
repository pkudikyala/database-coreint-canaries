CANARY     = nri-mysql
ENVIRONMENT ?= default

NRIA_LICENSE_KEY := ${NRIA_LICENSE_KEY}
ifeq ($(ENVIRONMENT),stable)
	NRIA_LICENSE_KEY := $(NRIA_LICENSE_KEY_STABLE)
endif
ifeq ($(ENVIRONMENT),candidate)
	NRIA_LICENSE_KEY := $(NRIA_LICENSE_KEY_CANDIDATE)
endif

SKIP_MINIKUBE := ""

ifeq "$(ENVIRONMENT)" "default"
	NAMESPACE    = can-$(CANARY)
	RELEASE_NAME = $(CANARY)
	VALUE_FILES  = -f values.yaml
else
	NAMESPACE    = can-$(CANARY)-$(ENVIRONMENT)
	RELEASE_NAME = $(CANARY)-$(ENVIRONMENT)
	VALUE_FILES  = -f values.yaml -f values-$(ENVIRONMENT).yaml
endif

.PHONY: canary-up
canary-up:
ifeq "$(NRIA_LICENSE_KEY)" ""
	@echo "NRIA_LICENSE_KEY is empty"; exit 1
endif
ifeq "$(SKIP_MINIKUBE)" ""
	minikube start
endif
	@echo " ==> Creating namespace: $(NAMESPACE)"
	kubectl create ns "$(NAMESPACE)" || true
	@echo " ==> Creating secret"
	kubectl -n "$(NAMESPACE)" create secret generic newrelic-licenses-$(ENVIRONMENT) \
		--dry-run=client -o yaml \
		--type=string \
		--from-literal="NRIA_LICENSE_KEY=$(NRIA_LICENSE_KEY)" \
		| kubectl apply -n "$(NAMESPACE)" -f -
	@echo " ==> Adding NR Helm repo"
	helm repo add newrelic https://helm-charts.newrelic.com || true
	helm repo update
	@echo " ==> Building Helm dependencies"
	helm dependency build
	@echo " ==> Installing: $(RELEASE_NAME) in $(NAMESPACE)"
	helm upgrade --install -n "$(NAMESPACE)" "$(RELEASE_NAME)" . $(VALUE_FILES) \
		--set environment=$(ENVIRONMENT)

.PHONY: canary-down
canary-down:
	helm uninstall -n "$(NAMESPACE)" "$(RELEASE_NAME)" || true
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
	@echo "==> Stable:"
	kubectl get pods -n can-$(CANARY)-stable 2>/dev/null || echo "  No stable deployment found"
	@echo "==> Candidate:"
	kubectl get pods -n can-$(CANARY)-candidate 2>/dev/null || echo "  No candidate deployment found"
