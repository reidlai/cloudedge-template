# Implementation Tasks: Refactor OpenTofu Directory Structure

**Feature**: `004-move-all-opentofu`
**Branch**: `004-move-all-opentofu`
**Date**: 2025-11-25
**Status**: Ready for Implementation

## Summary

This document breaks down the OpenTofu directory restructure into atomic, executable tasks organized by user story. The feature relocates all OpenTofu configuration files from the repository root to `deploy/opentofu/gcp/`, performs state migration with automated rollback capabilities, ensures provider version consistency, and implements a Private CA.

**Total Estimated Tasks**: 60 tasks across 6 phases
**Parallelization Opportunities**: 15 parallelizable tasks marked with [P]
**Test Tasks**: 17 Terratest scenarios to implement

---

## Implementation Strategy

### MVP Scope (Minimum Viable Product)

**MVP = User Stories 1 + 2 + 3**

- Delivers complete directory restructure with state migration.
- Replaces self-signed certs with Private CA (DevOps tier).
- Includes automated rollback for safety.

### Incremental Delivery Approach

1. **Phase 1 (Setup)**: Project initialization and prerequisite checks
2. **Phase 2 (Foundational)**: Pre-migration preparation and validation
3. **Phase 3 (US1)**: Relocate root configuration files
4. **Phase 4 (US2)**: Relocate modules directory
5. **Phase 5 (US3)**: Implement Private CA
6. **Phase 6 (Polish)**: BDD test implementation and validation

---

## Phase 1: Setup & Prerequisites

**Goal**: Prepare environment and verify prerequisites for safe migration

**Tasks**:

- [X] T001 Verify OpenTofu CLI installation and version (requires >= v1.10.7) in current environment
- [X] T002 Verify GCS backend access by running `tofu state list` from repository root
- [X] T003 Verify no active state locks exist by checking for `.terraform.tfstate.lock.info` file
- [X] T004 Create directory structure: `mkdir -p deploy/opentofu/gcp` from repository root
- [X] T005 Document pre-migration state by recording resource count: `tofu state list | wc -l > /tmp/pre-migration-resource-count.txt`

**Completion Criteria**:

- ✅ OpenTofu v1.10.7+ available
- ✅ State accessible (no lock conflicts)
- ✅ Target directory created
- ✅ Pre-migration baseline documented

---

## Phase 2: Foundational - Pre-Migration Preparation

**Goal**: Create backups and clean caches before any file moves

**Dependencies**: Phase 1 must complete first

**Tasks**:

- [X] T006 Create state backup with timestamp: `tofu state pull > state-backup-$(date +%Y%m%d%H%M%S).tfstate` from repository root
- [X] T007 Validate state backup is valid JSON by running `cat state-backup-*.tfstate | jq . > /dev/null`
- [X] T008 Record state lineage for verification: `jq -r '.lineage' state-backup-*.tfstate > /tmp/original-lineage.txt`
- [X] T009 Create backup of backend.tf: `cp backend.tf backend.tf.backup-$(date +%Y%m%d%H%M%S)`
- [X] T010 Create backup of backend-config.hcl: `cp backend-config.hcl backend-config.hcl.backup-$(date +%Y%m%d%H%M%S)`
- [X] T011 Delete all .terraform cache directories: `find . -name ".terraform" -type d -prune -exec rm -rf {} \;` from repository root (FR-009)
- [X] T012 Verify cache deletion: `find . -name ".terraform" -type d` should return empty

**Completion Criteria**:

- ✅ State backup created and validated
- ✅ Backend configuration backed up
- ✅ All .terraform caches removed
- ✅ Baseline metrics recorded (lineage, resource count)

**Rollback**: If any backup creation fails, abort migration (no changes made yet)

---

## Phase 3: User Story 1 - Relocate Root OpenTofu Configurations

**User Story**: As a DevOps Engineer, I want to move the OpenTofu/Terraform configuration files from the repository root to a dedicated GCP deployment directory so that the repository root remains clean and the infrastructure code is organized by provider/environment.

**Priority**: P1
**Dependencies**: Phase 2 must complete first

### File Relocation Tasks

