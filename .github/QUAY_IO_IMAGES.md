# Images Stored in Quay.io

This document lists all container images that are built and pushed to Quay.io by the GitHub Actions workflows.

**Default Registry:** `quay.io/confidential-containers`

## Main Application Images

### 1. cloud-api-adaptor

The cloud-api-adaptor implements the remote hypervisor interface for Kata Containers, enabling the creation of Kata VMs on cloud environments without requiring baremetal servers or nested virtualization. It runs as a daemonset on each Kubernetes worker node and receives commands from the `containerd-shim-kata-v2` process, translating them into cloud provider API calls to create and manage peer pod VMs. The adaptor establishes VxLAN network tunnels between worker nodes and peer pod VMs to enable communication and container lifecycle management.

- **Image Name:** `quay.io/confidential-containers/cloud-api-adaptor`
- **Tags:**
  - `latest` - Latest dev build
  - `dev-<commit-sha>` - Dev build with commit SHA
  - `<commit-sha>` - Release build with commit SHA
  - `<tag>-dev` - Dev build for releases
  - `<tag>` - Release build for releases
  - `<tag>-amd64-dev` - Architecture-specific dev builds
  - `<tag>-amd64` - Architecture-specific release builds
  - `<tag>-s390x-dev` - Architecture-specific dev builds
  - `<tag>-s390x` - Architecture-specific release builds
  - `<tag>-ppc64le-dev` - Architecture-specific dev builds
  - `<tag>-ppc64le` - Architecture-specific release builds
- **Architectures:** linux/amd64, linux/s390x, linux/ppc64le
- **Workflows:** 
  - `publish_images_on_push.yaml` (on push to main)
  - `caa_build_and_push.yaml`
  - `caa_build_and_push_per_arch.yaml`
  - `release.yaml` (on release)

### 2. peerpod-ctrl

The peerpod-ctrl is a Kubernetes controller that tracks cloud provider resources for peer pods. It watches PeerPod Custom Resource (CR) events and ensures proper cleanup of cloud resources. When a peer pod is created, the cloud-api-adaptor creates a PeerPod CR containing the VM instance ID and cloud provider information. If the cloud-api-adaptor fails to delete resources (e.g., due to network errors), the controller detects dangling resources via finalizers and performs cleanup to prevent resource leaks.

- **Image Name:** `quay.io/confidential-containers/peerpod-ctrl`
- **Tags:**
  - `latest` - Latest build
  - `<commit-sha>` - Build with commit SHA
  - `<release-tag>` - Release tag
- **Architectures:** linux/amd64, linux/s390x, linux/ppc64le
- **Workflows:**
  - `publish_images_on_push.yaml` (on push to main)
  - `peerpod-ctrl_image.yaml`
  - `release.yaml` (on release)

### 3. peer-pods-webhook

The peer-pods-webhook is a mutating admission controller that modifies pod specifications for peer pods. Unlike standard pods, peer pods consume resources on cloud VMs rather than worker nodes, which causes scheduling issues. The webhook intercepts pod creation requests for specific runtime classes, removes standard resource entries (CPU/memory), and replaces them with peer-pod extended resources. This allows Kubernetes to properly track and schedule peer pods while accounting for actual resource consumption on worker nodes separately.

- **Image Name:** `quay.io/confidential-containers/peer-pods-webhook`
- **Tags:**
  - `latest` - Latest build
  - `<commit-sha>` - Build with commit SHA
  - `<release-tag>` - Release tag
- **Workflows:**
  - `publish_images_on_push.yaml` (on push to main)
  - `webhook_image.yaml`
  - `release.yaml` (on release)

## CSI Wrapper Images

### 4. csi-controller-wrapper

The csi-controller-wrapper is a CSI (Container Storage Interface) plugin that runs on the Kubernetes control plane. It wraps existing CSI drivers to enable persistent volume attachment for peer pods. The wrapper intercepts CSI controller service calls, creates PeerPodVolume CRs to track volume state, and coordinates with the cloud-api-adaptor to attach volumes to peer pod VMs running in the cloud rather than on worker nodes.

- **Image Name:** `quay.io/confidential-containers/csi-controller-wrapper`
- **Tags:**
  - `latest` - Latest build
  - `<commit-sha>` - Build with commit SHA
  - `<release-tag>` - Release tag
