#!/bin/bash
# analyze-warnings.sh — Comprehensive warning analysis and categorization
# Usage: ./Scripts/analyze-warnings.sh [full|concurrency|dead-code|logic|codable]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CATEGORY="${1:-full}"
OUTPUT_FILE="/tmp/warnings_analysis_$(date +%Y%m%d_%H%M%S).txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Anigma Build Warning Analysis${NC}"
echo "Category: $CATEGORY"
echo "Output: $OUTPUT_FILE"
echo ""

# Function to run build and capture warnings
run_build_analysis() {
    echo "Building and capturing warnings..."
    swift build 2>&1 | tee "$OUTPUT_FILE" > /dev/null
}

# Function to count and categorize warnings
categorize_warnings() {
    echo -e "${YELLOW}=== WARNING SUMMARY ===${NC}"
    
    local total=$(grep -c "warning:" "$OUTPUT_FILE" || echo "0")
    echo "Total warnings: $total"
    echo ""
    
    # Concurrency warnings
    echo -e "${YELLOW}Concurrency & Swift 6:${NC}"
    local redundant_await=$(grep -c "no 'async' operations occur within 'await' expression" "$OUTPUT_FILE" || echo "0")
    local data_race=$(grep -c "reference to captured var in concurrently-executing code" "$OUTPUT_FILE" || echo "0")
    local actor_iso=$(grep -c "actor-isolated method can not be referenced from a nonisolated context" "$OUTPUT_FILE" || echo "0")
    echo "  • Redundant awaits: $redundant_await"
    echo "  • Data race risks: $data_race"
    echo "  • Actor isolation: $actor_iso"
    local conc_total=$((redundant_await + data_race + actor_iso))
    echo "  Subtotal: $conc_total"
    echo ""
    
    # Dead code warnings
    echo -e "${YELLOW}Dead Code & Unused Values:${NC}"
    local unused_size=$(grep -c "value 'size' was defined but never used" "$OUTPUT_FILE" || echo "0")
    local unused_result=$(grep -c "result of call to.*is unused" "$OUTPUT_FILE" || echo "0")
    local never_mutated=$(grep -c "variable was never mutated" "$OUTPUT_FILE" || echo "0")
    echo "  • Unused 'size': $unused_size"
    echo "  • Unused results: $unused_result"
    echo "  • Never mutated (var->let): $never_mutated"
    local dead_total=$((unused_size + unused_result + never_mutated))
    echo "  Subtotal: $dead_total"
    echo ""
    
    # Logic & flow control warnings
    echo -e "${YELLOW}Logic & Flow Control:${NC}"
    local unreachable_catch=$(grep -c "'catch' block is unreachable" "$OUTPUT_FILE" || echo "0")
    local redundant_try=$(grep -c "no calls to throwing functions occur within 'try' expression" "$OUTPUT_FILE" || echo "0")
    local exhaustive=$(grep -c "switch must be exhaustive" "$OUTPUT_FILE" || echo "0")
    echo "  • Unreachable catch: $unreachable_catch"
    echo "  • Redundant try: $redundant_try"
    echo "  • Exhaustive switch: $exhaustive"
    local logic_total=$((unreachable_catch + redundant_try + exhaustive))
    echo "  Subtotal: $logic_total"
    echo ""
    
    # Codable warnings
    echo -e "${YELLOW}Codable Implementation:${NC}"
    local codable_immutable=$(grep -c "immutable property will not be decoded because it is declared with an initial value" "$OUTPUT_FILE" || echo "0")
    echo "  • Immutable+initial value: $codable_immutable"
    local codable_total=$codable_immutable
    echo "  Subtotal: $codable_total"
    echo ""
    
    # Summary
    local calc_total=$((conc_total + dead_total + logic_total + codable_total))
    echo -e "${GREEN}Categorized total: $calc_total / $total${NC}"
    echo "Uncategorized: $((total - calc_total))"
}

# Function to list specific warnings
list_concurrency_warnings() {
    echo -e "${YELLOW}=== CONCURRENCY WARNINGS ===${NC}"
    
    echo -e "${BLUE}Redundant awaits:${NC}"
    grep "no 'async' operations occur within 'await' expression" "$OUTPUT_FILE" || echo "None found"
    echo ""
    
    echo -e "${BLUE}Data race risks:${NC}"
    grep "reference to captured var in concurrently-executing code" "$OUTPUT_FILE" || echo "None found"
    echo ""
    
    echo -e "${BLUE}Actor isolation:${NC}"
    grep "actor-isolated method can not be referenced from a nonisolated context" "$OUTPUT_FILE" || echo "None found"
}

list_dead_code_warnings() {
    echo -e "${YELLOW}=== DEAD CODE & UNUSED VALUES ===${NC}"
    
    echo -e "${BLUE}Unused size:${NC}"
    grep "value 'size' was defined but never used" "$OUTPUT_FILE" || echo "None found"
    echo ""
    
    echo -e "${BLUE}Unused results:${NC}"
    grep "result of call to.*is unused" "$OUTPUT_FILE" || echo "None found"
    echo ""
    
    echo -e "${BLUE}Never mutated:${NC}"
    grep "variable was never mutated" "$OUTPUT_FILE" || echo "None found"
}

list_logic_warnings() {
    echo -e "${YELLOW}=== LOGIC & FLOW CONTROL ===${NC}"
    
    echo -e "${BLUE}Unreachable catch:${NC}"
    grep "'catch' block is unreachable" "$OUTPUT_FILE" || echo "None found"
    echo ""
    
    echo -e "${BLUE}Redundant try:${NC}"
    grep "no calls to throwing functions occur within 'try' expression" "$OUTPUT_FILE" || echo "None found"
    echo ""
    
    echo -e "${BLUE}Exhaustive switch:${NC}"
    grep "switch must be exhaustive" "$OUTPUT_FILE" || echo "None found"
}

list_codable_warnings() {
    echo -e "${YELLOW}=== CODABLE IMPLEMENTATION ===${NC}"
    
    echo -e "${BLUE}Immutable+initial value:${NC}"
    grep "immutable property will not be decoded because it is declared with an initial value" "$OUTPUT_FILE" || echo "None found"
}

# Main execution
run_build_analysis

case "$CATEGORY" in
    full)
        categorize_warnings
        list_concurrency_warnings
        list_dead_code_warnings
        list_logic_warnings
        list_codable_warnings
        ;;
    concurrency)
        list_concurrency_warnings
        ;;
    dead-code)
        list_dead_code_warnings
        ;;
    logic)
        list_logic_warnings
        ;;
    codable)
        list_codable_warnings
        ;;
    *)
        echo "Unknown category: $CATEGORY"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Analysis complete. Full output saved to: $OUTPUT_FILE${NC}"