- [X] T013 [P] [US1] Move main.tf using git: `git mv main.tf deploy/opentofu/gcp/` from repository root
- [X] T014 [P] [US1] Move variables.tf using git: `git mv variables.tf deploy/opentofu/gcp/` from repository root
- [X] T015 [P] [US1] Move outputs.tf using git: `git mv outputs.tf deploy/opentofu/gcp/` from repository root
- [X] T016 [US1] Move backend.tf using git: `git mv backend.tf deploy/opentofu/gcp/` from repository root
- [X] T018 [US1] Copy provider lock file to new location: `cp .terraform.lock.hcl deploy/opentofu/gcp/.terraform.lock.hcl` (FR-007, preserves root copy)
- [X] T019 [US1] Verify lock files are identical: `diff .terraform.lock.hcl deploy/opentofu/gcp/.terraform.lock.hcl`

### State Migration Tasks

- [X] T022 [US1] **PREREQUISITE**: Ensure `TF_VAR_bucket_name` and `TF_VAR_project_id` environment variables are set correctly for the GCS backend. Initialize new backend location: `cd deploy/opentofu/gcp && tofu init -migrate-state -backend-config="bucket=${TF_VAR_bucket_name}" -backend-config="prefix=${TF_VAR_project_id}"`
- [X] T023 [US1] Push state to new backend: `tofu state push ../../../state-backup-*.tfstate` from deploy/opentofu/gcp/
- [X] T024 [US1] Verify state lineage matches: compare `tofu state pull | jq -r '.lineage'` with `/tmp/original-lineage.txt`
- [X] T025 [US1] Verify resource count unchanged: compare `tofu state list | wc -l` with `/tmp/pre-migration-resource-count.txt`
- [X] T026 [US1] Run validation: `tofu validate` from deploy/opentofu/gcp/ should pass (FR-004, SC-002)
- [X] T027 [US1] Run plan verification: `tofu plan -detailed-exitcode` from deploy/opentofu/gcp/ should return exit code 0 (no changes)

### Rollback Automation (Critical Safety Task)

- [X] T028 [US1] Create rollback script at `scripts/rollback-migration.sh` with trap handler for automatic state restoration on failure (FR-011)

**User Story 1 Independent Test Criteria**:

- ✅ Files `main.tf`, `variables.tf`, `outputs.tf`, `backend.tf`, `backend-config.hcl` exist in `deploy/opentofu/gcp/`
- ✅ No `*.tf` files remain in repository root (except `.terraform.lock.hcl`)
- ✅ `tofu validate` passes in new location
- ✅ `tofu plan` shows zero changes
- ✅ State lineage unchanged
- ✅ Resource count unchanged

---

## Phase 4: User Story 2 - Relocate Infrastructure Modules

**User Story**: As a DevOps Engineer, I want to move the shared modules into the GCP deployment directory scope so that all dependencies for the GCP deployment are self-contained within the `deploy/opentofu/gcp` structure.

**Priority**: P1
**Dependencies**: User Story 1 (Phase 3) must complete first

### Module Relocation Tasks

- [X] T029 [US2] Move entire modules directory using git: `git mv modules deploy/opentofu/gcp/` from repository root (FR-002)
- [X] T030 [US2] Verify modules directory structure: `ls -R deploy/opentofu/gcp/modules/` should show gcp/, aws/, azure/ subdirectories
- [X] T031 [US2] Verify no modules/ directory remains in repository root: `ls modules/ 2>&1` should return "No such file or directory"

### Module Resolution Validation

- [X] T032 [US2] Initialize with module resolution: `tofu init` from deploy/opentofu/gcp/ should successfully resolve all modules
- [X] T033 [US2] Verify module source paths: `tofu get` from deploy/opentofu/gcp/ should complete without errors (FR-003)
- [X] T034 [US2] Run validation with modules: `tofu validate` from deploy/opentofu/gcp/ should pass

**User Story 2 Independent Test Criteria**:

- ✅ Directory `deploy/opentofu/gcp/modules/` exists
- ✅ Modules contain all subdirectories: gcp/, aws/, azure/
- ✅ `tofu init` successfully resolves all module references

---

## Phase 5: User Story 3 - Implement Google Managed Private CA

**User Story**: As a Security Engineer, I want to replace the existing self-signed TLS certificates with Google-managed certificates issued by a Private Certificate Authority (CAS) to improve security.

**Priority**: P2
**Dependencies**: User Story 2 (Phase 4) must complete first

### Private CA Implementation Tasks