- **Architectures:** linux/amd64, linux/s390x, linux/ppc64le
- **Workflows:**
  - `publish_images_on_push.yaml` (on push to main)
  - `csi_wrapper_images.yaml`
  - `release.yaml` (on release)

### 5. csi-node-wrapper

The csi-node-wrapper is a CSI plugin that runs on Kubernetes worker nodes. It wraps existing CSI node services to handle volume operations for peer pods. The wrapper intercepts CSI node service calls, communicates with the cloud-api-adaptor to identify the peer pod VM, and coordinates volume attachment operations to ensure persistent volumes are properly mounted in peer pod VMs running in the cloud.

- **Image Name:** `quay.io/confidential-containers/csi-node-wrapper`
- **Tags:**
  - `latest` - Latest build
  - `<commit-sha>` - Build with commit SHA
  - `<release-tag>` - Release tag
- **Architectures:** linux/amd64, linux/s390x, linux/ppc64le
- **Workflows:**
  - `publish_images_on_push.yaml` (on push to main)
  - `csi_wrapper_images.yaml`
  - `release.yaml` (on release)

### 6. csi-podvm-wrapper

The csi-podvm-wrapper is a CSI plugin that runs inside peer pod VMs. It provides the node-side CSI interface within the peer pod VM environment, allowing the VM to receive and process volume mount/unmount requests. This component works in conjunction with the csi-controller-wrapper and csi-node-wrapper to complete the volume attachment workflow for peer pods.

- **Image Name:** `quay.io/confidential-containers/csi-podvm-wrapper`
- **Tags:**
  - `latest` - Latest build
  - `<commit-sha>` - Build with commit SHA
  - `<release-tag>` - Release tag
- **Architectures:** linux/amd64, linux/s390x, linux/ppc64le
- **Workflows:**
  - `publish_images_on_push.yaml` (on push to main)
  - `csi_wrapper_images.yaml`
  - `release.yaml` (on release)

## PodVM Images

### 7. podvm-generic-fedora (mkosi-based)

The podvm-generic-fedora image is a modern PodVM image built using mkosi (a tool for building OS images). This image contains the necessary components to run peer pods, including the agent-protocol-forwarder, Kata agent, and other runtime dependencies. The mkosi-based approach provides a more maintainable and reproducible build process compared to the legacy packer-based approach. The image is stored as an OCI artifact containing a QCOW2 disk image that can be imported into various cloud providers.

- **Image Name:** `quay.io/confidential-containers/podvm-generic-fedora`
- **Variants:**
  - `podvm-generic-fedora-amd64` - AMD64 architecture
  - `podvm-generic-fedora-s390x` - S390x architecture
  - `podvm-generic-fedora-debug-amd64` - Debug variant for AMD64
  - `podvm-generic-fedora-debug-s390x` - Debug variant for S390x
- **Tags:**
  - `<short-commit-sha>` - Short commit SHA
  - `<image-tag>` - Custom image tag (if provided)
- **Format:** OCI artifact (tar.xz containing qcow2)
- **Workflows:**
  - `podvm_mkosi.yaml`
  - `e2e_run_all.yaml`
  - `podvm_publish.yaml`
  - `release.yaml` (on release)

### 8. podvm-docker-image

The podvm-docker-image is a Docker OCI-compatible container image version of the PodVM, specifically designed for use with the Docker cloud provider. Unlike the QCOW2 format used for other providers, this image is packaged as a standard Docker image that can be pulled and run by Docker, enabling peer pods to run in Docker-based environments.

- **Image Name:** `quay.io/confidential-containers/podvm-docker-image-<arch>`
- **Variants:**
  - `podvm-docker-image-amd64` - AMD64 architecture
  - `podvm-docker-image-s390x` - S390x architecture
- **Tags:**
  - `<short-commit-sha>` - Short commit SHA
- **Format:** Docker OCI image
- **Workflows:**
  - `podvm_mkosi.yaml`
  - `e2e_run_all.yaml`

### 9. podvm (packer-based)

The podvm images are legacy PodVM images built using HashiCorp Packer. These images are provider-specific and OS-specific (e.g., Ubuntu-based images for generic providers). They contain the same runtime components as mkosi-based images but use a different build toolchain. While still supported, the project is transitioning to mkosi-based builds for better maintainability.

- **Image Name:** `quay.io/confidential-containers/podvm-<provider>-<os>-<arch>`
- **Examples:**
  - `podvm-generic-ubuntu-amd64`
  - `podvm-generic-ubuntu-s390x`
