.PHONY: up down build load deploy verify rollback logs chaos-db clean

CLUSTER_NAME := settle-local
NAMESPACE := settle

up:
	@echo "==> bootstrapping k3d cluster + dependencies"
	k3d cluster create $(CLUSTER_NAME) --config local/k3d-config.yaml || true
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl config set-context --current --namespace=$(NAMESPACE)
	@if [ ! -f local/.env ]; then cp local/.env.example local/.env; \
		echo "created local/.env from example - edit if needed"; fi
	kubectl apply -f local/postgres.yaml
	kubectl apply -f local/redis.yaml
	@echo "==> injecting local secrets from local/.env (git-ignored, never committed)"
	kubectl create secret generic settle-secrets \
		--from-env-file=local/.env \
		--namespace=$(NAMESPACE) \
		--dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f deploy/k8s/config.yaml
	kubectl apply -f deploy/k8s/service.yaml -f deploy/k8s/ingress.yaml
	@echo "==> local cluster ready. Run 'make deploy TAG=1.9.0' to ship an image."

down:
	k3d cluster delete $(CLUSTER_NAME)

build:
	docker build -t settle-api:$(TAG) ./app

load:
	k3d image import settle-api:$(TAG) -c $(CLUSTER_NAME)

deploy:
	@test -n "$(TAG)" || (echo "usage: make deploy TAG=1.9.0" && exit 1)
	sed -e "s#ghcr.io/paylane/settle-api:PLACEHOLDER_IMAGE_TAG#settle-api:$(TAG)#g" \
	    -e "s#PLACEHOLDER_IMAGE_TAG#$(TAG)#g" \
	    -e "s#PLACEHOLDER_DEPLOY_TS#$$(date -u +%FT%TZ)#g" \
	    deploy/k8s/deployment.yaml | kubectl apply -f -
	kubectl apply -f deploy/k8s/hpa.yaml
	kubectl rollout status deployment/settle-api --timeout=120s

verify:
	@bash local/verify.sh

rollback:
	kubectl rollout undo deployment/settle-api
	kubectl rollout undo deployment/settle-worker
	kubectl rollout status deployment/settle-api --timeout=120s

logs:
	kubectl logs -l app=settle-api -f --tail=100

# Task F stretch — inject 3s Postgres latency via toxiproxy sidecar,
# not implemented; see docs/NOT-DONE.md.
chaos-db:
	@echo "not implemented - see docs/NOT-DONE.md"
	@exit 1

clean: down
