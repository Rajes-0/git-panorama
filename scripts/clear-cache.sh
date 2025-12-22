#!/bin/bash
# Clear analysis cache
# Use this to force re-analysis of all repositories

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_FILE="${CONFIG_FILE:-${PROJECT_DIR}/config.yaml}"

echo "=========================================="
echo "Clear Analysis Cache"
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

if [ -d "$CACHE_DIR" ]; then
    echo "Removing cache directory: $CACHE_DIR"
    rm -rf "$CACHE_DIR"
    echo "✓ Cache cleared successfully"
else
    echo "No cache directory found at: $CACHE_DIR"
    echo "✓ Nothing to clear"
fi

echo ""
echo "Next analysis will re-process all repositories."
echo ""

