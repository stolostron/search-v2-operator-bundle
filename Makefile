# Copyright Contributors to the Open Cluster Management project

-include /opt/build-harness/Makefile.prow

.PHONY: bundle-latest-image
bundle-latest-image:
	bash ./scripts/bundle-image-pickup.sh -s

.PHONY: test-e2e
test-e2e:
	echo "[TODO] Run e2e test here."
