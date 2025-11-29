```markdown
# AGENTS.md

This file provides guidance to **OpenCode agents** (and any autonomous coding agent workflow) when working with code in this repository.

## Overview

The repository implements a **Spec-Driven Development (SDD)** workflow optimized for agent-based development. The process is fully structured, deterministic, and enforces separation of concerns across specification, planning, and execution phases using custom agent commands/tools.

## Workflow Commands

All workflow commands are defined in `.opencode/commands/` and execute via the `/command-name` syntax.

### Feature Development Lifecycle

1. **`/speckit.constitution [principles]`** - Create or update project constitution (`.specify/memory/constitution.md`)
   - Defines non-negotiable development principles
   - Templates are synchronized automatically
   - Uses semantic versioning (MAJOR.MINOR.PATCH)

2. **`/speckit.specify <feature description>`** - Create feature specification
   - Generates `specs/###-feature/spec.md` from template
   - Focus: WHAT and WHY (business requirements, user scenarios)
   - Avoid: HOW (no tech stack, APIs, implementation details)

3. **`/speckit.clarify`** - Resolve specification ambiguities (run BEFORE `/speckit.plan`)
   - Asks up to 5 targeted clarification questions
   - Updates spec.md with answers in `## Clarifications` section
   - Reduces rework during implementation

4. **`/speckit.plan [context]`** - Generate implementation plan
   - Requires completed spec.md
   - Creates: `research.md`, `data-model.md`, `contracts/`, `quickstart.md`, agent-specific guidance
   - Validates against constitution principles
   - Stops before task generation (use `/speckit.tasks` next)

5. **`/speckit.tasks [context]`** - Generate actionable task breakdown
   - Requires completed plan.md
   - Creates dependency-ordered `tasks.md`
   - Tasks marked `[P]` can run in parallel
   - Sequential tasks must run in order

6. **`/speckit.analyze`** - Cross-artifact consistency analysis (run AFTER `/speckit.tasks`)
   - Read-only validation across spec.md, plan.md, tasks.md
   - Detects: duplications, ambiguities, coverage gaps, constitution violations
   - Severity: CRITICAL, HIGH, MEDIUM, LOW
   - Provides remediation suggestions (does NOT auto-fix)

7. **`/speckit.implement`** - Execute implementation from tasks.md
   - Phase-by-phase execution: Setup → Tests → Core → Integration → Polish
   - Respects task dependencies and parallel markers
   - Marks completed tasks with `[X]` in tasks.md

## Repository Structure (Agent-Visible)

```
.env                       # Local environment variables file including TF_VAR_ prefixed environment varialbes
.github/                   # GitHub Actions configuration and documentation
├── workflows/             # All GitHub CI pipeline definitions
│   └── ci.yaml            # Main CI pipeline: lint, security scans, unit/contract tests, plan validation
└── CI_QUICK_REFERNCE.md   # Human-readable summary of all CI pipelines and manual triggers
.opencode/                 # OpenCode agent configuration (native format)  
├── commands/              # Github Spec-kit specific commands
├── node_modules/          # NodeJS modules folder for coding agent
├── .gitignore             # gitignore for coding agent
├── package.json           # package.json for coding agent
└── settings.local.json    # Local overrides for agent behavior (ignored in git)
.specify/
├── memory/
│   └── constitution.md     # Non-negotiable principles (MUST be respected)
├── scripts/bash/           # Helper scripts agents can call
│   ├── check-prerequisites.sh        # Validates current state before running a command
│   ├── common.sh                     # Shared bash functions
│   ├── create-new-feature.sh         # Creates feature branch + initial spec folder
│   ├── setup-plan.sh                 # Orchestrates plan generation phase
│   └── update-agent-context.sh       # Update coding agent context
└── templates/              # Templates with [PLACEHOLDERS] for generation
│   ├── agent-file-template.md
│   ├── checklist-template.md
│   ├── plan-template.md
│   ├── spec-template.md
│   └── tasks-template.md
deploy/opentofu/            # Opentofu core scripts folder
├── gcp/
|   ├──project-singleton    # All scripts under this folder are used to manage resources which are specific for GCP project singleton resources (resource removal takes grace period more than one day)
|   │  ├── locals.tf                  # local variables
|   │  ├── main.tf                    # Main OpenTofu file including terraform block
|   │  ├── variables.tf               # Root module variables
|   │  └── outputs.tf                 # Root module outputs
|   └──environment-specific # All scripts under this folder are used to manage resources which are easily be removed immediately in GCP within few mintues
|      ├── main.tf                    # Main OpenTofu file including terraform block
|      ├── variables.tf               # Root module variables
|      └── outputs.tf                 # Root module outputs
├── aws/                    # Placehodler folder for future AWS implementation
└── azure/                  # Placehodler folder for future Azure implementation
docs/                       # Project specific documentation folder
features/                   # Cucumber BDD scenarios (@smoke, @integration, @api)
specs/###-feature/          # One folder per feature (auto-created)
├── spec.md                 # Business spec (non-technical)
├── plan.md                 # Technical architecture
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/              # API/interface contracts
└── tasks.md                # Executable task list with [P] parallel markers
tests/
├── unit/                  # Isolated unit tests (mocks only)
├── integration/           # Playwright integration tests
└── contract/              # API contract tests
pre-commit-config.yaml      # Pre-commit hooks
threat_modelling/reports/   # Security scan outputs
README.md                   # Project README.md to have all latest information including overview, architecture, quick start, detail documentation links, contribution, license section

```

