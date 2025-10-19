# Pre-commit Hooks Setup Guide

This guide explains how to set up and use pre-commit hooks that mirror the CI pipeline gates defined in the constitution (§7).

## Overview

Pre-commit hooks automatically run security and quality checks before each commit, catching issues early in the development cycle. This mirrors the CI pipeline to provide fast feedback locally.

**Benefits**:

- ✅ Catch issues before pushing to remote
- ✅ Faster feedback than waiting for CI pipeline
- ✅ Consistent code quality across team
- ✅ Reduces CI failures and pipeline runs

## Prerequisites

Before setting up pre-commit hooks, ensure you have the following installed:

1. **Python 3.12+** (for pre-commit framework and Python tools)
2. **Poetry** (for dependency management)
3. **OpenTofu** (for Terraform validation)
4. **Go** (for Go code formatting in tests)
5. **TFLint** (for Terraform linting)
6. **gitleaks** (for secrets scanning)

### Installation Commands

```bash
# 1. Verify Python version
python --version  # Should be 3.12 or higher

# 2. Install Poetry (if not already installed)
curl -sSL https://install.python-poetry.org | python3 -

# 3. Install OpenTofu
# See: https://opentofu.org/docs/intro/install/

# 4. Install Go
# See: https://golang.org/doc/install

# 5. Install TFLint
# macOS:
brew install tflint

# Linux:
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Windows:
choco install tflint

# 6. Install gitleaks
# macOS:
brew install gitleaks

# Linux:
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.2/gitleaks_8.18.2_linux_x64.tar.gz
tar -xzf gitleaks_8.18.2_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/

# Windows:
choco install gitleaks

# Go (alternative):
go install github.com/gitleaks/gitleaks/v8@latest
```

## Quick Start

### 1. Install Project Dependencies

```bash
# Navigate to project root
cd vibetics-cloudedge

# Install all dependencies (includes pre-commit)
poetry install
```

### 2. Install Pre-commit Hooks

```bash
# Install hooks into .git/hooks/
poetry run pre-commit install

# Install commit-msg hook (for conventional commits)
poetry run pre-commit install --hook-type commit-msg

# Install pre-push hook (optional, for slower checks)
poetry run pre-commit install --hook-type pre-push
```

**Expected Output**:

```
pre-commit installed at .git/hooks/pre-commit
pre-commit installed at .git/hooks/commit-msg
```

### 3. Initialize TFLint Plugins

```bash
# Download TFLint plugins (Terraform and GCP rulesets)
tflint --init
```

**Expected Output**:

```
Installing "terraform" plugin...
Installing "google" plugin...
```

### 4. Verify Installation

```bash
# Run pre-commit on all files (first run will download hook dependencies)
poetry run pre-commit run --all-files
```

**First Run**: This will take 5-10 minutes as it downloads and installs all hook dependencies.

**Subsequent Runs**: Much faster (< 1 minute for typical changes).

## Usage

### Automatic Execution (Recommended)

After installation, hooks run automatically on `git commit`:

```bash
# Make changes
vim main.tf

# Stage changes
git add main.tf

# Commit (hooks run automatically)
git commit -m "feat: add WAF module"
```

**Hook Execution Flow**:

```
git commit
  ├─ Pre-commit hooks run:
  │  ├─ Check file sizes
  │  ├─ Trim trailing whitespace
  │  ├─ Check YAML/JSON syntax
  │  ├─ Scan for secrets (gitleaks)
  │  ├─ Format OpenTofu code (tofu fmt)
  │  ├─ Validate OpenTofu syntax (tofu validate)
  │  ├─ Lint OpenTofu code (tflint)
  │  ├─ IaC compliance scan (checkov)
  │  ├─ Security scan (semgrep)
  │  ├─ Format Python code (black, isort)
  │  ├─ Format Go code (go fmt)
  │  └─ Lint Markdown (markdownlint)
  │
  ├─ Commit-msg hook runs:
  │  └─ Validate conventional commit format
  │
  └─ Commit succeeds or fails based on hook results
```

### Manual Execution

Run hooks manually without committing:

```bash
# Run all hooks on all files
poetry run pre-commit run --all-files

# Run all hooks on staged files only
poetry run pre-commit run

# Run specific hook on all files
poetry run pre-commit run terraform_fmt --all-files
poetry run pre-commit run gitleaks --all-files
poetry run pre-commit run checkov --all-files

# Run specific hook on specific files
poetry run pre-commit run terraform_validate --files modules/gcp/waf/main.tf
```

### Bypass Hooks (Use Sparingly)