- [X] T035 [US3] Enable CAS API: Ensure `privateca.googleapis.com` and `certificatemanager.googleapis.com` are enabled in `deploy/opentofu/gcp/main.tf` (or relevant service config).
- [X] T036 [US3] Define CAS Pool Resource: Add `google_privateca_ca_pool` to `deploy/opentofu/gcp/main.tf` (or new module) with `tier = "DEVOPS"` (Per-Certificate billing) per FR-016.
- [X] T037 [US3] Define Root CA: Add `google_privateca_certificate_authority` for the Root CA within the pool.
- [X] T038 [US3] Configure Certificate Manager: Add `google_certificate_manager_certificate` resource referencing the CAS Pool.
- [X] T039 [US3] Configure Cross-Project Access: Add `google_privateca_ca_pool_iam_binding` to grant `roles/privateca.certificateManager` (or equivalent) to the target service accounts or projects (FR-017).
- [X] T040 [US3] Update Load Balancer: Modify the `dr_loadbalancer` (or relevant) module to accept the new certificate ID instead of self-signed PEMs.
- [X] T041 [US3] Remove Legacy Resources: Remove `tls_private_key` and `tls_self_signed_cert` resources from `deploy/opentofu/gcp/modules/gcp/self_signed_certificate/`.
- [X] T042 [US3] Apply Changes: Run `tofu apply` in `deploy/opentofu/gcp/` to provision the Private CA and update the LB.
- [X] T043 [US3] Verify Deployment: Check GCP Console or use `gcloud privateca pools describe` to verify Tier is DevOps and IAM bindings exist.

**User Story 3 Independent Test Criteria**:

- ✅ `google_privateca_ca_pool` exists with tier "DEVOPS".
- ✅ IAM bindings allow cross-project access.
- ✅ Load Balancer uses a Google-managed certificate.
- ✅ No `tls_self_signed_cert` resources remain in state.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Goal**: Implement BDD test scenarios and final validation

**Dependencies**: User Story 3 must complete first

### BDD Test Implementation (Terratest)

- [X] T044 [P] Copy BDD feature file: `cp specs/004-move-all-opentofu/contracts/directory_migration.feature features/` to project root features/ directory
- [X] T045 [P] Create Terratest integration test skeleton in tests/integration/directory_migration_test.go for @integration scenarios
- [X] T046 [P] Create Terratest contract test skeleton in tests/contract/state_migration_test.go for @contract scenarios
- [X] T047 Implement BDD scenario: "Successfully move OpenTofu files to new directory structure" (@smoke @integration)
- [X] T048 Implement BDD scenario: "Successfully migrate OpenTofu state to new backend location" (@integration @state-migration)
- [X] T049 Implement BDD scenario: "Module source paths remain valid after relocation" (@integration)
- [X] T050 Implement BDD scenario: "Provider version consistency is maintained after migration" (@integration)
- [X] T051 Implement BDD scenario: "Automatic rollback on state migration failure" (@integration @rollback)
- [X] T052 Implement BDD scenario: "Rollback when state verification fails after migration" (@integration @rollback)
- [X] T053 Implement BDD scenario: "Dot-files remain in repository root" (@integration @compliance)
- [X] T054 Implement BDD scenario: "Backend configuration key is correctly updated" (@contract)
- [X] T055 Implement BDD scenario: "State backup file is created with correct naming convention" (@contract)
- [X] T056 [US3] Implement BDD scenario: "Verify CAS Pool exists and has correct tier" (@integration @security)
- [X] T057 [US3] Implement BDD scenario: "Verify Load Balancer uses managed certificate" (@integration @security)
- [X] T058 [US3] Implement BDD scenario: "Verify CAS Pool IAM bindings for cross-project access" (@integration @security)

### Final Validation & Documentation

- [X] T059 Run comprehensive validation: `tofu fmt -check -recursive && tofu validate && tofu plan -detailed-exitcode` from deploy/opentofu/gcp/
- [X] T060 Verify all success criteria met: SC-001 (no .tf in root), SC-002 (validate passes), SC-003 (structure), SC-004 (Private CA)
- [X] T061 Stage all changes for git commit: `git add -A` from repository root
- [X] T062 Create git commit with migration summary including state lineage and resource count verification
- [X] T063 [P] Create follow-up GitHub issue for documentation updates (README.md, CI/CD workflows, helper scripts) per FR-005

**Completion Criteria**:

- ✅ All BDD scenarios implemented
- ✅ All success criteria validated
- ✅ Changes committed
