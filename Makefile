-include .env

PHP_VER ?= 8.2
DOCKER_TAG ?= ghcr.io/allhaileris/php-container:$(PHP_VER)

DOCKER_BUILD_COMMAND = docker buildx build \
	--tag $(DOCKER_TAG)

arm:
	$(DOCKER_BUILD_COMMAND) --platform linux/arm64 \
    	--build-arg PHP_VER=$(PHP_VER) \
     	--push .

push: arm