**⚠️ WARNING**: Only bypass hooks when absolutely necessary (e.g., work-in-progress commits to a feature branch).

```bash
# Skip all hooks for a single commit
git commit --no-verify -m "wip: debugging firewall rules"

# Or use shorthand
git commit -n -m "wip: incomplete changes"
```

**When to bypass**:

- ✅ Work-in-progress commits on feature branches (will be squashed before PR)
- ✅ Emergency hotfixes (run hooks manually after commit)
- ❌ **NEVER** bypass for commits to `main`, `nonprod`, or `prod` branches
- ❌ **NEVER** bypass secrets scanning (gitleaks)

## Hook Categories

### 1. File Quality Checks (Fast, ~5 seconds)

- **check-added-large-files**: Prevents committing files > 500KB
- **end-of-file-fixer**: Ensures files end with newline
- **trailing-whitespace**: Removes trailing spaces
- **check-yaml/json/toml**: Validates syntax
- **check-merge-conflict**: Detects merge conflict markers
- **detect-private-key**: Detects SSH/PGP private keys

### 2. Secrets Scanning (Fast, ~10 seconds)

- **gitleaks**: Scans for exposed secrets (API keys, tokens, credentials)
  - **Blocking**: ANY secret detected blocks commit
  - **No waivers allowed** (constitution §7)

### 3. OpenTofu/Terraform (Medium, ~30 seconds)

- **terraform_fmt**: Auto-formats `.tf` files
- **terraform_validate**: Validates syntax and configuration
- **terraform_tflint**: Lints for best practices and errors
- **terraform_checkov**: IaC security compliance (CIS benchmarks)
- **terraform_docs**: Generates module documentation

### 4. Security Scanning (Medium, ~45 seconds)

- **checkov** (IaC compliance): CRITICAL/HIGH findings should be addressed
- **semgrep** (SAST): Detects security vulnerabilities in code patterns

### 5. Code Formatting (Fast, ~10 seconds)

- **black**: Formats Python code (test scripts)
- **isort**: Sorts Python imports
- **go-fmt**: Formats Go code (Terratest)
- **markdownlint**: Lints Markdown documentation
- **yamllint**: Lints YAML files

### 6. Git Commit Standards (Instant, <1 second)

- **conventional-pre-commit**: Enforces conventional commit format
  - Format: `type(scope): subject`
  - Types: `feat`, `fix`, `docs`, `test`, `chore`, `refactor`, `perf`, `ci`, `build`
  - Example: `feat(waf): add rate limiting rules`

## Configuration Files

Pre-commit hooks reference these configuration files:

| File | Purpose | Hook(s) Using It |
|------|---------|------------------|
| `pre-commit-config.yaml` | Main hook configuration | All hooks |
| `.tflint.hcl` | TFLint rules and plugins | `terraform_tflint` |
| `.tflintignore` | TFLint exclusions | `terraform_tflint` |
| `.checkov.yaml` | Checkov compliance rules | `terraform_checkov` |
| `.markdownlint.yaml` | Markdown linting rules | `markdownlint` |
| `.yamllint.yaml` | YAML linting rules | `yamllint` |

## Troubleshooting

### Hook Installation Fails

**Error**: `pre-commit: command not found`

**Solution**:

```bash
# Ensure Poetry environment is activated
poetry shell

# Or run with poetry prefix
poetry run pre-commit install
```

---

**Error**: `tflint: command not found`

**Solution**:

```bash
# Install TFLint (see Prerequisites section)
brew install tflint  # macOS
# or
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash  # Linux
```

---

**Error**: `gitleaks: command not found`

**Solution**:

```bash
# Install gitleaks (see Prerequisites section)
brew install gitleaks  # macOS
# or
go install github.com/gitleaks/gitleaks/v8@latest
```

### Hook Execution Fails

**Error**: `terraform_validate` fails with "Missing backend configuration"

**Solution**:

```bash
# Initialize OpenTofu with backend disabled (for validation only)
tofu init -backend=false

# Or run validate with the hook's built-in retry
poetry run pre-commit run terraform_validate --all-files
```

---

**Error**: `terraform_tflint` fails with "Failed to initialize plugins"

**Solution**:

```bash
# Initialize TFLint plugins
tflint --init

# Retry hook
poetry run pre-commit run terraform_tflint --all-files
```

---

**Error**: `checkov` reports CRITICAL findings

**Solution**:

1. **Fix the issue** (preferred):

   ```bash
   # Review checkov output for specific CKV-* check IDs
   poetry run checkov --directory . --framework terraform

   # Fix the security issue in your code
   vim main.tf

   # Retry
   git commit -m "fix: address checkov security findings"
   ```

