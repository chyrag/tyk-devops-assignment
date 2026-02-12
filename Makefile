# Makefile for httpbin

# Variables
BINARY_NAME  := httpbin
OUTPUT_DIR   := bin
MAIN_PATH    := ./cmd/httpbin
GO           ?= go
MAINTAINER   := Chirag Kantharia <chirag.kantharia@gmail.com>
RELEASE      := 1
GITHUB_USER  := chyrag
GITHUB_REPO  := tyk-devops-assignment

REGISTRY     := ghcr.io
IMAGE_NAME   := $(REGISTRY)/$(GITHUB_USER)/$(GITHUB_REPO)/$(BINARY_NAME)

# Build metadata (evaluated once)
VERSION      ?= $(shell git describe --tags --always 2>/dev/null || echo "dev")
BUILD_TIME   := $(shell date -u '+%Y-%m-%d_%H:%M:%S_UTC')
COMMIT_SHA   := $(shell git rev-parse HEAD 2>/dev/null || echo "unknown")
LDFLAGS      := -s -w -X main.version=$(VERSION) -X main.buildTime=$(BUILD_TIME) -X main.commit=$(COMMIT_SHA)

# Architecture Detection
ifeq ($(ARCH),)
    UNAME_M := $(shell uname -m)
    ifeq ($(UNAME_M),x86_64)
        ARCH := amd64
    else ifeq ($(UNAME_M),aarch64)
        ARCH := arm64
    else
        ARCH := $(UNAME_M)
    endif
endif

# RPM Arch mapping
RPM_ARCH := $(ARCH)
ifeq ($(ARCH),amd64)
    RPM_ARCH := x86_64
else ifeq ($(ARCH),arm64)
    RPM_ARCH := aarch64
endif

.PHONY: all build build-static test lint fmt vet clean deb rpm docker

all: build build-static

prep:
	mkdir -p $(OUTPUT_DIR)

build-static: prep
	@echo "Building static binary (CGO_ENABLED=0, ARCH=$(ARCH))..."
	CGO_ENABLED=0 GOARCH=$(ARCH) $(GO) build \
		-buildvcs=false \
		-ldflags "$(LDFLAGS)" \
		-o $(OUTPUT_DIR)/$(BINARY_NAME)-static-$(ARCH) \
		$(MAIN_PATH)
	@echo "Static binary built: $(OUTPUT_DIR)/$(BINARY_NAME)-static-$(ARCH)"
	@ls -lh $(OUTPUT_DIR)/$(BINARY_NAME)-static-$(ARCH)

build: prep
	@echo "Building binary (CGO_ENABLED=1, ARCH=$(ARCH))..."
	CGO_ENABLED=1 GOARCH=$(ARCH) $(GO) build \
		-buildvcs=false \
		-ldflags "$(LDFLAGS)" \
		-o $(OUTPUT_DIR)/$(BINARY_NAME)-$(ARCH) \
		$(MAIN_PATH)
	@echo "CGO binary built: $(OUTPUT_DIR)/$(BINARY_NAME)-$(ARCH)"
	@ls -lh $(OUTPUT_DIR)/$(BINARY_NAME)-$(ARCH)

build-fips: prep
	@echo "Building FIPS compliant binary (CGO_ENABLED=1, ARCH=$(ARCH)"
	CGO_ENABLED=1 GOARCH=${ARCH} GOEXPERIMENT=boringcrypto $(GO) build \
		-buildvcs=false \
		-tags=requirefips \
		-ldflags "$(LDFLAGS)" \
		-o $(OUTPUT_DIR)/$(BINARY_NAME)-$(ARCH)-fips \
		$(MAIN_PATH)

# Debian packaging
deb: build-static
	@echo "Building Debian package for $(ARCH)"
	$(eval DEB_ROOT := $(OUTPUT_DIR)/deb-$(ARCH))
	$(eval DEB_PKG := $(OUTPUT_DIR)/$(BINARY_NAME)_$(VERSION)_$(ARCH).deb)
	mkdir -p $(DEB_ROOT)/usr/bin/ $(DEB_ROOT)/DEBIAN
	cp $(OUTPUT_DIR)/$(BINARY_NAME)-static-$(ARCH) $(DEB_ROOT)/usr/bin/$(BINARY_NAME)
	echo "Package: $(BINARY_NAME)\nVersion: $(VERSION)\nArchitecture: $(ARCH)\nMaintainer: $(MAINTAINER)\nDescription: httpbin tool" > $(DEB_ROOT)/DEBIAN/control
	dpkg-deb --root-owner-group --build $(DEB_ROOT) $(DEB_PKG)
	dpkg-deb --info $(DEB_PKG)
	dpkg-deb --contents $(DEB_PKG)

