#!/bin/bash
# GitStats - Clone/update repositories, analyze, and update dashboards
# Usage: ./run.sh [OPTIONS]
#
# Options:
#   --skip-pull, --no-pull    Skip git pull/fetch if repositories exist (use cached data)
#   --help                    Show this help message
#
# Safe to run multiple times - clones new repos, updates existing ones, and refreshes data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/config.yaml}"

# Read configuration from config.yaml (with fallback to environment variables)
if [ -f "${CONFIG_FILE}" ] && command -v python3 &> /dev/null; then
    ES_HOST="${ES_HOST:-$(python3 "${SCRIPT_DIR}/scripts/read-config.py" "${CONFIG_FILE}" "elasticsearch.host" 2>/dev/null || echo "localhost")}"
    ES_PORT="${ES_PORT:-$(python3 "${SCRIPT_DIR}/scripts/read-config.py" "${CONFIG_FILE}" "elasticsearch.port" 2>/dev/null || echo "9200")}"
else
    # Fallback to defaults if config not available
    ES_HOST="${ES_HOST:-localhost}"
    ES_PORT="${ES_PORT:-9200}"
fi

ES_URL="http://${ES_HOST}:${ES_PORT}"
SKIP_PULL=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-pull|--no-pull)
            SKIP_PULL=true
            shift
            ;;
        --help|-h)
            echo "GitStats - Run Analysis"
            echo ""
            echo "Usage: ./run.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-pull, --no-pull    Skip git pull/fetch if repositories exist (use cached data)"
            echo "  --help, -h                Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  CONFIG_FILE               Path to config.yaml (default: ./config.yaml)"
            echo "  ES_HOST                   Elasticsearch host (default: localhost)"
            echo "  ES_PORT                   Elasticsearch port (default: 9200)"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run './run.sh --help' for usage information"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "GitStats - Run Analysis"
echo "=========================================="
echo "Config: ${CONFIG_FILE}"
echo "Elasticsearch: ${ES_URL}"
if [ "$SKIP_PULL" = true ]; then
    echo "Mode: Skip pull (using cached repositories)"
fi
echo ""

# Check prerequisites
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "❌ Error: Configuration file not found: ${CONFIG_FILE}"
    exit 1
fi

if ! python3 -c "import yaml" 2>/dev/null; then
    echo "❌ Error: PyYAML not installed. Run: uv pip install -r requirements.txt --system"
    exit 1
fi

if ! curl -s "${ES_URL}/_cluster/health" > /dev/null; then
    echo "❌ Error: Cannot connect to Elasticsearch at ${ES_URL}"
    echo "Run: ./install.sh first to start services"
    exit 1
fi

echo "✓ Prerequisites met"
echo ""

# Clone/update repositories first (unless --skip-pull is set)
if [ "$SKIP_PULL" = true ]; then
    echo "Skipping repository pull (--skip-pull enabled)"
    echo ""
    
    # Check if repositories directory exists
    BASE_DIR=$(python3 -c "
import yaml
with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)
base_dir = config.get('repositories', {}).get('base_directory', './repositories')
print(base_dir)
")
    
    if [ ! -d "${SCRIPT_DIR}/${BASE_DIR}" ] || [ -z "$(ls -A "${SCRIPT_DIR}/${BASE_DIR}" 2>/dev/null)" ]; then
        echo "⚠️  Warning: Repositories directory is empty or doesn't exist!"
        echo "   Running clone for the first time..."
        echo ""
        "${SCRIPT_DIR}/scripts/clone-repositories.sh" || {
            echo ""
            echo "❌ Error: Failed to clone repositories. Cannot continue without repositories."
            exit 1
        }
    else
        echo "✓ Using existing repositories in ${BASE_DIR}/"
        echo ""
    fi
else
    echo "Cloning/updating repositories..."
    "${SCRIPT_DIR}/scripts/clone-repositories.sh" || {
        echo ""
        echo "⚠ Warning: Some repositories failed to clone/update, but continuing with analysis..."
    }
    echo ""
fi

# Run analysis
echo "Analyzing repositories..."
python3 "${SCRIPT_DIR}/scripts/analyze_git_commits.py" "${CONFIG_FILE}"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "⚠ Error: Analysis failed with exit code $EXIT_CODE"
    exit 1
fi

echo ""
echo "✓ Analysis complete"
echo ""

# Upload to Elasticsearch
echo "Uploading to Elasticsearch..."
"${SCRIPT_DIR}/scripts/upload-to-elasticsearch.sh"
echo ""

# Check for unmapped emails
echo "Checking for unmapped emails..."
python3 "${SCRIPT_DIR}/scripts/find_unmapped_emails.py" "${CONFIG_FILE}"
echo ""

# Show statistics
echo "=========================================="
echo "Statistics"
echo "=========================================="
curl -s "${ES_URL}/_cat/indices/git-*?v&h=index,docs.count,store.size"
echo ""

echo "Recent commits by repository:"
curl -s -X GET "${ES_URL}/git-commits/_search?size=0" -H "Content-Type: application/json" -d '{
  "aggs": {
    "by_repository": {
      "terms": {
        "field": "repository",
        "size": 20
      }
    }
  }
}' | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    buckets = data['aggregations']['by_repository']['buckets']
    for bucket in buckets:
        print(f\"  {bucket['key']}: {bucket['doc_count']:,} commits\")
except Exception as e:
    print(f'  Could not parse results: {e}')
" 2>/dev/null || echo "  (statistics not available)"

echo ""
echo "=========================================="
echo "✓ Analysis Complete!"
echo "=========================================="
echo ""
echo "View dashboards: http://localhost:3000"
echo ""
echo "Run ./run.sh again anytime to update with latest changes."
echo "Use ./run.sh --skip-pull to skip git pull and use cached data (faster)."
echo ""

