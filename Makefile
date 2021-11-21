# Bump these on release, 
# and for now update the deployment files under /deploy.
# The README.md file will auto-populate from the GitHub release.
VERSION_MAJOR ?= 0
VERSION_MINOR ?= 1
BUILD_NUMBER  ?= 2

VERSION_STRING = $(VERSION_MAJOR).$(VERSION_MINOR).$(BUILD_NUMBER)
IMAGE_TAG ?= $(VERSION_STRING)
REGISTRY_USER ?= quay.io/kuttiproject

SOURCEFILES = cmd/kutti-localprovisioner/main.go pkg/localprovisioner/localprovisioner.go

.PHONY: image
image: out/kutti-localprovisioner build/package/provisioner-localvolume/singlestage.Dockerfile
	docker image build -t $(REGISTRY_USER)/provisioner-localvolume:$(IMAGE_TAG) \
	                   -f build/package/provisioner-localvolume/singlestage.Dockerfile \
					   .

.PHONY: image-multistage
image-multistage: build/package/provisioner-localvolume/multistage.Dockerfile $(SOURCEFILES)
	docker image build 	-t $(REGISTRY_USER)/provisioner-localvolume:$(IMAGE_TAG) \
						-f build/package/provisioner-localvolume/multistage.Dockerfile \
						--build-arg VERSION_STRING=${VERSION_STRING} \
						.

.PHONY: clean
clean: rmi cleanlocal

.PHONY: cleanlocal
cleanlocal:
	rm -rf out/*

.PHONY: rmi
rmi:
	docker image rm $(REGISTRY_USER)/provisioner-localvolume:$(IMAGE_TAG)

out/kutti-localprovisioner: $(SOURCEFILES)
	go mod tidy
	CGO_ENABLED=0 go build -o out/kutti-localprovisioner -ldflags "-X main.version=${VERSION_STRING}" ./cmd/kutti-localprovisioner/

.PHONY: provisioner
provisioner: out/kutti-localprovisioner
