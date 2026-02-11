#!/bin/bash
#
# Simple tests for totp-vault CLI
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$SCRIPT_DIR/.build/debug/totp-vault"

echo "🧪 Testing totp-vault CLI"
echo ""

# Build if needed
if [ ! -f "$VAULT" ]; then
    echo "Building..."
    cd "$SCRIPT_DIR"
    swift build
fi

# Test 1: Help command
echo "Test 1: --help"
$VAULT --help > /dev/null
echo "  ✓ Help works"

# Test 2: Version command
echo "Test 2: --version"
VERSION=$($VAULT --version)
echo "  ✓ Version: $VERSION"

# Test 3: Time command
echo "Test 3: time"
TIME=$($VAULT time)
if [[ "$TIME" =~ ^[0-9]+$ ]] && [ "$TIME" -ge 1 ] && [ "$TIME" -le 30 ]; then
    echo "  ✓ Time remaining: ${TIME}s"
else
    echo "  ✗ Invalid time: $TIME"
    exit 1
fi

# Test 4: List (empty)
echo "Test 4: list (should be empty or show existing)"
$VAULT list > /dev/null
echo "  ✓ List works"

# Test 5: Get non-existent (should fail)
echo "Test 5: get non-existent (should fail)"
if $VAULT get nonexistent-secret-12345 2>/dev/null; then
    echo "  ✗ Should have failed"
    exit 1
else
    echo "  ✓ Correctly fails for missing secret"
fi

echo ""
echo "✅ All tests passed!"
echo ""
echo "Note: To test add/get flow, manually run:"
echo "  $VAULT add test-secret"
echo "  $VAULT get test-secret"
echo "  $VAULT remove test-secret"
