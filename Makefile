# Copyright Contributors to the Open Cluster Management project

-include /opt/build-harness/Makefile.prow

.PHONY: bundle-latest-image
bundle-latest-image:
	bash ./scripts/bundle-image-pickup.sh -s

.PHONY: e2e
e2e:
	echo "Running e2e test..."