2. **Request waiver** (if fix not feasible):
   - Create GitHub issue with waiver justification
   - Add check ID to `.checkov.yaml` skip list with comment:

     ```yaml
     skip-check:
       - CKV_GCP_1  # Waiver: Issue #123, expires 2025-02-15
     ```

   - Obtain Security Lead + PO approval before commit

---

**Error**: Hooks are too slow

**Solution**:

1. **Run only on changed files** (default behavior):

   ```bash
   # Only staged files are checked
   git commit
   ```

2. **Skip slow hooks temporarily** (use sparingly):

   ```bash
   # Set environment variable to skip specific hooks
   SKIP=semgrep,terraform_checkov git commit -m "wip: fast commit"
   ```

3. **Disable hooks for WIP commits** (use `--no-verify`):

   ```bash
   git commit --no-verify -m "wip: debugging"
   ```

### False Positives

**Gitleaks false positive** (e.g., test fixtures, examples):

Create `.gitleaksignore` file:

```bash
# .gitleaksignore
# Test fixtures with fake credentials
tests/fixtures/fake-credentials.json:1
examples/demo-api-key.txt:5
```

**Checkov false positive**:

Add inline skip comment in `.tf` file:

```hcl
resource "google_compute_instance" "example" {
  # checkov:skip=CKV_GCP_1:Justification for skipping this check
  name         = "test-instance"
  machine_type = "e2-medium"
}
```

## Updating Hooks

Pre-commit hooks should be updated monthly to get latest security rules:

```bash
# Update to latest hook versions
poetry run pre-commit autoupdate

# Review changes
git diff pre-commit-config.yaml

# Test updated hooks
poetry run pre-commit run --all-files

# Commit updates
git add pre-commit-config.yaml
git commit -m "chore: update pre-commit hooks"
```

## CI/CD Integration

Pre-commit hooks mirror the CI pipeline, but CI runs additional checks:

| Check | Pre-commit | CI Pipeline |
|-------|-----------|-------------|
| File quality | ✅ | ✅ |
| Secrets scan (gitleaks) | ✅ | ✅ |
| OpenTofu format/lint | ✅ | ✅ |
| IaC compliance (checkov) | ✅ (local) | ✅ (with reporting) |
| SAST (semgrep) | ✅ (warnings) | ✅ (generates reports) |
| Code formatting | ✅ | ✅ |
| Conventional commits | ✅ | ✅ |
| Threat modeling | ❌ | ✅ (CI only) |
| Container scanning | ❌ | ✅ (CI only) |
| Integration tests | ❌ | ✅ (CD only) |
| DAST | ❌ | ✅ (CD only) |

**Why some checks are CI-only**:

- **Threat modeling**: Requires full codebase analysis and GitHub API access
- **Container scanning**: Requires building full Docker images
- **Integration tests**: Requires deploying infrastructure (too slow for local)
- **DAST**: Requires live infrastructure to test

## Best Practices

1. **Run hooks before pushing**:

   ```bash
   # Ensure all hooks pass before pushing
   poetry run pre-commit run --all-files
   git push
   ```

2. **Fix issues incrementally**:
   - Don't bypass hooks repeatedly
   - Fix security findings as they appear
   - Request waivers only when necessary

3. **Keep hooks updated**:
   - Run `poetry run pre-commit autoupdate` monthly
   - Test updated hooks before committing

4. **Use conventional commits**:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation
   - `test:` for tests
   - `refactor:` for code refactoring
   - `chore:` for maintenance tasks

5. **Share hook setup with team**:
   - Document any custom configurations
   - Help team members troubleshoot hook issues
   - Keep this guide updated

## Getting Help

**Hook failures**:

1. Read the error message carefully
2. Check this guide's Troubleshooting section
3. Review configuration files (`.tflint.hcl`, `.checkov.yaml`, etc.)
4. Ask in team chat with error output

**Security findings**:

1. Understand the vulnerability (checkov/semgrep output)
2. Attempt to fix the issue
3. If fix not feasible, request waiver (see constitution §Waiver Process)
4. Never bypass secrets scanning (gitleaks)

## Additional Resources

- [Pre-commit Documentation](https://pre-commit.com/)
- [TFLint Rules](https://github.com/terraform-linters/tflint/tree/master/docs/rules)
- [Checkov Policies](https://www.checkov.io/5.Policy%20Index/terraform.html)
- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Project Constitution](.specify/memory/constitution.md)
- [README CI/CD Section](../README.md#continuous-integration-ci)