## Key Workflow Scripts

All scripts must be run from repository root.

### check-prerequisites.sh

```bash
.specify/scripts/bash/check-prerequisites.sh --json
.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
.specify/scripts/bash/check-prerequisites.sh --json --paths-only
```

- Returns: `FEATURE_DIR`, `AVAILABLE_DOCS`, `BRANCH`, `REPO_ROOT`
- Use `--require-tasks` for implementation phase
- Use `--paths-only` for minimal output

### create-new-feature.sh

```bash
.specify/scripts/bash/create-new-feature.sh --json "feature description"
```

- Creates feature branch and initializes spec file
- Returns: `BRANCH_NAME`, `SPEC_FILE`

### setup-plan.sh

```bash
.specify/scripts/bash/setup-plan.sh --json
```

- Returns: `FEATURE_SPEC`, `IMPL_PLAN`, `SPECS_DIR`, `BRANCH`

## Development Principles

### Constitution Authority

- The constitution (`.specify/memory/constitution.md`) is **non-negotiable**
- All design artifacts must validate against constitution principles
- Violations are flagged as CRITICAL during `/speckit.analyze`

### Artifact Separation

- **spec.md**: Business requirements (non-technical stakeholders)
- **plan.md**: Technical architecture (developers)
- **tasks.md**: Implementation steps (execution)

### Execution Order

When using workflow commands:

1.  Start with `/speckit.constitution` (if not already defined)
2.  Run `/speckit.specify` with feature description
3.  Run `/speckit.clarify` to resolve ambiguities
4.  Run `/speckit.plan` to generate design artifacts
5.  Run `/speckit.tasks` to create task breakdown
6.  Optional: Run `/speckit.analyze` to validate consistency
7.  Run `/speckit.implement` to execute tasks

## Project Technical Stack

**Framework**: OpenTofu as IaaS tool to manage shared cloud provider resource including WAF, CDN, DR related load balancer, Firewall, Firewall Rules, shared ingress VPC, shared egress VPC, VPC Link or similar cloud provider service, Key Management, shared secrets, etc.
**CI**: GitHub Actions with multi-environment promotion flow
**CD**: Cloud provider deployment tool
**Security Tools**:
- Secrets: gitleaks
- SCA: checkov
- SAST: Semgrep





main.tf                    # Main OpenTofu file
variables.tf               # Root module variables
outputs.tf                 # Root module outputs
```

## Important Notes

- **All file paths returned by scripts are absolute paths**
- The `/speckit.plan` command does NOT create tasks.md (use `/speckit.tasks` for that)
- Templates contain placeholders like `[FEATURE_NAME]` that get replaced during execution
- Clarifications should run BEFORE planning to reduce rework
- Analysis (`/speckit.analyze`) is read-only and never modifies files
- **Constitution compliance is mandatory**: All implementations must follow 12-Factor and SOLID principles
- **Branch naming**: Use GitHub branch (e.g., `2-feature-name`, not `002-feature-name`)
- **Out of Scope**: All resources related to different project cloud infrastrucutre related settings are out of this project
