#!/bin/bash

################################################################################
# Anigma Phase 0 CI Gate Validator
# Enforces all five contracts: Error Model, Diagnostics, Build Hygiene, 
# Test Coverage, and Tier Validation
#
# Usage: ./scripts/validate_gates.sh [--verbose] [--capsule CAPSULE_NAME]
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERBOSE=false
TARGET_CAPSULE=""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Gate tracking
GATES_PASSED=0
GATES_FAILED=0
FAILED_GATES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose) VERBOSE=true; shift ;;
        --capsule) TARGET_CAPSULE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${BLUE}ℹ${NC}  $*"
}

log_success() {
    echo -e "${GREEN}✅${NC} $*"
}

log_error() {
    echo -e "${RED}❌${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC}  $*"
}

gate_pass() {
    local gate_name="$1"
    log_success "GATE_${gate_name} PASSED"
    ((GATES_PASSED++))
}

gate_fail() {
    local gate_name="$1"
    local reason="$2"
    local fix="$3"
    log_error "GATE_${gate_name} FAILED"
    echo -e "   ${RED}Reason:${NC} ${reason}"
    if [[ -n "$fix" ]]; then
        echo -e "   ${YELLOW}Fix:${NC}    ${fix}"
    fi
    ((GATES_FAILED++))
    FAILED_GATES+=("${gate_name}")
}

check_capsule_dir() {
    if [[ ! -d "$REPO_ROOT/anigma/Anigma/Packages/$1" ]]; then
        return 1
    fi
    return 0
}

get_capsule_manifest() {
    local capsule="$1"
    local manifest_path="$REPO_ROOT/anigma/Anigma/Packages/${capsule}/MANIFEST.toml"
    if [[ -f "$manifest_path" ]]; then
        echo "$manifest_path"
    else
        echo ""
    fi
}

get_manifest_value() {
    local manifest_path="$1"
    local key="$2"
    if [[ -f "$manifest_path" ]]; then
        grep "^${key}" "$manifest_path" | sed 's/.*=\s*"\?//;s/"\?$//' | head -1
    fi
}

################################################################################
# GATE 1: ERROR_MODEL
# Enforcement: No public capsule API throws non-CapsuleError
################################################################################

check_error_model() {
    local capsule="$1"
    local package_dir="$REPO_ROOT/anigma/Anigma/Packages/${capsule}"
    local sources_dir="${package_dir}/Sources/${capsule}"
    
    if [[ ! -d "$sources_dir" ]]; then
        log_warn "No sources found for ${capsule}, skipping ERROR_MODEL check"
        return 0
    fi
    
    local violations=""
    
    # Check for direct NSError instantiation in public APIs
    if grep -r "NSError(" "${sources_dir}" 2>/dev/null | grep -v "^[[:space:]]*\/\/" | grep "public\|func"; then
        violations="${violations}NSError thrown in public API
"
    fi
    
    # Check for random exception types (pattern: throw SomeType(...))
    if grep -rE "throw\s+[A-Z][a-zA-Z]+Error\(" "${sources_dir}" 2>/dev/null | \
       grep -v "CapsuleError" | grep -v "^[[:space:]]*\/\/" | grep "public"; then
        violations="${violations}Non-CapsuleError exception found
"
    fi
    
    if [[ -n "$violations" ]]; then
        gate_fail "ERROR_MODEL" \
            "Public API throws non-canonical error type" \
            "Replace with CapsuleError (see PHASE0_REMEDIATION_CONTRACTS.md Contract 1)"
        return 1
    else
        gate_pass "ERROR_MODEL"
        return 0
    fi
}

################################################################################
# GATE 2: DIAGNOSTICS_CONFORMANCE
# Enforcement: No print(), NSLog(), os_log() in capsule sources
################################################################################

