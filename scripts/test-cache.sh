#!/bin/bash
# Test script to verify caching mechanism
# This script demonstrates that the cache works correctly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_FILE="${CONFIG_FILE:-${PROJECT_DIR}/config.yaml}"

echo "=========================================="
echo "Cache Mechanism Test"
echo "=========================================="
echo ""

# Get output directory from config
OUTPUT_DIR=$(python3 -c "
import yaml
import sys

try:
    with open('${CONFIG_FILE}', 'r') as f:
        config = yaml.safe_load(f)
    
    output_dir = config.get('analysis', {}).get('output_directory', './git-stats')
    print(output_dir)
except Exception as e:
    print('./git-stats', file=sys.stderr)
    sys.exit(0)
")

CACHE_DIR="${PROJECT_DIR}/${OUTPUT_DIR}/.cache"

echo "Step 1: Clear any existing cache"
echo "-----------------------------------"
if [ -d "$CACHE_DIR" ]; then
    rm -rf "$CACHE_DIR"
    echo "✓ Cache cleared"
else
    echo "✓ No cache to clear"
fi
echo ""

echo "Step 2: First run (should analyze all repos)"
echo "-----------------------------------"
echo "Running commits analysis..."
time python3 "${SCRIPT_DIR}/analyze_git_commits.py" "${CONFIG_FILE}" 2>&1 | head -20
FIRST_RUN_EXIT=$?
echo ""

if [ $FIRST_RUN_EXIT -eq 0 ]; then
    echo "✓ First run completed successfully"
else
    echo "✗ First run failed with exit code $FIRST_RUN_EXIT"
    exit 1
fi
echo ""

# Check if cache was created
if [ -d "$CACHE_DIR" ]; then
    echo "✓ Cache directory created: $CACHE_DIR"
    echo "  Cache files:"
    ls -lh "$CACHE_DIR" | tail -n +2 | awk '{print "    " $9 " (" $5 ")"}'
else
    echo "✗ Cache directory not created!"
    exit 1
fi
echo ""

echo "Step 3: Second run (should use cache)"
echo "-----------------------------------"
echo "Running commits analysis again..."
time python3 "${SCRIPT_DIR}/analyze_git_commits.py" "${CONFIG_FILE}" 2>&1 | head -20
SECOND_RUN_EXIT=$?
echo ""

if [ $SECOND_RUN_EXIT -eq 0 ]; then
    echo "✓ Second run completed successfully"
else
    echo "✗ Second run failed with exit code $SECOND_RUN_EXIT"
    exit 1
fi
echo ""

echo "=========================================="
echo "✓ Cache Test Complete!"
echo "=========================================="
echo ""
echo "Expected behavior:"
echo "  - First run: 'Analyzing repository: <name>'"
echo "  - Second run: 'Repository unchanged (using cache): <name>'"
echo ""
echo "If you see the above pattern, caching is working correctly!"
echo ""