rpm: build-static
	@echo "Building RPM package for $(RPM_ARCH)"
	$(eval RPM_ROOT := $(HOME)/rpmbuild)
	$(eval RPM_PKG := $(OUTPUT_DIR)/$(BINARY_NAME)-$(VERSION)-$(RELEASE).$(RPM_ARCH).rpm)
	mkdir -p $(RPM_ROOT)/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
	mkdir -p $(OUTPUT_DIR)/rpm-tmp/usr/bin
	cp $(OUTPUT_DIR)/$(BINARY_NAME)-static-$(ARCH) $(OUTPUT_DIR)/rpm-tmp/usr/bin/$(BINARY_NAME)
	echo -e "Name: $(BINARY_NAME)\nVersion: $(VERSION)\nRelease: $(RELEASE)\nSummary: httpbin tool\nLicense: MIT\n%description\nhttpbin tool\n%files\n/usr/bin/$(BINARY_NAME)" > $(OUTPUT_DIR)/$(BINARY_NAME).spec
	rpmbuild -bb --define "_topdir $(RPM_ROOT)" --buildroot $(PWD)/$(OUTPUT_DIR)/rpm-tmp $(OUTPUT_DIR)/$(BINARY_NAME).spec
	mv $(RPM_ROOT)/RPMS/*/*.rpm $(RPM_PKG)
	rpm -qip $(RPM_PKG)
	rpm -qlp $(RPM_PKG)

docker-setup:
	docker buildx create --use --name multiarch-builder
	docker buildx inspect multiarch-builder --bootstrap

docker-login:
	@echo "$$GITHUB_TOKEN" | docker login $(REGISTRY) -u $(GITHUB_USER) --password-stdin

docker: docker-setup docker-login
	@echo "Building container image for $(BINARY_NAME)"
	docker buildx build \
	       --platform linux/amd64,linux/arm64 \
	       --tag $(IMAGE_NAME) \
	       --tag $(IMAGE_NAME):$(VERSION) \
	       --tag $(IMAGE_NAME):sha-$(COMMIT_SHA) \
	       --push .
	 docker buildx rm multiarch-builder

fips: docker-setup docker-login
	@echo "Building FIPS compliant container image for $(BINARY_NAME)"
	docker buildx build \
	       --platform linux/amd64,linux/arm64 \
	       --file Dockerfile.fips \
	       --tag $(IMAGE_NAME):fips \
	       --tag $(IMAGE_NAME):$(VERSION)-fips \
	       --tag $(IMAGE_NAME):sha-$(COMMIT_SHA)-fips \
	       --push .
	 docker buildx rm multiarch-builder

test:
	@echo "Running tests..."
	$(GO) test -v -race -cover ./...

test-coverage:
	@echo "Running tests with coverage..."
	$(GO) test -v -race -coverprofile=coverage.out ./...
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

lint: fmt vet
	@echo "Linting complete"

fmt:
	@echo "Checking code formatting..."
	$(GO) fmt -n ./...

vet:
	@echo "Running go vet..."
	$(GO) vet ./...

clean:
	@echo "Cleaning..."
	@rm -rf $(OUTPUT_DIR)
	@rm -f $(BINARY_NAME)
	@rm -f coverage.out coverage.html
	$(GO) clean
	@echo "Clean complete"

clean-cache:
	@echo "Cleaning all build caches..."
	$(GO) clean -cache -testcache

run: build
	@$(OUTPUT_DIR)/$(BINARY_NAME)

release: build build-static deb
	gh release create $(VERSION) \
		bin/httpbin* \
		--title "Release $(VERSION)" \
		--repo $(GITHUB_USER)/$(GITHUB_REPO) \
		--generate-notes \
		--latest