check_diagnostics() {
    local capsule="$1"
    local package_dir="$REPO_ROOT/anigma/Anigma/Packages/${capsule}"
    local sources_dir="${package_dir}/Sources/${capsule}"
    
    if [[ ! -d "$sources_dir" ]]; then
        log_warn "No sources found for ${capsule}, skipping DIAGNOSTICS check"
        return 0
    fi
    
    local violations=""
    local violation_files=""
    
    # Check for print() statements
    while IFS= read -r file line; do
        if [[ -n "$file" ]]; then
            violations="${violations}Found print() in $file
"
            violation_files="${violation_files}$file
"
        fi
    done < <(grep -rn "print(" "${sources_dir}" 2>/dev/null | grep -v "^[[:space:]]*\/\/" | cut -d: -f1,2 | sort -u)
    
    # Check for NSLog statements
    while IFS= read -r file line; do
        if [[ -n "$file" ]]; then
            violations="${violations}Found NSLog() in $file
"
            violation_files="${violation_files}$file
"
        fi
    done < <(grep -rn "NSLog(" "${sources_dir}" 2>/dev/null | grep -v "^[[:space:]]*\/\/" | cut -d: -f1,2 | sort -u)
    
    # Check for os_log statements
    while IFS= read -r file line; do
        if [[ -n "$file" ]]; then
            violations="${violations}Found os_log() in $file
"
            violation_files="${violation_files}$file
"
        fi
    done < <(grep -rn "os_log(" "${sources_dir}" 2>/dev/null | grep -v "^[[:space:]]*\/\/" | cut -d: -f1,2 | sort -u)
    
    if [[ -n "$violations" ]]; then
        gate_fail "DIAGNOSTICS_CONFORMANCE" \
            "Direct logging detected (print/NSLog/os_log)" \
            "Use CapsuleDiagnostics.event() instead (see PHASE0_REMEDIATION_CONTRACTS.md Contract 2)"
        if [[ "$VERBOSE" == true ]]; then
            echo -e "   ${YELLOW}Files:${NC}"
            echo "$violation_files" | sort -u | sed 's/^/     /'
        fi
        return 1
    else
        gate_pass "DIAGNOSTICS_CONFORMANCE"
        return 0
    fi
}

################################################################################
# GATE 3: BUILD_HYGIENE
# Enforcement: No hardcoded /opt/homebrew paths, all linker flags documented
################################################################################

check_build_hygiene() {
    local capsule="$1"
    local package_dir="$REPO_ROOT/anigma/Anigma/Packages/${capsule}"
    local package_swift="${package_dir}/Package.swift"
    
    if [[ ! -f "$package_swift" ]]; then
        log_warn "No Package.swift found for ${capsule}, skipping BUILD_HYGIENE check"
        return 0
    fi
    
    local violations=""
    
    # Check for hardcoded homebrew paths
    if grep -E "[\"\']\/opt\/homebrew" "$package_swift"; then
        violations="${violations}Hardcoded /opt/homebrew path detected
"
    fi
    
    # Check for undocumented linker settings
    # Look for unsafeFlags or linkedLibrary without preceding REASON/EXTERNAL_DEP comment
    if grep -E "(unsafeFlags|linkedLibrary)" "$package_swift" > /dev/null; then
        # Get lines with linker settings and check if they have REASON or EXTERNAL_DEP comment
        local problematic_lines=""
        while IFS= read -r line; do
            # Check if this line has a linker setting
            if echo "$line" | grep -qE "(unsafeFlags|linkedLibrary)"; then
                # Look back for REASON or EXTERNAL_DEP comment
                if ! grep -B3 "$line" "$package_swift" 2>/dev/null | grep -qE "(REASON|EXTERNAL_DEP|unsafe_flag)"; then
                    problematic_lines="${problematic_lines}$line
"
                fi
            fi
        done < <(grep -n "unsafeFlags\|linkedLibrary" "$package_swift")
        
        if [[ -n "$problematic_lines" ]]; then
            violations="${violations}Undocumented linker flags/libraries found
"
        fi
    fi
    
    if [[ -n "$violations" ]]; then
        gate_fail "BUILD_HYGIENE" \
            "${violations%$'\n'}" \
            "Document all linker settings with REASON/EXTERNAL_DEP comments (see PHASE0_REMEDIATION_CONTRACTS.md Contract 4)"
        return 1
    else
        gate_pass "BUILD_HYGIENE"
        return 0
    fi
}

################################################################################
# GATE 4: TEST_COVERAGE
# Enforcement: Tier 5 (80% coverage, 15+ tests), Tier 3 (60% coverage, 10+ tests)
################################################################################

check_test_coverage() {
    local capsule="$1"
    local manifest_path=$(get_capsule_manifest "$capsule")
    
    if [[ -z "$manifest_path" ]]; then
        log_warn "No MANIFEST.toml for ${capsule}, assuming Tier 2"
        gate_pass "TEST_COVERAGE"
        return 0
    fi
    
    local tier=$(get_manifest_value "$manifest_path" "tier")
    local coverage=$(get_manifest_value "$manifest_path" "coverage_percent")
    local test_count=$(get_manifest_value "$manifest_path" "test_count")
    
    # Default to missing values
    coverage=${coverage:-0}
    test_count=${test_count:-0}
    tier=${tier:-2}
    
    local min_coverage=0
    local min_tests=0
    
    if [[ "$tier" == "5" ]]; then
        min_coverage=80
        min_tests=15
    elif [[ "$tier" == "3" ]]; then
        min_coverage=60
        min_tests=10
    elif [[ "$tier" == "2" ]]; then
        # Optional in Phase 0
        gate_pass "TEST_COVERAGE"
        return 0
    else
        log_warn "Unknown tier: $tier for ${capsule}"
        gate_pass "TEST_COVERAGE"
        return 0
    fi
    
    local violations=""
    
    if (( coverage < min_coverage )); then
        violations="${violations}Coverage ${coverage}% < required ${min_coverage}% for Tier ${tier}
"
    fi
    
    if (( test_count < min_tests )); then
        violations="${violations}Test count ${test_count} < required ${min_tests} for Tier ${tier}
"
    fi
    
    if [[ -n "$violations" ]]; then
        gate_fail "TEST_COVERAGE" \
            "$(echo "$violations" | xargs)" \
            "Add tests and/or update MANIFEST.toml coverage metrics"
        return 1
    else
        log_info "TEST_COVERAGE check: ${capsule} Tier ${tier}: ${coverage}% coverage, ${test_count} tests"
        gate_pass "TEST_COVERAGE"
        return 0
    fi
}

