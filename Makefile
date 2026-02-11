# Makefile for httpbin

# Variables
BINARY_NAME=httpbin
OUTPUT_DIR=dist
MAIN_PATH=./cmd/httpbin
GO?=/usr/local/go/bin/go
LDFLAGS=-s -w
OS := linux
ifeq ($(ARCH),)
ARCH_RAW ?= $(shell uname -m)
ifeq ($(ARCH_RAW),x86_64)
    ARCH=amd64
else
ifeq ($(ARCH_RAW),aarch64)
    ARCH=arm64
else
    ARCH=$(ARCH_RAW)
endif
endif
endif
GIT_COMMIT := $(shell git rev-parse --short HEAD)
MAINTAINER := Chirag Kantharia <chirag.kantharia@gmail.com>
RELEASE := 1

# Build info
# VERSION?=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
VERSION?=$(shell git describe --tags --always 2>/dev/null || echo "dev")
BUILD_TIME=$(shell date -u '+%Y-%m-%d_%H:%M:%S_UTC')
COMMIT=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

.PHONY: all build build-static build test lint fmt vet clean deb rpm docker

all: build

build-static:
	@echo "Building static binary (CGO_ENABLED=0, ARCH=$(ARCH))..."
	@mkdir -p $(OUTPUT_DIR)
	CGO_ENABLED=0 GOOS=$(OS) GOARCH=$(ARCH) $(GO) build \
		-a \
		-ldflags "$(LDFLAGS) -X main.version=$(VERSION) -X main.buildTime=$(BUILD_TIME) -X main.commit=$(COMMIT)" \
		-o $(OUTPUT_DIR)/$(BINARY_NAME)-static \
		$(MAIN_PATH)
	@echo "Static binary built: $(OUTPUT_DIR)/$(BINARY_NAME)-static"
	@ls -lh $(OUTPUT_DIR)/$(BINARY_NAME)-static

build:
	@echo "Building binary (CGO_ENABLED=1, ARCH=$(ARCH))..."
	@mkdir -p $(OUTPUT_DIR)
	CGO_ENABLED=0 GOOS=$(OS) GOARCH=$(ARCH) $(GO) build \
		-ldflags "$(LDFLAGS) -X main.version=$(VERSION) -X main.buildTime=$(BUILD_TIME) -X main.commit=$(COMMIT)" \
		-o $(OUTPUT_DIR)/$(BINARY_NAME)-$(ARCH) \
		$(MAIN_PATH)
	@echo "CGO binary built: $(OUTPUT_DIR)/$(BINARY_NAME)-$(ARCH)"
	@ls -lh $(OUTPUT_DIR)/$(BINARY_NAME)-$(ARCH)

# Debian packaging
deb: build-static
	@echo "Building debian package for $(ARCH)"
	$(eval DEB_ROOT := $(OUTPUT_DIR)/deb-$(ARCH))
	mkdir -p $(DEB_ROOT)/usr/bin/ $(DEB_ROOT)/DEBIAN
	cp $(OUTPUT_DIR)/$(BINARY_NAME)-static $(DEB_ROOT)/usr/bin/$(BINARY_NAME)
	echo "Package: $(BINARY_NAME)\nVersion: $(VERSION)\nArchitecture: $(ARCH)\nMaintainer: $(MAINTAINER)\nDescription: httpbin tool" > $(DEB_ROOT)/DEBIAN/control
	dpkg-deb --root-owner-group --build $(DEB_ROOT) \
		$(OUTPUT_DIR)/$(BINARY_NAME)_$(VERSION)_$(ARCH).deb
	dpkg-deb --info $(OUTPUT_DIR)/$(BINARY_NAME)_$(VERSION)_$(ARCH).deb
	dpkg-deb --contents $(OUTPUT_DIR)/$(BINARY_NAME)_$(VERSION)_$(ARCH).deb

# RPM packaging
rpm: build-static
	@echo "Building debian package for $(ARCH)"
	$(eval RPM_ROOT := $(OUTPUT_DIR)/rpm-$(ARCH))
	mkdir -p $(RPM_ROOT)/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
	mkdir -p $(OUTPUT_DIR)/rpm-tmp/usr/bin
	cp $(OUTPUT_DIR)/$(BINARY_NAME)-static $(OUTPUT_DIR)/rpm-tmp/usr/bin/$(BINARY_NAME)
	echo "Name: $(BINARY_NAME)\n"
	echo -e "Name: $(BINARY_NAME)\nVersion: $(VERSION)\nRelease: $(RELEASE)\nSummary: httpbin tool\nLicense: MIT\n%description\nhttpbin tool\n%files\n/usr/bin/$(BINARY_NAME)" > $(OUTPUT_DIR)/$(BINARY_NAME).spec
	rpmbuild -bb --define "_topdir $(RPM_ROOT)" --buildroot $(PWD)/$(OUTPUT_DIR)/rpm-tmp $(OUTPUT_DIR)/$(BINARY_NAME).spec
	mv $(RPM_ROOT)/RPMS/*/*.rpm $(OUTPUT_DIR)/$(BINARY_NAME)-$(VERSION)-$(RELEASE).$(ARCH).rpm
	rpm -qlpi $(OUTPUT_DIR)/$(BINARY_NAME)-$(VERSION)-$(RELEASE).$(ARCH).rpm

docker:
	@echo "Building container image for $(BINARY_NAME)"
	docker buildx create --use
	docker buildx build \
	       --platform linux/amd64,linux/arm64 \
	       --tag $(BINARY_NAME) \
	       --tag $(BINARY_NAME):$(VERSION) \
	       --tag $(BINARY_NAME):sha-$(GIT_COMMIT) \
	       --load .

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
