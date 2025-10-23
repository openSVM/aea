#!/bin/bash
# Bug fixes for AEA system
# Run this script to apply critical bug fixes

set -euo pipefail

echo "Applying critical bug fixes to AEA system..."
echo ""

# Fix 1: Fish shell syntax error
echo "1. Fixing Fish shell syntax in setup-global-alias.sh..."
sed -i 's/set -l command (count \$argv > \/dev\/null && echo \$argv\[1\] || echo "status")/set -l command (if test (count \$argv) -gt 0; echo \$argv[1]; else; echo "status"; end)/' scripts/setup-global-alias.sh

# Fix 2: Add array safety check
echo "2. Adding array safety check in setup-global-alias.sh..."
# Find line with AVAILABLE_SHELLS assignment and add safety check after
sed -i '/^AVAILABLE_SHELLS=($(detect_available_shells))$/a\
\
# Safety check for empty array\
if [ ${#AVAILABLE_SHELLS[@]} -eq 0 ]; then\
    echo "Warning: No supported shell configurations found"\
    AVAILABLE_SHELLS=("$CURRENT_SHELL")\
fi' scripts/setup-global-alias.sh

# Fix 3: Create log directory early in aea.sh
echo "3. Ensuring log directory exists before logging..."
sed -i '/^AEA_VERSION="0.1.0"$/a\
\
# Ensure directories exist early\
mkdir -p "$(dirname "${BASH_SOURCE[0]}")/.processed" "$(dirname "${BASH_SOURCE[0]}")/logs"' aea.sh

# Fix 4: Fix spaces in cd command for Fish update function
echo "4. Fixing spaces in paths for Fish update function..."
sed -i 's/cd "\$AEA_REPO" && git pull/(cd "\$AEA_REPO" \&\& git pull)/' scripts/setup-global-alias.sh

echo ""
echo "Critical fixes applied! Summary:"
echo "✓ Fixed Fish shell syntax error"
echo "✓ Added array safety checks"
echo "✓ Fixed log directory creation order"
echo "✓ Fixed spaces in path handling"
echo ""
echo "To verify fixes, run:"
echo "  bash aea.sh test"
echo "  bash scripts/setup-global-alias.sh --auto"