################################################################################
# GATE 5: TIER_VALIDATION
# Enforcement: Validate tier requirements from MANIFEST.toml
################################################################################

check_tier_validation() {
    local capsule="$1"
    local manifest_path=$(get_capsule_manifest "$capsule")
    
    if [[ -z "$manifest_path" ]]; then
        log_warn "No MANIFEST.toml for ${capsule}, skipping TIER_VALIDATION"
        return 0
    fi
    
    local tier=$(get_manifest_value "$manifest_path" "tier")
    local name=$(get_manifest_value "$manifest_path" "name")
    local owner=$(get_manifest_value "$manifest_path" "owner")
    local min_coverage=$(get_manifest_value "$manifest_path" "coverage_percent")
    local status=$(get_manifest_value "$manifest_path" "status")
    
    # Validate required fields
    if [[ -z "$tier" ]] || [[ -z "$name" ]]; then
        gate_fail "TIER_VALIDATION" \
            "MANIFEST.toml missing required fields (tier, name)" \
            "See sample MANIFEST.toml in this repository"
        return 1
    fi
    
    # Validate tier is valid
    if ! [[ "$tier" =~ ^[1-5]$ ]]; then
        gate_fail "TIER_VALIDATION" \
            "Invalid tier value: $tier" \
            "Tier must be 1-5"
        return 1
    fi
    
    gate_pass "TIER_VALIDATION"
    return 0
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    log_info "=========================================="
    log_info "Anigma Phase 0 CI Gate Validation"
    log_info "=========================================="
    echo ""
    
    # Determine which capsules to check
    local capsules_to_check=()
    if [[ -n "$TARGET_CAPSULE" ]]; then
        if check_capsule_dir "$TARGET_CAPSULE"; then
            capsules_to_check=("$TARGET_CAPSULE")
        else
            log_error "Capsule not found: $TARGET_CAPSULE"
            exit 1
        fi
    else
        # Find all capsules with Package.swift
        while IFS= read -r capsule_path; do
            if [[ -f "${capsule_path}/Package.swift" ]]; then
                capsule_name=$(basename "$(dirname "$capsule_path")")
                capsules_to_check+=("$capsule_name")
            fi
        done < <(find "$REPO_ROOT/anigma/Anigma/Packages" -name "Package.swift" -type f 2>/dev/null)
    fi
    
    if [[ ${#capsules_to_check[@]} -eq 0 ]]; then
        log_error "No capsules found to check"
        exit 1
    fi
    
    log_info "Checking ${#capsules_to_check[@]} capsule(s): ${capsules_to_check[*]}"
    echo ""
    
    # Run all gates for each capsule
    local gate_results=()
    for capsule in "${capsules_to_check[@]}"; do
        echo -e "${BLUE}━━━ ${capsule} ━━━${NC}"
        check_error_model "$capsule" || true
        check_diagnostics "$capsule" || true
        check_build_hygiene "$capsule" || true
        check_test_coverage "$capsule" || true
        check_tier_validation "$capsule" || true
        echo ""
    done
    
    # Print summary
    echo -e "${BLUE}=========================================="
    echo "Summary"
    echo "==========================================${NC}"
    echo -e "Passed: ${GREEN}${GATES_PASSED}${NC}"
    echo -e "Failed: ${RED}${GATES_FAILED}${NC}"
    
    if [[ ${#FAILED_GATES[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed Gates:${NC}"
        for gate in "${FAILED_GATES[@]}"; do
            echo "  - $gate"
        done
    fi
    echo ""
    
    if [[ $GATES_FAILED -gt 0 ]]; then
        log_error "CI Gate Validation FAILED"
        exit 1
    else
        log_success "CI Gate Validation PASSED"
        exit 0
    fi
}

main "$@"
