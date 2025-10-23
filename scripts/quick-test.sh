#!/bin/bash
# quick-test.sh - Quick validation tests for AEA
# Simpler, faster tests that don't hang

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

echo ""
echo -e "${BLUE}AEA Quick Test Suite${NC}"
echo "===================="
echo ""

# Test 1: Check required files exist
echo "Test 1: Core files exist"
if [ -f "scripts/aea-check.sh" ] && [ -f "scripts/aea-send.sh" ] && [ -f "PROTOCOL.md" ]; then
    test_pass "Core files present"
else
    test_fail "Core files missing"
fi

# Test 2: Scripts are executable
echo "Test 2: Scripts executable"
if [ -x "scripts/aea-check.sh" ] && [ -x "scripts/aea-send.sh" ]; then
    test_pass "Scripts are executable"
else
    test_fail "Scripts not executable"
fi

# Test 3: jq is available
echo "Test 3: jq dependency"
if command -v jq &>/dev/null; then
    test_pass "jq is installed"
else
    test_fail "jq not found"
fi

# Test 4: Check script runs
echo "Test 4: Check script runs"
if timeout 5 bash scripts/aea-check.sh &>/dev/null; then
    test_pass "aea-check.sh runs successfully"
else
    test_fail "aea-check.sh failed or timed out"
fi

# Test 5: Common utilities
echo "Test 5: Common utilities"
if [ -f "scripts/aea-common.sh" ]; then
    test_pass "Common utilities present"
else
    test_fail "Common utilities missing"
fi

# Test 6: Documentation exists
echo "Test 6: Documentation"
doc_count=0
[ -f "docs/EXAMPLES.md" ] && ((doc_count++))
[ -f "docs/SECURITY.md" ] && ((doc_count++))
[ -f "docs/INSTALLATION.md" ] && ((doc_count++))
if [ $doc_count -eq 3 ]; then
    test_pass "All documentation present"
else
    test_fail "Missing documentation ($doc_count/3)"
fi

# Test 7: Uninstall script
echo "Test 7: Lifecycle tools"
if [ -f "scripts/uninstall-aea.sh" ] && [ -f "scripts/aea-cleanup.sh" ]; then
    test_pass "Uninstall and cleanup tools present"
else
    test_fail "Lifecycle tools missing"
fi

# Test 8: Protocol version
echo "Test 8: Protocol version"
if grep -q "0.1.0" PROTOCOL.md; then
    test_pass "Protocol version documented"
else
    test_fail "Protocol version not found"
fi

# Test 9: Registry functions
echo "Test 9: Registry script"
if [ -f "scripts/aea-registry.sh" ] && grep -q "register_agent" scripts/aea-registry.sh; then
    test_pass "Registry functions present"
else
    test_fail "Registry incomplete"
fi

# Test 10: Error messages enhanced
echo "Test 10: Error message improvements"
if grep -q "💡 How to fix" scripts/aea-send.sh; then
    test_pass "Enhanced error messages present"
else
    test_fail "Error messages not enhanced"
fi

# Summary
echo ""
echo "===================="
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
