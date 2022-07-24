# Bump these on release, 
# and for now update the deployment files under /deploy.
# The README.md file will auto-populate from the GitHub release.
VERSION_MAJOR ?= 0
VERSION_MINOR ?= 2
BUILD_NUMBER  ?= 0
PATCH_STRING  ?= -beta1

VERSION_STRING = $(VERSION_MAJOR).$(VERSION_MINOR).$(BUILD_NUMBER)$(PATCH_STRING)
IMAGE_TAG ?= $(VERSION_STRING)
REGISTRY_USER ?= quay.io/kuttiproject

SOURCEFILES = cmd/kutti-localprovisioner/main.go pkg/localprovisioner/localprovisioner.go

# Targets
.PHONY: usage
usage:
	@echo "Usage: make provisioner|image|image-multistage|cleanlocal|rmi|clean"

out/kutti-localprovisioner: $(SOURCEFILES)
	CGO_ENABLED=0 go build -o out/kutti-localprovisioner -ldflags "-X main.version=${VERSION_STRING}" ./cmd/kutti-localprovisioner/

.PHONY: provisioner
provisioner: out/kutti-localprovisioner

.PHONY: image
image: provisioner build/package/container/singlestage.Dockerfile
	docker image build -t $(REGISTRY_USER)/provisioner-localvolume:$(IMAGE_TAG) \
	                   -f build/package/container/singlestage.Dockerfile \
					   .

.PHONY: image-multistage
image-multistage: build/package/container/multistage.Dockerfile $(SOURCEFILES)
	docker image build 	-t $(REGISTRY_USER)/provisioner-localvolume:$(IMAGE_TAG) \
						-f build/package/container/multistage.Dockerfile \
						--build-arg VERSION_STRING=${VERSION_STRING} \
						.

.PHONY: cleanlocal
cleanlocal:
	rm -rf out/*

.PHONY: rmi
rmi:
	docker image rm $(REGISTRY_USER)/provisioner-localvolume:$(IMAGE_TAG)

.PHONY: clean
clean: cleanlocal rmi
