VERSION := $(shell git rev-parse --short HEAD)
UV := ~/.local/bin/uv
CURL := $(shell if command -v axel >/dev/null 2>&1; then echo "axel"; else echo "curl"; fi)
REMOTE := nvidia@gpu
REMOTE_PATH := ~/projects/work/textract-rest-api
DOCKER_REGISTRY := registry.lazycat.cloud/x/textract-rest-api
DOCKER_NAME := textract-rest-api
ENV_PROXY := http://192.168.1.200:7890

sync-from-gpu:
	rsync -arvzlt --delete --exclude-from=.rsyncignore $(REMOTE):$(REMOTE_PATH)/ ./

sync-to-gpu:
	ssh -t $(REMOTE) "mkdir -p $(REMOTE_PATH)"
	rsync -arvzlt --delete --exclude-from=.rsyncignore ./ $(REMOTE):$(REMOTE_PATH)

sync-clean:
	ssh -t $(REMOTE) "rm -rf $(REMOTE_PATH)"

build: sync-to-gpu
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker build \
	    -f Dockerfile \
	    -t $(DOCKER_REGISTRY):$(VERSION) \
	    -t $(DOCKER_REGISTRY):latest \
        --network host \
        --build-arg "HTTP_PROXY=$(ENV_PROXY)" \
        --build-arg "HTTPS_PROXY=$(ENV_PROXY)" \
        --build-arg "NO_PROXY=localhost,192.168.1.200,registry.lazycat.cloud" \
		."

test: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm --gpus all --name $(DOCKER_NAME) --network host -v ./output:/app/output $(DOCKER_REGISTRY):$(VERSION)"

inspect: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm --gpus all --name $(DOCKER_NAME) --network host -v ./output:/app/output $(DOCKER_REGISTRY):$(VERSION) sh"

push: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker push $(DOCKER_REGISTRY):$(VERSION) && \
		docker push $(DOCKER_REGISTRY):latest"

.PHONY: build test inspect push sync-from-gpu sync-to-gpu sync-clean