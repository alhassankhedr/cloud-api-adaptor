# GitHub Actions Activation Guide

This guide explains what you need to do to activate the GitHub Actions workflows in this repository.

## 1. Enable GitHub Actions

GitHub Actions are enabled by default, but verify:
1. Go to your repository **Settings** → **Actions** → **General**
2. Ensure "Allow all actions and reusable workflows" is selected (or configure as needed)
3. Ensure workflows can read and write permissions

## 2. Required Secrets

Configure these secrets in **Settings** → **Secrets and variables** → **Actions** → **Secrets**:

### Essential Secrets (for basic builds)

- **`QUAY_PASSWORD`** - Required for pushing images to Quay.io
  - Get this from your Quay.io account
  - Used by: `publish_images_on_push.yaml`, `caa_build_and_push.yaml`, `podvm_*.yaml`, etc.

### Optional Secrets (for specific features)

- **`AWS_IAM_ROLE_ARN`** - For AWS e2e tests
  - Format: `arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME`
  - Used by: `e2e_aws.yaml`, `e2e_run_all.yaml`

- **`REGISTRY_CREDENTIAL_ENCODED`** - For authenticated registry access in libvirt tests
  - Base64 encoded docker credentials
  - Used by: `e2e_libvirt.yaml`

- **`AZURE_CLIENT_ID`** - For Azure workflows
- **`AZURE_SUBSCRIPTION_ID`** - For Azure workflows  
- **`AZURE_TENANT_ID`** - For Azure workflows
  - Used by: `azure-e2e-test.yml`, `azure-podvm-image-build.yml`

## 3. Required Variables

Configure these in **Settings** → **Secrets and variables** → **Actions** → **Variables**:

### Essential Variables

- **`QUAY_USERNAME`** - Your Quay.io username
  - Used for pushing images to Quay.io
  - Used by most build workflows

### Optional Variables (for Azure workflows)

- **`AZURE_ACR_URL`** - Azure Container Registry URL
- **`AZURE_MANAGED_IDENTITY_NAME`** - Azure Managed Identity name
- **`AZURE_RESOURCE_GROUP`** - Azure Resource Group name
- **`AZURE_PODVM_GALLERY_NAME`** - Azure Shared Image Gallery name
- **`AZURE_PODVM_IMAGE_DEF_NAME`** - Azure PodVM image definition name
- **`AZURE_COMMUNITY_GALLERY_NAME`** - Azure Community Gallery name
- **`AZURE_RELEASE_PODVM_GALLERY_NAME`** - For release builds
- **`AZURE_RELEASE_PODVM_IMAGE_DEF_NAME`** - For release builds
- **`AZURE_RELEASE_PODVM_IMAGE_DEF_NAME_DEBUG`** - For debug release builds
- **`AZURE_RELEASE_COMMUNITY_GALLERY_NAME`** - For release builds
- **`AZURE_RELEASE_RESOURCE_GROUP`** - For release builds

### Optional Variables (for e2e tests)

- **`AUTHENTICATED_REGISTRY_IMAGE`** - For libvirt e2e tests with authenticated registry

## 4. Repository Permissions

Most workflows use `permissions: {}` which means they run with minimal permissions. Some workflows require:

- **`contents: read`** - To checkout code (usually automatic)
- **`packages: write`** - To push container images
- **`id-token: write`** - For OIDC authentication (AWS, Azure)
- **`attestations: write`** - For build attestations
- **`security-events: write`** - For security scanning (CodeQL, Scorecard)

These are typically configured per-job in the workflows.

## 5. Workflow-Specific Setup

### For Basic Builds (No External Services)

The following workflows work with minimal setup:
- ✅ `build.yaml` - Builds and tests (no secrets needed)
- ✅ `lint.yaml` - Code linting (no secrets needed)
- ✅ `commit-message-check.yaml` - Commit message validation (no secrets needed)
- ✅ `actionlint.yaml` - Workflow linting (no secrets needed)

### For Image Publishing

To publish images, you need:
1. **`QUAY_PASSWORD`** secret
2. **`QUAY_USERNAME`** variable
3. Or use `ghcr.io` (GitHub Container Registry) - uses `GITHUB_TOKEN` automatically

Workflows:
- `publish_images_on_push.yaml` - Publishes on push to main
- `caa_build_and_push.yaml` - Builds cloud-api-adaptor images
- `podvm_*.yaml` - Builds PodVM images

### For E2E Tests

**Docker e2e tests:**
- Requires: `QUAY_PASSWORD` and `QUAY_USERNAME`
- Workflow: `e2e_docker.yaml`

**Libvirt e2e tests:**
- Requires: `REGISTRY_CREDENTIAL_ENCODED` secret
- Optional: `AUTHENTICATED_REGISTRY_IMAGE` variable
- Workflow: `e2e_libvirt.yaml`

**AWS e2e tests:**
- Requires: `AWS_IAM_ROLE_ARN` secret
- Workflow: `e2e_aws.yaml`

**Azure e2e tests:**
- Requires: Azure secrets and variables (see Azure section above)
- Workflow: `azure-e2e-test.yml`

### For Azure Workflows

Full Azure setup requires:
- Secrets: `AZURE_CLIENT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`
- Variables: Multiple `AZURE_*` variables (see Variables section)

## 6. Quick Start Checklist

For a minimal working setup:

- [ ] Enable GitHub Actions in repository settings
- [ ] Add `QUAY_PASSWORD` secret (if using Quay.io)
- [ ] Add `QUAY_USERNAME` variable (if using Quay.io)
- [ ] Or configure workflows to use `ghcr.io` instead

For full functionality:

- [ ] Add all secrets listed above
- [ ] Add all variables listed above
- [ ] Configure AWS IAM role (for AWS tests)
- [ ] Configure Azure credentials (for Azure tests)
- [ ] Set up authenticated registry (for libvirt tests)

## 7. Testing Your Setup

1. **Test basic builds:**
   - Create a pull request → `build.yaml` should run automatically
   - Or manually trigger via "Run workflow" button

2. **Test image publishing:**
   - Push to `main` branch → `publish_images_on_push.yaml` should run
   - Check Actions tab for any errors about missing secrets

3. **Test e2e (if configured):**
   - Add label `test_e2e_docker` to a PR → Docker e2e tests run
   - Add label `test_e2e_libvirt` to a PR → Libvirt e2e tests run
   - Add label `test_e2e_aws` to a PR → AWS e2e tests run

## 8. Troubleshooting

**Workflows not running?**
- Check Actions tab for errors
- Verify secrets/variables are set correctly
- Check repository Actions permissions

**Image push failures?**
- Verify `QUAY_PASSWORD` is correct
- Verify `QUAY_USERNAME` matches your account
- Check registry permissions

**E2E test failures?**
- Verify required secrets are set
- Check cloud provider credentials
- Review workflow logs for specific errors

## 9. Notes

- **`GITHUB_TOKEN`** is automatically provided by GitHub Actions - no setup needed
- Some workflows are **callable** (workflow_call) - they only run when called by other workflows
- Some workflows use **conditional execution** - they check for secrets before running
- The `stale.yaml` workflow runs on a schedule to close stale PRs
- The `daily-e2e-tests.yaml` runs daily at 04:15 UTC
