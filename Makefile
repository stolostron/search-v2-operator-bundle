# Copyright Contributors to the Open Cluster Management project

# VERSION defines the project version for the bundle.
# Update this value when you upgrade the version of your project.
# To re-generate a bundle for another specific version without changing the standard setup, you can:
# - use the VERSION as arg of the bundle target (e.g make bundle VERSION=0.0.2)
# - use environment variables to overwrite this value (e.g export VERSION=0.0.2)
VERSION ?= $(shell cat COMPONENT_VERSION)-$(shell date +%s)

# For example, running 'make bundle-build bundle-push' will build
# open-cluster-management.io/search-operator-bundle:$VERSION.
IMAGE_TAG_BASE ?= open-cluster-management.io/search-operator-bundle

# BUNDLE_IMG defines the image:tag used for the bundle.
# You can use it as an arg. (E.g make bundle-build BUNDLE_IMG=<some-registry>/<project-name-bundle>:<tag>)
BUNDLE_IMG ?= $(IMAGE_TAG_BASE):v$(VERSION)

default::
	make help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

.PHONY: bundle-build
bundle-build: ## Build the bundle image.
	docker build -f Dockerfile -t $(BUNDLE_IMG) .

.PHONY: bundle-push
bundle-push: ## Push the bundle image.
	$(MAKE) docker-push IMG=$(BUNDLE_IMG)

update: ## Update images to latest versions.
	sh ./scripts/bundle-image-pickup.sh -s