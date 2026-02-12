# Build options

## Triggers

Builds can be triggered through:
1. Manual workflow dispatch
2. Pushing a tag that starts with 'v', for example, v1.2.3.

## Build process



## Build artifacts

We build the following artifacts as part of this Github action
workflow.

- httpbin RPM for RHEL8 (amd64)
- httpbin RPM for RHEL8 (arm64)
- httpbin RPM for RHEL9 (amd64)
- httpbin RPM for RHEL9 (arm64)
- httpbin DEB for Debian 13 (stable) (amd64)
- httpbin DEB for Debian 13 (stable) (arm64)
- httpbin DEB for Debian 12 (old stable) (amd64)
- httpbin DEB for Debian 12 (old stable) (arm64)
- statically linked httpbin binary for Ubuntu (amd64)
- statically linked httpbin binary for Ubuntu (arm64)
- dynamically linked httpbin binary for Ubuntu (amd64)
- dynamically linked httpbin binary for Ubuntu (arm64)


## Extending github action workflow

Q. How do I add new platforms to build packages for?

A. Update the strategy matrix in build_packages: section in the
   workflow. The configuration for each platform requires the
   following:
   - distro (name of the docker image on hub.docker.com)
   - distro_name (name of the distribution)
   - package_type (type of the package: deb or rpm)
   - install_test_cmd (command to install packages on the distribution)
   - arch (architecture)
   - runner (name of the github runner)

Q. How do I add new architectures to build statically linked and
   dynamically linked binaries for?

A. Update the strategy matrix in the build-binaries: section in the
   workflow. The configuration for each architecture requires the
   following:
   - arch (architecture; used by go build and so should match GOARCH)
   - runner (name of the github runner)

## Future development

1. Investigate why goreleaser did not work.
