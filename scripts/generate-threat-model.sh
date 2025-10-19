#!/bin/bash
# ============================================================================
# Threagile Threat Modeling Report Generator
# ============================================================================
# Generates threat modeling reports and diagrams from threat-model.yaml
#
# Usage:
#   ./scripts/generate-threat-model.sh [--local]
#
# Options:
#   --local    Run locally (uses Docker, saves to threat_modelling/reports/)
#   (default)  CI mode (validates environment, uploads artifacts)
#
# Requirements:
#   - Docker installed (for Threagile execution)
#   - threat_modelling/threat-model.yaml exists
#
# Outputs (in threat_modelling/reports/):
#   - risks.json              Machine-readable risk findings
#   - risks.xlsx              Excel report for human review
#   - data-flow-diagram.png   Architecture visualization
#   - data-asset-diagram.png  Data flow visualization
#   - report.pdf              Comprehensive PDF report
# ============================================================================

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly THREAT_MODEL="${REPO_ROOT}/threat_modelling/threat-model.yaml"
readonly REPORTS_DIR="${REPO_ROOT}/threat_modelling/reports"
readonly THREAGILE_IMAGE="threagile/threagile:latest"

# Flags
LOCAL_MODE=false

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

# ============================================================================
# Validation
# ============================================================================

validate_prerequisites() {
    log_info "Validating prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        log_error "Install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    log_success "Docker found: $(docker --version | head -1)"

    # Check threat model exists
    if [ ! -f "$THREAT_MODEL" ]; then
        log_error "Threat model not found: $THREAT_MODEL"
        log_error "Create threat_modelling/threat-model.yaml before running this script"
        exit 1
    fi
    log_success "Threat model found: $THREAT_MODEL"

    # Create reports directory
    mkdir -p "$REPORTS_DIR"
    log_success "Reports directory ready: $REPORTS_DIR"
}

# ============================================================================
# Pull Threagile Docker Image
# ============================================================================

pull_threagile_image() {
    log_info "Pulling Threagile Docker image..."

    if docker pull "$THREAGILE_IMAGE"; then
        log_success "Threagile image pulled successfully"
    else
        log_error "Failed to pull Threagile image"
        exit 1
    fi
}

# ============================================================================
# Generate Threat Model Reports
# ============================================================================

generate_reports() {
    log_info "Generating threat model reports with Threagile..."

    # Run Threagile in Docker container
    # Mount: threat_modelling/ directory to /app/work in container
    # Output: All reports saved to threat_modelling/reports/

    if docker run --rm \
        -v "${REPO_ROOT}/threat_modelling:/app/work" \
        -w /app/work \
        "$THREAGILE_IMAGE" \
        -model threat-model.yaml \
        -output reports; then

        log_success "Threagile analysis completed"
    else
        log_error "Threagile analysis failed"
        exit 1
    fi
}

# ============================================================================
# Analyze Results
# ============================================================================

analyze_results() {
    log_info "Analyzing threat modeling results..."

    # Check if risks.json was generated
    if [ ! -f "${REPORTS_DIR}/risks.json" ]; then
        log_warning "No risks.json found - Threagile may not have generated all outputs"
        log_info "Available files in ${REPORTS_DIR}:"
        ls -lh "$REPORTS_DIR" || true
        return 0
    fi

    # Count risk severities (if jq is available)
    if command -v jq &> /dev/null; then
        CRITICAL_COUNT=$(jq '[.risks[] | select(.severity == "critical")] | length' "${REPORTS_DIR}/risks.json" 2>/dev/null || echo "0")
        HIGH_COUNT=$(jq '[.risks[] | select(.severity == "high")] | length' "${REPORTS_DIR}/risks.json" 2>/dev/null || echo "0")
        MEDIUM_COUNT=$(jq '[.risks[] | select(.severity == "medium")] | length' "${REPORTS_DIR}/risks.json" 2>/dev/null || echo "0")
        LOW_COUNT=$(jq '[.risks[] | select(.severity == "low")] | length' "${REPORTS_DIR}/risks.json" 2>/dev/null || echo "0")

        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "  Threat Modeling Results Summary"
        echo "═══════════════════════════════════════════════════════════════"
        echo -e "  ${RED}CRITICAL:${NC} $CRITICAL_COUNT"
        echo -e "  ${YELLOW}HIGH:${NC}     $HIGH_COUNT"
        echo -e "  ${BLUE}MEDIUM:${NC}   $MEDIUM_COUNT"
        echo -e "  ${GREEN}LOW:${NC}      $LOW_COUNT"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""

        # Exit with error if CRITICAL threats found (CI mode only)
        if [ "$LOCAL_MODE" = false ] && [ "$CRITICAL_COUNT" -gt 0 ]; then
            log_error "CRITICAL severity threats detected - failing CI build"
            log_error "Review threats in ${REPORTS_DIR}/risks.json"
            exit 1
        fi
    else
        log_info "jq not installed - skipping risk severity analysis"
    fi

    log_success "Generated reports:"
    find "$REPORTS_DIR" -type f -exec ls -lh {} \; | awk '{print "  - " $9 " (" $5 ")"}'
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --local)
                LOCAL_MODE=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 [--local]"
                exit 1
                ;;
        esac
    done

    log_info "Starting Threagile threat modeling report generation..."
    log_info "Mode: $([ "$LOCAL_MODE" = true ] && echo "LOCAL" || echo "CI")"
    echo ""

    validate_prerequisites
    pull_threagile_image
    generate_reports
    analyze_results

    echo ""
    log_success "Threat modeling report generation complete"
    log_info "Reports available at: ${REPORTS_DIR}/"
    echo ""

    if [ "$LOCAL_MODE" = true ]; then
        log_info "View reports:"
        log_info "  JSON:   cat ${REPORTS_DIR}/risks.json | jq"
        log_info "  Excel:  open ${REPORTS_DIR}/risks.xlsx"
        log_info "  Images: open ${REPORTS_DIR}/*.png"
    fi
}

main "$@"