- **Tags:**
  - `latest` - Latest build
  - `<commit-sha>` - Build with commit SHA
  - `<release-tag>` - Release tag
- **Workflows:**
  - `podvm.yaml`
  - `podvm_publish.yaml`
  - `e2e_run_all.yaml`
  - `release.yaml` (on release)

### 10. podvm-builder

The podvm-builder is a container image used in the PodVM build pipeline. It contains the build tools and dependencies needed to compile binaries and prepare components that will be included in the final PodVM images. This intermediate build image is used during the multi-stage build process for creating PodVM images.

- **Image Name:** `quay.io/confidential-containers/podvm-builder`
- **Tags:**
  - `latest` - Latest build
  - `<commit-sha>` - Build with commit SHA
  - `<release-tag>` - Release tag
- **Workflows:**
  - `podvm_builder.yaml`
  - `podvm_publish.yaml`
  - `release.yaml` (on release)

### 11. podvm-binaries

The podvm-binaries image contains the compiled binaries and runtime components that are extracted and included in the final PodVM images. This intermediate image is produced after building the binaries and is used as a source for copying components into the final PodVM images during the build process.

- **Image Name:** `quay.io/confidential-containers/podvm-binaries`
- **Tags:**
  - `latest` - Latest build
  - `<commit-sha>` - Build with commit SHA
  - `<release-tag>` - Release tag
- **Workflows:**
  - `podvm_binaries.yaml`
  - `podvm_publish.yaml`
  - `release.yaml` (on release)

## Build Tools

### 12. golang-fedora

The golang-fedora image is a build environment container image that provides a consistent Go development and build environment based on Fedora Linux. It contains a specific version of Go and Fedora, ensuring reproducible builds across different environments. This image is used in CI/CD pipelines and by developers who need a standardized build environment for compiling Go-based components of the project.

- **Image Name:** `quay.io/confidential-containers/golang-fedora`
- **Tags:**
  - `<go-version>-<fedora-version>` - Version-based tag (e.g., `1.21-f39`)
  - `<go-version>-<fedora-version>-<commit-sha>` - With commit SHA
- **Architectures:** linux/amd64, linux/arm64, linux/ppc64le, linux/s390x
- **Workflows:**
  - `build-golang-fedora.yaml` (on push to main or workflow_dispatch)

## Test Images

### 13. test-images

The test-images are container images used as test fixtures in end-to-end (e2e) tests. These images are based on various base images (Alpine, Ubuntu, etc.) and are used to validate peer pod functionality, including container execution, networking, and storage operations. Different test image variants allow testing across various Linux distributions and scenarios.

- **Image Name:** `quay.io/confidential-containers/test-images`
- **Tags:**
  - `<dockerfile-suffix>` - Based on Dockerfile name (e.g., `alpine`, `ubuntu`, etc.)
- **Architectures:** linux/amd64, linux/s390x
- **Workflows:**
  - `test-images.yaml` (on push to main or workflow_dispatch)

## Image Naming Summary

All images follow this pattern:
```
quay.io/confidential-containers/<image-name>:<tag>
```

Where:
- **Registry:** `quay.io/confidential-containers` (default)
- **Image Name:** Varies by component (see above)
- **Tag:** Usually `latest`, commit SHA, or release tag

## When Images Are Published

1. **On Push to Main Branch:**
   - `cloud-api-adaptor` (dev and release variants)
   - `peerpod-ctrl`
   - `peer-pods-webhook`
   - `csi-controller-wrapper`
   - `csi-node-wrapper`
   - `csi-podvm-wrapper`

2. **On Release Creation:**
   - All images above with release tags
   - PodVM images (builder, binaries, packer-based, mkosi-based)

3. **On Workflow Dispatch:**
   - All images can be manually triggered
   - `golang-fedora` (when Dockerfile changes)
   - `test-images` (when Dockerfile changes)

4. **For E2E Tests:**
   - Images are built with PR-specific tags (e.g., `ci-pr123`)
   - Stored in `ghcr.io` by default for PR tests

## Notes

- Images can also be pushed to `ghcr.io` (GitHub Container Registry) by changing the registry input
- Some workflows support both `quay.io` and `ghcr.io` based on configuration
- PodVM mkosi images are stored as OCI artifacts (not standard Docker images)
- Architecture-specific builds are available for amd64, s390x, and ppc64le
- Debug variants are available for mkosi-based PodVM images
