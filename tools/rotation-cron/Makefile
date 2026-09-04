NAMESPACE    = tools-rotation-cron
RELEASE_NAME = rotation-cron

GIT_TOKEN := ${GIT_TOKEN}

.PHONY: rotation-cron-up
rotation-cron-up:
ifeq "$(GIT_TOKEN)" ""
	@echo "GIT_TOKEN is empty -- export it first, e.g.:"; \
	 echo "  export GIT_TOKEN=\$$(newrelic-vault us read terraform/data-integrations/production/a2q-common/GIT_TOKEN -field=value)"; \
	 exit 1
endif
	@echo " ==> Creating namespace: $(NAMESPACE)"
	kubectl create ns "$(NAMESPACE)" || true
	@echo " ==> Creating secret"
	kubectl -n "$(NAMESPACE)" create secret generic rotation-git-token \
		--dry-run=client -o yaml \
		--from-literal="GIT_TOKEN=$(GIT_TOKEN)" \
		| kubectl apply -n "$(NAMESPACE)" -f -
	@echo " ==> Installing: $(RELEASE_NAME) in $(NAMESPACE)"
	helm upgrade --install -n "$(NAMESPACE)" "$(RELEASE_NAME)" . --take-ownership

.PHONY: rotation-cron-down
rotation-cron-down:
	helm uninstall -n "$(NAMESPACE)" "$(RELEASE_NAME)" || true
	kubectl delete ns "$(NAMESPACE)" || true

.PHONY: rotation-cron-status
rotation-cron-status:
	kubectl get cronjobs -n "$(NAMESPACE)"
